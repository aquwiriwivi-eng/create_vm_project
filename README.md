🇬🇧 English | [🇷🇺 Русский](README.ru.md)

# 🚀 Applying Virtual Machine Technology to System Administration Tasks

**Building a hands-on virtualization lab based on KVM/QEMU, VMware Workstation and Cloud-init**

![Debian 13](https://img.shields.io/badge/OS-Debian%2013-blueviolet?style=for-the-badge&logo=debian)
![KVM](https://img.shields.io/badge/Hypervisor-KVM%20%2F%20QEMU-orange?style=for-the-badge&logo=linux)
![VMware](https://img.shields.io/badge/Hypervisor-VMware%20Workstation-607078?style=for-the-badge&logo=vmware)
![PowerShell](https://img.shields.io/badge/Script-PowerShell-5391FE?style=for-the-badge&logo=powershell)
![Cloud-init](https://img.shields.io/badge/Automation-Cloud--init-green?style=for-the-badge)
![Docker](https://img.shields.io/badge/Containers-Docker-blue?style=for-the-badge&logo=docker)

---

## 📌 About the project

This repository contains automation scripts and configuration files developed as part of a course project.

The project explores virtualization technology and its practical use in typical system and network administration tasks, following the **Infrastructure as Code (IaC)** approach: a virtual machine is created and configured with a single command, with no manual OS installation.

Two scenarios are implemented:

| Scenario | Host | Hypervisor | Guest OS | Script |
|----------|------|------------|----------|--------|
| **Linux** | Debian 13 (Trixie) | KVM / QEMU (`libvirt`) | Ubuntu 24.04 (cloud image) | `create_cloud_vm.sh` |
| **Windows** | Windows 10 | VMware Workstation | Debian 13 (cloud image) | `create_vmware_vm.ps1` |

---

## 🛠️ Technology stack

| Category | Technologies |
|----------|--------------|
| **Host systems** | Debian 13 (Trixie), Windows 10 |
| **Hypervisors** | KVM, QEMU, `libvirt`, `virsh`, `virt-install`; VMware Workstation (`vmrun`) |
| **Image handling** | `qemu-img` (resize, qcow2 → VMDK conversion), `cloud-localds` / IMAPI2 (building `seed.iso`) |
| **Deployment automation** | Cloud-init (`user-data`, `meta-data`), Bash, PowerShell |
| **Containerization** | Docker, Docker Compose (`example-voting-app` stack) |

---

## 📂 Repository structure

```
.
├── create_vm.sh             # Linux: create a VM from an ISO image via virt-install
├── create_cloud_vm.sh       # Linux: deploy an Ubuntu cloud image (disk resize + cloud-init)
├── create_vmware_vm.ps1     # Windows: deploy a Debian 13 cloud image in VMware Workstation
├── user-data                # Cloud-init (Linux): user, SSH key, sudo, package updates
├── meta-data                # Cloud-init (Linux): instance-id and hostname
├── README.md                # Documentation (English)
└── README.ru.md             # Documentation (Russian)
```

### 💡 Components

- **`create_vm.sh`** — classic VM creation from an ISO via `virt-install` (interactive OS installation). The ISO path is hard-coded in the script — replace it with your own.
- **`create_cloud_vm.sh`** — automated deployment of an **Ubuntu 24.04** cloud image: recreates the VM, builds `seed.iso` from `user-data`/`meta-data`, copies the base image, grows the disk to 20 GB with `qemu-img` and starts the VM without a console (`--noautoconsole`).
- **`create_vmware_vm.ps1`** — the same idea for **Windows + VMware Workstation**: downloads the **Debian 13** cloud image, grows the disk, converts qcow2 → VMDK, creates the `.vmx` and a `seed.iso` with the cloud-init settings (it generates them itself and does not use the repository's `user-data`), starts the VM and prints its IP address.
- **`user-data`** — cloud-init configuration for the Linux scenario: creates the `ubuntu_auto_1` user, adds an SSH key, configures `sudo` and updates packages.
- **`meta-data`** — the VM's `instance-id` and hostname.

> ⚠️ **Before running, replace the SSH key and password hash in `user-data` (and at the top of the `.ps1`) with your own.** The repository contains the author's examples: you will not be able to log in with someone else's public key, and the example password must not be used anywhere except a throwaway lab.

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

On Windows, `openssl` is included with Git for Windows (`C:\Program Files\Git\usr\bin\openssl.exe`) and available in WSL.

> ℹ️ The main way to log in is **an SSH key**. By default cloud-init locks the created user's password (`lock_passwd: true`), so setting `passwd` alone does not let you log in with it. If you need password login (for example from the VM console), add `lock_passwd: false` to the user (the `.ps1` already does this).

---

## 🐧 Option A: Linux (KVM/QEMU, Debian 13)

### 1. Preparing the host

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

Edit `user-data`: put in your SSH key and password hash.

Download the Ubuntu 24.04 cloud image into the libvirt images directory **under the file name the script expects**:

```bash
sudo wget -O /var/lib/libvirt/images/ubuntu-24.04-server-cloudimg-amd64.img \
    https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

### 3. Running the deployment

Run the script **from the repository directory** (it reads `user-data` and `meta-data` from the current folder) and as a regular user — the script already uses `sudo` internally:

```bash
chmod +x create_cloud_vm.sh
./create_cloud_vm.sh
```

### 4. Connecting to the VM

Wait 1–2 minutes (first boot and cloud-init), then find the IP address leased by the `libvirt` DHCP server:

```bash
sudo virsh net-dhcp-leases default
```

Connect over SSH (the user is defined in `user-data`):

```bash
ssh ubuntu_auto_1@<VM_IP_ADDRESS>
```

### Re-running and removing the VM

Running `./create_cloud_vm.sh` again deletes the previous VM together with its disk and creates a new one. To remove it manually:

```bash
sudo virsh destroy ubuntu-cloud-cli
sudo virsh undefine ubuntu-cloud-cli --nvram
sudo rm -f /var/lib/libvirt/images/ubuntu-cli-vm.qcow2
```

> ⚠️ `create_vm.sh` and `create_cloud_vm.sh` use the same disk file, `/var/lib/libvirt/images/ubuntu-cli-vm.qcow2`. `create_cloud_vm.sh` **deletes** it on start, so don't use both scripts for the same VM.

---

## 🪟 Option B: Windows 10 (VMware Workstation)

### Requirements

- **VMware Workstation** (with the `vmrun.exe` utility) — the script looks for it in `C:\Program Files (x86)\VMware\VMware Workstation\` and `C:\Program Files\VMware\VMware Workstation\`
- **QEMU for Windows** ([qemu.weilnetz.de/w64](https://qemu.weilnetz.de/w64/)) — only `qemu-img.exe` is needed; the script finds it in `C:\Program Files\qemu\` or in `PATH`
- PowerShell 5.1 (built into Windows 10) **or newer**, including PowerShell 7 (`pwsh`), and internet access
- About 5 GB of free disk space (the ~400 MB image is cached; the VM disk grows up to 20 GB)

### Preparation

Open `create_vmware_vm.ps1` and replace the values in the settings block with your own:

```powershell
$sshUser   = 'vmsk'
$sshPubKey = 'ssh-ed25519 AAAA... your_key'
$passHash  = '$6$...'   # output of openssl passwd -6
```

You can also change the VM name, memory (`$memMB`), CPU count (`$cpus`) and disk size (`$diskSize`) there.

### Running

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

### What the script does

1. Locates `qemu-img.exe` and `vmrun.exe`.
2. Generates `user-data` and `meta-data` and builds `seed.iso` from them (volume label `cidata`, ISO9660 + **Joliet** file system — without Joliet cloud-init cannot find the files).
3. Downloads the Debian 13 cloud image into the `_cache` folder (later runs use the cache).
4. Grows the disk to 20 GB and converts qcow2 → VMDK.
5. Creates the `.vmx` (4 CPUs, 4 GB RAM, NAT networking, `seed.iso` as the CD-ROM).
6. Starts the VM through `vmrun` and waits until cloud-init installs `open-vm-tools` and the VM reports its IP (up to 8 minutes).

The VM files are created in the `DebianCloudVM` folder next to the script.

### Connecting to the VM

The script prints the IP address and a ready-to-use command:

```powershell
ssh vmsk@<VM_IP_ADDRESS>
```

If the IP could not be detected, open the VM console in VMware and run `ip a`.

---

## 🐳 Demo: "VM + containerization"

The scripts **do not install** Docker — install it inside the VM yourself. For example, on Ubuntu 24.04:

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2 git
```

Then deploy the sample application:

```bash
# Check the Docker version
docker --version

# Deploy the sample application
git clone https://github.com/dockersamples/example-voting-app.git
cd example-voting-app
sudo docker compose up -d
sudo docker compose ps          # published ports of the applications
```

The application is available at the VM's IP address on the ports shown by `docker compose ps`.

---

## 🩺 Troubleshooting

| Symptom | What to do |
|---------|------------|
| `ssh` refuses the connection in the first minutes after boot | Cloud-init is still configuring the system. Wait 1–3 minutes and try again |
| `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED` after recreating the VM | The new VM got the same IP but different host keys: `ssh-keygen -R <IP>` |
| `Permission denied (publickey)` | The public key in `user-data` / `$sshPubKey` is not yours. Compare fingerprints: `ssh-keygen -lf ~/.ssh/id_ed25519.pub` |
| Password login does not work | cloud-init locks the password by default — add `lock_passwd: false` (see the key and password section) |
| `create_cloud_vm.sh` fails while copying the image | The base image has not been downloaded to `/var/lib/libvirt/images/` or has a different name (see step 2 of option A) |
| The VMware VM gets no IP | Check that the VM has booted and cloud-init has finished: inside the VM run `cloud-init status --long` |

---

# With love from **Vmsk_Wivi** 🌸
