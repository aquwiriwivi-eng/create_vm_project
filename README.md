🇬🇧 English | [🇷🇺 Русский](README.ru.md)

# 🚀 Applying Virtual Machine Technology to System Administration Tasks

**A hands-on virtualization lab based on KVM/QEMU, VMware Workstation and Cloud-init**

![Debian 13](https://img.shields.io/badge/OS-Debian%2013-blueviolet?style=for-the-badge&logo=debian)
![KVM](https://img.shields.io/badge/Hypervisor-KVM%20%2F%20QEMU-orange?style=for-the-badge&logo=linux)
![VMware](https://img.shields.io/badge/Hypervisor-VMware%20Workstation-607078?style=for-the-badge&logo=vmware)
![PowerShell](https://img.shields.io/badge/Script-PowerShell-5391FE?style=for-the-badge&logo=powershell)
![Cloud-init](https://img.shields.io/badge/Automation-Cloud--init-green?style=for-the-badge)
![Docker](https://img.shields.io/badge/Containers-Docker-blue?style=for-the-badge&logo=docker)

---

## 📌 About the project

This repository contains the automation scripts and configuration files developed for a course project.

The project explores virtualization technology and its use in typical system and network administration tasks. It is built on the **Infrastructure as Code (IaC)** approach: a virtual machine is created and configured with a single command, with no manual OS installation.

Three scenarios are implemented:

| Scenario | Host | Hypervisor | Guest OS | Script |
|----------|------|------------|----------|--------|
| **Linux** | Debian 13 (Trixie) | KVM / QEMU (`libvirt`) | Ubuntu 24.04 (cloud image) | `create_cloud_vm.sh` |
| **Windows, single VM** | Windows 10 | VMware Workstation | Debian 13 (cloud image) | `create_vmware_vm.ps1` |
| **Windows, VM series** | Windows 10 | VMware Workstation | Debian 13 (cloud image) | `Auto-creating-vmware-debian_numbered.ps1` |

---

## 🛠️ Technology stack

| Category | Technologies |
|----------|--------------|
| **Host systems** | Debian 13 (Trixie), Windows 10 |
| **Hypervisors** | KVM, QEMU, `libvirt`, `virsh`, `virt-install`; VMware Workstation (`vmrun`) |
| **Image handling** | `qemu-img` (resize, qcow2 → VMDK conversion), `cloud-localds` / IMAPI2 (creating `seed.iso`) |
| **Deployment automation** | Cloud-init (`user-data`, `meta-data`), Bash, PowerShell |
| **Containerization** | Docker, Docker Compose (the `example-voting-app` stack) |

---

## 📂 Repository structure

```
.
├── create_vm.sh                                # Linux: create a VM from an ISO image via virt-install
├── create_cloud_vm.sh                          # Linux: deploy an Ubuntu cloud image (disk resize + cloud-init)
├── create_vmware_vm.ps1                        # Windows: a single Debian 13 VM in VMware Workstation (recreated with -Force)
├── Auto-creating-vmware-debian_numbered.ps1    # Windows: each run creates a new, sequentially numbered VM
├── user-data                                   # Cloud-init (Linux): user, SSH key, sudo, package updates
├── meta-data                                   # Cloud-init (Linux): instance-id and hostname
├── README.md                                   # Documentation (English)
└── README.ru.md                                # Documentation (Russian)
```

### 💡 Component overview

- **`create_vm.sh`** — a classic VM installation from an ISO via `virt-install` (interactive OS installation). The ISO path is hardcoded in the script; replace it with your own.
- **`create_cloud_vm.sh`** — automated deployment of an **Ubuntu 24.04** cloud image. The script recreates the VM, generates `seed.iso` from `user-data`/`meta-data`, copies the base image, expands the disk to 20 GB with `qemu-img`, and starts the VM without a console (`--noautoconsole`).
- **`create_vmware_vm.ps1`** — the counterpart for **Windows + VMware Workstation**; it works with a **single** VM named `DebianCloudVM`. The script downloads the **Debian 13** cloud image, expands the disk, converts qcow2 → VMDK, creates the `.vmx` and a `seed.iso` with cloud-init settings (it generates them itself and does not use the repository's `user-data`), starts the VM, and prints its IP. If the VM already exists, it can be recreated with the `-Force` switch.
- **`Auto-creating-vmware-debian_numbered.ps1`** — a variant of the previous script for a **series of VMs**. It first checks which VMs already exist, then creates a **new** one with the next number (`DebianCloudVM-001`, `DebianCloudVM-002`, …) and a user `vmsk-NNN`, where `NNN` is the VM number. It never touches or deletes existing VMs. Details are in [option B2](#b2-vm-series-auto-creating-vmware-debian_numberedps1).
- **`user-data`** — the cloud-init configuration for the Linux scenario: creates the user `ubuntu_auto_1`, adds an SSH key, configures `sudo`, and updates packages.
- **`meta-data`** — the `instance-id` and the VM's hostname.

> ⚠️ **Before running, replace the SSH key in `user-data` (and at the top of the `.ps1` scripts), and in `user-data` also the password hash, with your own.** The repository contains the author's examples: you will not be able to log in with someone else's public key, and the example password must not be used anywhere except a test lab. Note that password login is disabled in the .ps1 scripts. Login is possible only with the SSH key. You will not be able to log in with a password, either locally or over SSH.

---

## 🔑 Preparing a key and a password

**SSH key** (if you don't have one yet). The private part stays with you; only the public part (`.pub`) goes into the VM:

```bash
ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub        # Windows PowerShell: type $env:USERPROFILE\.ssh\id_ed25519.pub
```

Paste the contents of `id_ed25519.pub` into `ssh_authorized_keys` (`user-data`) or into the `$sshPubKey` variable (`.ps1`).

**Password hash** (SHA-512) for the `passwd` field:

```bash
openssl passwd -6
```

On Windows, `openssl` is included with Git for Windows (`C:\Program Files\Git\usr\bin\openssl.exe`) and is available in WSL.

> ℹ️ The primary way to log in is **with an SSH key**. By default, cloud-init locks the password of the created user (`lock_passwd: true`), so the password in `passwd` alone does not let you log in. If you need password login (for example, from the VM console), add `lock_passwd: false` to the user (this is already done in `create_vmware_vm.ps1`).
>
> `Auto-creating-vmware-debian_numbered.ps1` does not set a password at all: login there is **key-only**, and no hash is needed.

---

## 🐧 Option A: Linux (KVM/QEMU, Debian 13)

### 1. Preparing the host system

Install the virtualization packages and utilities:

```bash
sudo apt update
sudo apt install -y qemu-system qemu-utils libvirt-daemon-system libvirt-clients \
    bridge-utils virtinst cloud-image-utils git
```

Start `libvirtd` and enable it at boot:

```bash
sudo systemctl enable --now libvirtd
```

Add yourself to the `libvirt` and `kvm` groups, then **log out and back in** (or run `newgrp libvirt`):

```bash
sudo usermod -aG libvirt,kvm $USER
```

Make sure the `default` network is running (the VM gets its IP from it via DHCP):

```bash
sudo virsh net-list --all
sudo virsh net-start default        # if it is inactive
sudo virsh net-autostart default
```

### 2. Getting the project and the base image

```bash
git clone https://github.com/aquwiriwivi-eng/create_vm_project.git
cd create_vm_project
```

Edit `user-data`: put in your own SSH key and password hash.

Download the Ubuntu 24.04 cloud image into the libvirt images directory **under the name the script expects**:

```bash
sudo wget -O /var/lib/libvirt/images/ubuntu-24.04-server-cloudimg-amd64.img \
    https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

### 3. Running the deployment

Run the script **from the repository directory** (it reads `user-data` and `meta-data` from the current folder) and as a regular user: the script already calls `sudo` internally.

```bash
chmod +x create_cloud_vm.sh
./create_cloud_vm.sh
```

### 4. Connecting to the VM

Wait 1–2 minutes (the first boot and cloud-init are in progress), then find the IP assigned by the `libvirt` DHCP server:

```bash
sudo virsh net-dhcp-leases default
```

Connect over SSH (the user is defined in `user-data`):

```bash
ssh ubuntu_auto_1@<VM_IP_ADDRESS>
```

### Re-running and removal

Running `./create_cloud_vm.sh` again deletes the previous VM together with its disk and creates a new one. To remove it manually:

```bash
sudo virsh destroy ubuntu-cloud-cli
sudo virsh undefine ubuntu-cloud-cli --nvram
sudo rm -f /var/lib/libvirt/images/ubuntu-cli-vm.qcow2
```

> ⚠️ `create_vm.sh` and `create_cloud_vm.sh` use the same disk file, `/var/lib/libvirt/images/ubuntu-cli-vm.qcow2`. `create_cloud_vm.sh` **deletes** it on startup, so do not use both scripts for the same VM.

---

## 🪟 Option B: Windows 10 (VMware Workstation)

There are two scripts for Windows. They do the same thing (Debian 13 cloud image → VMDK → VM in VMware), but handle already existing VMs differently:

| | `create_vmware_vm.ps1` | `Auto-creating-vmware-debian_numbered.ps1` |
|---|---|---|
| Number of VMs | one (`DebianCloudVM`) | as many as you need, one per run |
| If a VM already exists | stops with an error; with `-Force` the old VM is **deleted** and created again | existing VMs are left untouched, the next number is created |
| VM name | `DebianCloudVM` | `DebianCloudVM-001`, `DebianCloudVM-002`, … |
| User inside the VM | `vmsk` | `vmsk-001`, `vmsk-002`, … (the number matches the VM number) |
| Parameters | `-Force` | none |

### Requirements (common to both scripts)

- **VMware Workstation** (with the `vmrun.exe` utility): the script looks for it in `C:\Program Files (x86)\VMware\VMware Workstation\` and `C:\Program Files\VMware\VMware Workstation\`
- **QEMU for Windows** ([qemu.weilnetz.de/w64](https://qemu.weilnetz.de/w64/)): only `qemu-img.exe` is needed; the script finds it in `C:\Program Files\qemu\` or in `PATH`
- PowerShell 5.1 (built into Windows 10) **or newer**, including PowerShell 7 (`pwsh`), and internet access
- Free disk space: the image (~400 MB) is downloaded once and cached in `_cache`; each VM's disk takes up to 20 GB

### B1. Single VM: `create_vmware_vm.ps1`

#### Preparation

Open `create_vmware_vm.ps1` and replace the values in the settings block with your own:

```powershell
$sshUser   = 'vmsk'
$sshPubKey = 'ssh-ed25519 AAAA... your_key'
$passHash  = '$6$...'   # the output of openssl passwd -6
```

You can also change the VM name, memory size (`$memMB`), CPU count (`$cpus`) and disk size (`$diskSize`) here.

#### Running

```powershell
# Windows PowerShell 5.1 (built in)
powershell -ExecutionPolicy Bypass -File .\create_vmware_vm.ps1

# or PowerShell 7
pwsh -ExecutionPolicy Bypass -File .\create_vmware_vm.ps1
```

If the VM was already created by this script, recreate it from scratch (the old VM will be stopped and deleted):

```powershell
powershell -ExecutionPolicy Bypass -File .\create_vmware_vm.ps1 -Force
```

The VM files are created in the `DebianCloudVM` folder next to the script. To connect, use `ssh vmsk@<VM_IP_ADDRESS>`.

### B2. VM series: `Auto-creating-vmware-debian_numbered.ps1`

This script is meant for when you need several identical VMs (a lab of several nodes, a separate VM for each experiment). Each run **adds one new VM** and deletes nothing.

#### How the number is chosen

1. The script scans the folder it resides in and looks for subfolders named `DebianCloudVM-<number>`.
2. It prints the list of VMs found. For each one, `vmrun list` is used to show whether it is running or stopped.
3. It finds the highest number among those found and adds 1. If there are no VMs yet, `001` is created. The number is always written with three digits.
4. The names are built from this number:

| Number | Folder and VM name | User | Hostname |
|--------|--------------------|------|----------|
| 001 | `DebianCloudVM-001` | `vmsk-001` | `debiancloudvm-001` |
| 002 | `DebianCloudVM-002` | `vmsk-002` | `debiancloudvm-002` |
| 017 | `DebianCloudVM-017` | `vmsk-017` | `debiancloudvm-017` |

The `_cache` folder and the "old" un-numbered `DebianCloudVM` folder do not match the pattern: the script ignores them and does not modify them.

#### Preparation

Open the script and replace the public key in the settings block with your own. No password hash is needed: the password in the VM is locked, and login is key-only.

```powershell
$vmPrefix   = 'DebianCloudVM'   # VM name = <prefix>-<number>
$userPrefix = 'vmsk'            # user = <prefix>-<number>
$sshPubKey  = 'ssh-ed25519 AAAA... your_key'
```

You can also change the memory size (`$memMB`), CPU count (`$cpus`) and disk size (`$diskSize`) here.

#### Running

```powershell
powershell -ExecutionPolicy Bypass -File .\Auto-creating-vmware-debian_numbered.ps1
```

Each run creates one more VM. Example output:

```
[*] Checking for existing VMs...
[+] Existing VMs found: 2
    DebianCloudVM-001  (running)
    DebianCloudVM-002  (stopped)
[*] Creating a new VM: DebianCloudVM-003 (user: vmsk-003)
...
[SUCCESS] DebianCloudVM-003, IP: 192.168.x.x
    ssh vmsk-003@192.168.x.x
```

#### What the script does

1. Finds `qemu-img.exe` and `vmrun.exe`.
2. Looks for existing VMs and determines the new VM's number (see above).
3. Generates `user-data` and `meta-data` (user `vmsk-NNN`, your SSH key, passwordless `sudo`) and builds a `seed.iso` from them (label `cidata`, ISO9660 + **Joliet**).
4. Downloads the Debian 13 cloud image into `_cache`. The cache is shared by all VMs, so the image is downloaded only once.
5. Expands the disk to 20 GB and converts qcow2 → VMDK.
6. Creates the `.vmx` (4 CPUs, 4 GB RAM, NAT networking, `seed.iso` attached as a CD-ROM).
7. Starts the VM via `vmrun` and waits until cloud-init installs `open-vm-tools` and the VM reports its IP (up to 8 minutes).

#### Connecting

The user name contains the VM number. For `DebianCloudVM-003` it is `vmsk-003`:

```powershell
ssh vmsk-003@<VM_IP_ADDRESS>
```

> ⚠️ There is no un-numbered `vmsk` user in these VMs. Trying to log in as that user gives `Permission denied (publickey)`, just like with a wrong key.

#### Removing a VM

The script does not delete VMs. To remove one you no longer need, stop it and delete its folder:

```powershell
& "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe" -T ws stop .\DebianCloudVM-003\DebianCloudVM-003.vmx hard
Remove-Item .\DebianCloudVM-003 -Recurse -Force
```

#### Limitations

- Existing VMs are detected **only by folders next to the script**. VMs stored elsewhere or renamed will not be seen by the script.
- The number is the highest one found plus 1. If you delete the last VM (for example, `005`), the next one will get `005` again.
- If a run is interrupted midway, an incomplete numbered folder is left behind. The next run will treat it as an existing VM and take the next number, so it is best to delete such a folder manually.

---

## 🐳 "VM + Containerization" demo

The scripts do **not** install Docker; install it inside the VM yourself. For example, on Ubuntu 24.04:

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2 git
```

Then deploy the test application:

```bash
# Check the Docker version
docker --version

# Deploy the test application
git clone https://github.com/dockersamples/example-voting-app.git
cd example-voting-app
sudo docker compose up -d
sudo docker compose ps          # published ports of the applications
```

The application is available at the virtual machine's IP on the ports shown by `docker compose ps`.

---

## 🩺 Troubleshooting

| Symptom | What to do |
|---------|------------|
| `ssh` refuses the connection in the first minutes after startup | Cloud-init is still configuring the system. Wait 1–3 minutes and try again |
| `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED` after recreating a VM | The new VM got the same IP but different host keys: `ssh-keygen -R <IP>` |
| `Permission denied (publickey)` | The wrong public key is in `user-data` / `$sshPubKey`. Compare fingerprints: `ssh-keygen -lf ~/.ssh/id_ed25519.pub` |
| `Permission denied (publickey)` on a VM from `..._numbered.ps1` | Check the user name: it includes the number (`vmsk-003`), not just `vmsk`. The script prints the ready-to-use `ssh` command at the end |
| Password login does not work | The password is locked by cloud-init by default. Add `lock_passwd: false` (see the key and password section) |
| `create_cloud_vm.sh` fails while copying the image | The base image has not been downloaded to `/var/lib/libvirt/images/` or has a different name (see step 2 of option A) |
| A VM in VMware does not get an IP | Check that the VM has booted and cloud-init has finished: inside the VM, run `cloud-init status --long` |
| `..._numbered.ps1` created a VM with an unexpected number | The script only counts `DebianCloudVM-<number>` folders next to itself. Check where your VMs are stored and whether there are extra or unfinished folders |

---

# With love from **Vmsk_Wivi** 🌸
