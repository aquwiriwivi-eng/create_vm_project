#requires -Version 5.1
<#
.SYNOPSIS
    Скачивает Debian 13 Cloud Image, конвертирует в VMDK и создаёт НОВУЮ ВМ в VMware Workstation.

.DESCRIPTION
    Скрипт сначала ищет уже существующие ВМ (папки DebianCloudVM-NNN рядом со скриптом),
    затем создаёт следующую по порядку: DebianCloudVM-001, DebianCloudVM-002, ...
    Пользователь внутри ВМ называется vmsk-NNN (NNN - номер ВМ). Существующие ВМ не затрагиваются.
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # без этого Invoke-WebRequest в PS 5.1 качает в разы медленнее
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ============================ НАСТРОЙКИ ============================
$vmPrefix  = 'DebianCloudVM'   # имя ВМ = <префикс>-<номер>, например DebianCloudVM-001
$userPrefix = 'vmsk'           # пользователь  = <префикс>-<номер>, например vmsk-001
$memMB     = 4096
$cpus      = 4
$diskSize  = '20G'
$debianUrl = 'https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2'

$sshPubKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINncl4erfsbxC0CRmRGfu1sPakZA6rmhpufrEyBtDlr1 admin@DESKTOP-7CGROD6' # Your ssh pubkey
# ===================================================================

$baseDir    = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$cacheDir   = Join-Path $baseDir '_cache'
$cachedQcow = Join-Path $cacheDir 'debian-13-generic-amd64.qcow2'

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

function New-UserData([string]$User, [string]$PubKey, [string]$HostName) {
@"
#cloud-config
hostname: $HostName
manage_etc_hosts: true
ssh_pwauth: false
users:
  - name: $User
    gecos: $User
    shell: /bin/bash
    sudo: 'ALL=(ALL) NOPASSWD:ALL'
    lock_passwd: true
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

# --------------------------- 0. Поиск существующих ВМ и выбор номера ---------------------------

Write-Host '[*] Проверяю, есть ли уже созданные ВМ...' -ForegroundColor Cyan

# Список запущенных ВМ - только для информации в выводе
$running = @()
if ($vmrun) {
    $runOut  = Invoke-Native $vmrun @('-T', 'ws', 'list')
    $running = @($runOut -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -like '*.vmx' })
}

$namePattern = '^' + [regex]::Escape($vmPrefix) + '-(\d+)$'
$existing = @(Get-ChildItem -Path $baseDir -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match $namePattern })

$maxNum = 0
$found  = foreach ($d in $existing) {
    $null = $d.Name -match $namePattern
    $n = [int]$Matches[1]
    if ($n -gt $maxNum) { $maxNum = $n }
    $vmx = Join-Path $d.FullName "$($d.Name).vmx"
    [pscustomobject]@{ Num = $n; Name = $d.Name; Running = ($running -contains $vmx) }
}

if ($found) {
    Write-Host "[+] Найдено существующих ВМ: $(@($found).Count)" -ForegroundColor Green
    foreach ($f in ($found | Sort-Object Num)) {
        $state = if ($f.Running) { 'запущена' } else { 'остановлена' }
        Write-Host ("    {0}  ({1})" -f $f.Name, $state)
    }
} else {
    Write-Host '[+] Существующих ВМ не найдено - будет создана первая.' -ForegroundColor Green
}
if (Test-Path (Join-Path $baseDir $vmPrefix)) {
    Write-Host "[i] Найдена старая ВМ без номера '$vmPrefix' - она не затрагивается." -ForegroundColor DarkGray
}

$vmNum    = $maxNum + 1
$vmId     = '{0:D3}' -f $vmNum
$vmName   = "$vmPrefix-$vmId"
$hostName = $vmName.ToLower()
$sshUser  = "$userPrefix-$vmId"

$vmDir      = Join-Path $baseDir $vmName
$qcowFile   = Join-Path $vmDir 'debian.qcow2'
$vmdkFile   = Join-Path $vmDir 'debian.vmdk'
$vmxFile    = Join-Path $vmDir "$vmName.vmx"
$seedDir    = Join-Path $vmDir 'seed'
$isoFile    = Join-Path $vmDir 'seed.iso'

Write-Host "[*] Создаю новую ВМ: $vmName (пользователь: $sshUser)" -ForegroundColor Cyan

# --------------------------- 1. Подготовка папок ---------------------------

if (Test-Path $vmDir) { throw "Папка '$vmDir' уже существует - создание прервано, чтобы ничего не перезаписать." }
New-Item -ItemType Directory -Path $vmDir, $seedDir | Out-Null
if (!(Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir | Out-Null }

# --------------------------- 2. cloud-init seed.iso ---------------------------

Write-Host '[*] Генерация cloud-init (user-data / meta-data)...' -ForegroundColor Cyan
$instanceId = "iid-$hostName-$(Get-Date -Format 'yyyyMMddHHmmss')"
Write-TextLF (Join-Path $seedDir 'user-data') (New-UserData $sshUser $sshPubKey $hostName)
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
    Write-Host "[SUCCESS] $vmName, IP: $vmIp" -ForegroundColor Green
    Write-Host "    ssh $sshUser@$vmIp" -ForegroundColor White
} else {
    Write-Host '[!] IP не получен. Откройте консоль ВМ, войдите как $sshUser и выполните: ip a' -ForegroundColor Yellow
    Write-Host '    Диагностика внутри ВМ: cloud-init status --long ; sudo tail -n 50 /var/log/cloud-init.log' -ForegroundColor Yellow
}
