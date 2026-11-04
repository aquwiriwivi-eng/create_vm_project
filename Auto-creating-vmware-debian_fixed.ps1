#requires -Version 5.1
<#
.SYNOPSIS
    Скачивает Debian 13 Cloud Image, конвертирует в VMDK и создаёт ВМ в VMware Workstation.

.PARAMETER Force
    Если папка ВМ уже существует - остановить ВМ и пересоздать с нуля (старая будет удалена).
#>
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # без этого Invoke-WebRequest в PS 5.1 качает в разы медленнее
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ============================ НАСТРОЙКИ ============================
$vmName    = 'DebianCloudVM'
$hostName  = $vmName.ToLower()
$memMB     = 4096
$cpus      = 4
$diskSize  = '20G'
$debianUrl = 'https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2'

$sshUser   = 'vmsk'
$sshPubKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINncl4erfsbxC0CRmRGfu1sPakZA6rmhpufrEyBtDlr1 admin@DESKTOP-7CGROD6'
# SHA-512 хеш пароля (openssl passwd -6 / mkpasswd -m sha-512)
$passHash  = '$6$RG2d1nBacqS5EYQP$g/mT0eTqnNllyKEJlPDE59VYADvikHpSWcQ44kkCwB6kLMGcmJhLtMWLL7IlnsYOKDaB/Y/DBHgF2YBA8XGFv0'
# ===================================================================

$baseDir    = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$vmDir      = Join-Path $baseDir $vmName
$cacheDir   = Join-Path $baseDir '_cache'
$cachedQcow = Join-Path $cacheDir 'debian-13-generic-amd64.qcow2'
$qcowFile   = Join-Path $vmDir 'debian.qcow2'
$vmdkFile   = Join-Path $vmDir 'debian.vmdk'
$vmxFile    = Join-Path $vmDir "$vmName.vmx"
$seedDir    = Join-Path $vmDir 'seed'
$isoFile    = Join-Path $vmDir 'seed.iso'

$utf8NoBom  = New-Object System.Text.UTF8Encoding $false

# --------------------------- Вспомогательные функции ---------------------------

function Find-Exe([string]$Name, [string[]]$Candidates) {
    foreach ($c in $Candidates) { if ($c -and (Test-Path $c)) { return $c } }
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

# Запуск нативной программы без падения на stderr (в PS 5.1 при $ErrorActionPreference='Stop' и 2>&1 это ломается)
function Invoke-Native([string]$Exe, [string[]]$Arguments) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $Exe @Arguments 2>&1 | ForEach-Object { "$_" }
        return (($out -join "`n").Trim())
    } finally {
        $ErrorActionPreference = $old
    }
}

function Write-TextLF([string]$Path, [string]$Text) {
    # cloud-init надёжнее читает файлы с LF, без BOM
    [System.IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), $utf8NoBom)
}

function New-UserData([string]$User, [string]$PubKey, [string]$Hash, [string]$HostName) {
@"
#cloud-config
hostname: $HostName
manage_etc_hosts: true
ssh_pwauth: true
users:
  - name: $User
    gecos: $User
    shell: /bin/bash
    sudo: 'ALL=(ALL) NOPASSWD:ALL'
    lock_passwd: false
    passwd: '$Hash'
    ssh_authorized_keys:
      - '$PubKey'
package_update: true
packages:
  - open-vm-tools
"@
}

function New-VmxContent([string]$Name, [int]$Mem, [int]$Cpu) {
@"
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "19"
displayName = "$Name"
guestOS = "debian12-64"
memsize = "$Mem"
numvcpus = "$Cpu"
nvram = "$Name.nvram"
pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge4.functions = "8"
scsi0.present = "TRUE"
scsi0.virtualDev = "lsilogic"
scsi0:0.present = "TRUE"
scsi0:0.fileName = "debian.vmdk"
ide1:0.present = "TRUE"
ide1:0.deviceType = "cdrom-image"
ide1:0.fileName = "seed.iso"
ide1:0.startConnected = "TRUE"
ethernet0.present = "TRUE"
ethernet0.virtualDev = "e1000e"
ethernet0.connectionType = "nat"
ethernet0.addressType = "generated"
ethernet0.startConnected = "TRUE"
usb.present = "TRUE"
sound.present = "FALSE"
tools.syncTime = "TRUE"
"@
}

# IStream.Read принимает byte[], а не IntPtr, поэтому из чистого PowerShell
# корректно прочитать поток IMAPI нельзя - нужен небольшой C#-помощник.
if (-not ('IsoStreamWriter' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

public static class IsoStreamWriter
{
    public static void Write(string path, object comStream, int blockSize, int totalBlocks)
    {
        IStream src = (IStream)comStream;
        byte[] buf = new byte[blockSize];
        IntPtr pRead = Marshal.AllocHGlobal(sizeof(int));
        try
        {
            using (FileStream fs = File.Create(path))
            {
                for (int i = 0; i < totalBlocks; i++)
                {
                    src.Read(buf, blockSize, pRead);
                    int n = Marshal.ReadInt32(pRead);
                    if (n <= 0) break;
                    fs.Write(buf, 0, n);
                }
            }
        }
        finally { Marshal.FreeHGlobal(pRead); }
    }
}
'@
}

function New-CidataIso([string]$SourceDir, [string]$IsoPath, [string]$Label = 'cidata') {
    $fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
    try {
        # 1 = ISO9660, 2 = Joliet. Joliet ОБЯЗАТЕЛЕН: в чистом ISO9660 имя "user-data"
        # превращается в "USER_DATA", и cloud-init не находит файл.
        $fsi.FileSystemsToCreate = 3
        $fsi.VolumeName = $Label
        $fsi.Root.AddTree($SourceDir, $false)
        $res = $fsi.CreateResultImage()
        [IsoStreamWriter]::Write($IsoPath, $res.ImageStream, $res.BlockSize, $res.TotalBlocks)
        $expected = [int64]$res.BlockSize * [int64]$res.TotalBlocks
    } finally {
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($fsi)
    }

    # Проверки: размер совпадает и в образе есть Joliet-имя user-data (UTF-16BE)
    if ((Get-Item $IsoPath).Length -ne $expected) { throw "seed.iso записан не полностью." }
    $latin  = [Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($IsoPath))
    $needle = (([char[]]'user-data') | ForEach-Object { "`0$_" }) -join ''
    if (-not $latin.Contains($needle)) { throw "В seed.iso не найден файл user-data (Joliet)." }
}

# --------------------------- Поиск инструментов ---------------------------

$qemuImg = Find-Exe 'qemu-img.exe' @(
    "$env:ProgramFiles\qemu\qemu-img.exe",
    "${env:ProgramFiles(x86)}\qemu\qemu-img.exe"
)
if (-not $qemuImg) {
    throw "qemu-img.exe не найден. Установите QEMU for Windows: https://qemu.weilnetz.de/w64/"
}

$vmrun = Find-Exe 'vmrun.exe' @(
    "${env:ProgramFiles(x86)}\VMware\VMware Workstation\vmrun.exe",
    "$env:ProgramFiles\VMware\VMware Workstation\vmrun.exe"
)

# --------------------------- 1. Подготовка папок ---------------------------

if (Test-Path $vmDir) {
    if (-not $Force) {
        throw "Папка '$vmDir' уже существует. Запустите скрипт с параметром -Force, чтобы пересоздать ВМ (старая будет удалена)."
    }
    if ($vmrun -and (Test-Path $vmxFile)) {
        Write-Host '[*] Останавливаю старую ВМ...' -ForegroundColor Cyan
        [void](Invoke-Native $vmrun @('-T', 'ws', 'stop', $vmxFile, 'hard'))
        Start-Sleep -Seconds 3
    }
    Remove-Item $vmDir -Recurse -Force
}
New-Item -ItemType Directory -Path $vmDir, $seedDir | Out-Null
if (!(Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir | Out-Null }

# --------------------------- 2. cloud-init seed.iso ---------------------------

Write-Host '[*] Генерация cloud-init (user-data / meta-data)...' -ForegroundColor Cyan
$instanceId = "iid-$hostName-$(Get-Date -Format 'yyyyMMddHHmmss')"
Write-TextLF (Join-Path $seedDir 'user-data') (New-UserData $sshUser $sshPubKey $passHash $hostName)
Write-TextLF (Join-Path $seedDir 'meta-data') "instance-id: $instanceId`nlocal-hostname: $hostName`n"

Write-Host '[*] Создание seed.iso...' -ForegroundColor Cyan
New-CidataIso -SourceDir $seedDir -IsoPath $isoFile
Remove-Item $seedDir -Recurse -Force

# --------------------------- 3. Образ Debian (с кэшем) ---------------------------

if (Test-Path $cachedQcow) {
    Write-Host '[+] Найден кэшированный образ Debian, скачивание пропущено.' -ForegroundColor Green
} else {
    Write-Host '[*] Скачиваю Debian Cloud Image (~400 МБ)...' -ForegroundColor Cyan
    $part = "$cachedQcow.part"
    Invoke-WebRequest -Uri $debianUrl -OutFile $part -UseBasicParsing
    Move-Item $part $cachedQcow

    [void](Invoke-Native $qemuImg @('info', $cachedQcow))
    if ($LASTEXITCODE -ne 0) {
        Remove-Item $cachedQcow -Force
        throw 'Скачанный файл не является корректным образом qcow2.'
    }
}
Copy-Item $cachedQcow $qcowFile -Force

# --------------------------- 4. Resize + конвертация в VMDK ---------------------------

Write-Host "[*] Расширение диска до $diskSize..." -ForegroundColor Cyan
& $qemuImg resize -f qcow2 $qcowFile $diskSize
if ($LASTEXITCODE -ne 0) { throw 'qemu-img resize завершился с ошибкой.' }

Write-Host '[*] Конвертация qcow2 -> VMDK...' -ForegroundColor Cyan
& $qemuImg convert -f qcow2 -O vmdk -o 'subformat=monolithicSparse,adapter_type=lsilogic' $qcowFile $vmdkFile
if ($LASTEXITCODE -ne 0) { throw 'qemu-img convert завершился с ошибкой.' }
Remove-Item $qcowFile -Force

# --------------------------- 5. VMX ---------------------------

Write-Host '[*] Создание .vmx...' -ForegroundColor Cyan
Write-TextLF $vmxFile (New-VmxContent $vmName $memMB $cpus)
Write-Host "[+] ВМ создана: $vmDir" -ForegroundColor Green

# --------------------------- 6. Запуск и получение IP ---------------------------

if (-not $vmrun) {
    Write-Host '[!] vmrun.exe не найден - откройте .vmx в VMware вручную.' -ForegroundColor Yellow
    return
}

Write-Host '[*] Запуск ВМ...' -ForegroundColor Cyan
$startOut = Invoke-Native $vmrun @('-T', 'ws', 'start', $vmxFile, 'gui')
if ($startOut -match 'Error') { Write-Host "[!] vmrun: $startOut" -ForegroundColor Yellow }

Write-Host '[*] Жду первый запуск cloud-init и установку open-vm-tools (1-3 мин)...' -ForegroundColor Cyan
$vmIp     = $null
$deadline = (Get-Date).AddMinutes(8)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 5
    $out = Invoke-Native $vmrun @('-T', 'ws', 'getGuestIPAddress', $vmxFile)
    if ($out -match '^\d{1,3}(\.\d{1,3}){3}$') { $vmIp = $out; break }
    Write-Host -NoNewline '.'
}
Write-Host ''

if ($vmIp) {
    Write-Host "[SUCCESS] IP: $vmIp" -ForegroundColor Green
    Write-Host "    ssh $sshUser@$vmIp" -ForegroundColor White
} else {
    Write-Host '[!] IP не получен. Откройте консоль ВМ, войдите под своим пользователем и выполните: ip a' -ForegroundColor Yellow
    Write-Host '    Диагностика внутри ВМ: cloud-init status --long ; sudo tail -n 50 /var/log/cloud-init.log' -ForegroundColor Yellow
}
