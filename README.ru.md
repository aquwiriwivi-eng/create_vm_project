[🇬🇧 English](README.md) | 🇷🇺 Русский

# 🚀 Применение технологии виртуальных машин для решения задач администрирования

**Практический стенд виртуализации на базе KVM/QEMU, VMware Workstation и Cloud-init**

![Debian 13](https://img.shields.io/badge/OS-Debian%2013-blueviolet?style=for-the-badge&logo=debian)
![KVM](https://img.shields.io/badge/Hypervisor-KVM%20%2F%20QEMU-orange?style=for-the-badge&logo=linux)
![VMware](https://img.shields.io/badge/Hypervisor-VMware%20Workstation-607078?style=for-the-badge&logo=vmware)
![PowerShell](https://img.shields.io/badge/Script-PowerShell-5391FE?style=for-the-badge&logo=powershell)
![Cloud-init](https://img.shields.io/badge/Automation-Cloud--init-green?style=for-the-badge)
![Docker](https://img.shields.io/badge/Containers-Docker-blue?style=for-the-badge&logo=docker)

---

## 📌 О проекте

В репозитории собраны скрипты автоматизации и конфигурационные файлы, разработанные в рамках курсового проекта.

Проект исследует технологию виртуализации и её применение в типовых задачах системного и сетевого администрирования. В основе лежит подход **Infrastructure as Code (IaC)**: виртуальная машина создаётся и настраивается одной командой, без ручной установки ОС.

Реализованы три сценария:

| Сценарий | Хост | Гипервизор | Гостевая ОС | Скрипт |
|----------|------|------------|-------------|--------|
| **Linux** | Debian 13 (Trixie) | KVM / QEMU (`libvirt`) | Ubuntu 24.04 (cloud image) | `create_cloud_vm.sh` |
| **Windows, одна ВМ** | Windows 10 | VMware Workstation | Debian 13 (cloud image) | `create_vmware_vm.ps1` |
| **Windows, серия ВМ** | Windows 10 | VMware Workstation | Debian 13 (cloud image) | `Auto-creating-vmware-debian_numbered.ps1` |

---

## 🛠️ Технологический стек

| Категория | Технологии |
|-----------|------------|
| **Хост-системы** | Debian 13 (Trixie), Windows 10 |
| **Гипервизоры** | KVM, QEMU, `libvirt`, `virsh`, `virt-install`; VMware Workstation (`vmrun`) |
| **Работа с образами** | `qemu-img` (resize, конвертация qcow2 → VMDK), `cloud-localds` / IMAPI2 (создание `seed.iso`) |
| **Автоматизация деплоя** | Cloud-init (`user-data`, `meta-data`), Bash, PowerShell |
| **Контейнеризация** | Docker, Docker Compose (стек `example-voting-app`) |

---

## 📂 Структура репозитория

```
.
├── create_vm.sh                                # Linux: создание ВМ из ISO-образа через virt-install
├── create_cloud_vm.sh                          # Linux: деплой cloud-образа Ubuntu (resize диска + cloud-init)
├── create_vmware_vm.ps1                        # Windows: одна ВМ Debian 13 в VMware Workstation (пересоздаётся с -Force)
├── Auto-creating-vmware-debian_numbered.ps1    # Windows: каждый запуск создаёт новую ВМ с порядковым номером
├── user-data                                   # Cloud-init (Linux): пользователь, SSH-ключ, sudo, обновление пакетов
├── meta-data                                   # Cloud-init (Linux): instance-id и hostname
├── README.md                                   # Документация (English)
└── README.ru.md                                # Документация (Русский)
```

### 💡 Описание компонентов

- **`create_vm.sh`** — классическая установка ВМ из ISO через `virt-install` (интерактивная установка ОС). Путь к ISO в скрипте прописан жёстко, замените его на свой.
- **`create_cloud_vm.sh`** — автоматический деплой облачного образа **Ubuntu 24.04**. Скрипт пересоздаёт ВМ, генерирует `seed.iso` из `user-data`/`meta-data`, копирует базовый образ, расширяет диск до 20 ГБ через `qemu-img` и запускает ВМ без консоли (`--noautoconsole`).
- **`create_vmware_vm.ps1`** — аналог для **Windows + VMware Workstation**, работает с **одной** ВМ `DebianCloudVM`. Скрипт скачивает **Debian 13** cloud image, расширяет диск, конвертирует qcow2 → VMDK, создаёт `.vmx` и `seed.iso` с настройками cloud-init (генерирует их сам, `user-data` из репозитория не использует), запускает ВМ и выводит её IP. Если ВМ уже есть, её можно пересоздать ключом `-Force`.
- **`Auto-creating-vmware-debian_numbered.ps1`** — вариант предыдущего скрипта для **серии ВМ**. Он сначала проверяет, какие ВМ уже созданы, затем создаёт **новую** с очередным номером (`DebianCloudVM-001`, `DebianCloudVM-002`, …) и пользователем `vmsk-NNN`, где `NNN` — номер ВМ. Существующие ВМ он не трогает и не удаляет. Подробности — в [варианте B2](#b2-серия-вм-auto-creating-vmware-debian_numberedps1).
- **`user-data`** — конфигурация cloud-init для Linux-сценария: создаёт пользователя `ubuntu_auto_1`, добавляет SSH-ключ, настраивает `sudo` и обновляет пакеты.
- **`meta-data`** — `instance-id` и имя хоста ВМ.

> ⚠️ **Перед запуском замените в `user-data` (и в начале `.ps1`-скриптов) SSH-ключ, а в `user-data` ещё и хеш пароля, на свои.** В репозитории лежат примеры автора: с чужим публичным ключом вы не сможете войти, а пароль из примера нельзя использовать нигде, кроме тестового стенда. Учтите, что в скриптах .ps1 отключен вход по паролю. Вход осуществляется исключительно по отпечатку ssh. Вы не сможете войти ни локально, ни по ssh, используя пароль.

---

## 🔑 Подготовка ключа и пароля

**SSH-ключ** (если ещё нет). Приватная часть остаётся у вас, в ВМ попадает только публичная (`.pub`):

```bash
ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub        # Windows PowerShell: type $env:USERPROFILE\.ssh\id_ed25519.pub
```

Содержимое `id_ed25519.pub` вставьте в `ssh_authorized_keys` (`user-data`) или в переменную `$sshPubKey` (`.ps1`).

**Хеш пароля** (SHA-512) для поля `passwd`:

```bash
openssl passwd -6
```

На Windows `openssl` есть в составе Git for Windows (`C:\Program Files\Git\usr\bin\openssl.exe`) и в WSL.

> ℹ️ Основной способ входа — **по SSH-ключу**. По умолчанию cloud-init блокирует пароль созданного пользователя (`lock_passwd: true`), поэтому пароль в `passwd` сам по себе не позволяет войти. Если нужен вход по паролю (например, с консоли ВМ), добавьте пользователю `lock_passwd: false` (в `create_vmware_vm.ps1` это уже сделано).
>
> `Auto-creating-vmware-debian_numbered.ps1` пароль вообще не задаёт: там вход **только по ключу**, хеш не нужен.

---

## 🐧 Вариант A: Linux (KVM/QEMU, Debian 13)

### 1. Подготовка хост-системы

Установите пакеты виртуализации и утилиты:

```bash
sudo apt update
sudo apt install -y qemu-system qemu-utils libvirt-daemon-system libvirt-clients \
    bridge-utils virtinst cloud-image-utils git
```

Запустите `libvirtd` и добавьте в автозагрузку:

```bash
sudo systemctl enable --now libvirtd
```

Добавьте себя в группы `libvirt` и `kvm`, затем **перезайдите в сессию** (или выполните `newgrp libvirt`):

```bash
sudo usermod -aG libvirt,kvm $USER
```

Убедитесь, что сеть `default` запущена (в ней ВМ получает IP по DHCP):

```bash
sudo virsh net-list --all
sudo virsh net-start default        # если она неактивна
sudo virsh net-autostart default
```

### 2. Получение проекта и базового образа

```bash
git clone https://github.com/aquwiriwivi-eng/create_vm_project.git
cd create_vm_project
```

Отредактируйте `user-data`: подставьте свой SSH-ключ и хеш пароля.

Скачайте cloud-образ Ubuntu 24.04 в каталог образов libvirt **под тем именем, которое ожидает скрипт**:

```bash
sudo wget -O /var/lib/libvirt/images/ubuntu-24.04-server-cloudimg-amd64.img \
    https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

### 3. Запуск деплоя

Запускайте скрипт **из каталога репозитория** (он читает `user-data` и `meta-data` из текущей папки) и от обычного пользователя: `sudo` внутри скрипта уже есть.

```bash
chmod +x create_cloud_vm.sh
./create_cloud_vm.sh
```

### 4. Подключение к ВМ

Подождите 1–2 минуты (идёт первая загрузка и cloud-init), затем узнайте IP, выданный DHCP-сервером `libvirt`:

```bash
sudo virsh net-dhcp-leases default
```

Подключитесь по SSH (пользователь задан в `user-data`):

```bash
ssh ubuntu_auto_1@<IP_АДРЕС_ВМ>
```

### Повторный запуск и удаление

Повторный запуск `./create_cloud_vm.sh` удаляет прежнюю ВМ вместе с диском и создаёт новую. Удалить вручную:

```bash
sudo virsh destroy ubuntu-cloud-cli
sudo virsh undefine ubuntu-cloud-cli --nvram
sudo rm -f /var/lib/libvirt/images/ubuntu-cli-vm.qcow2
```

> ⚠️ `create_vm.sh` и `create_cloud_vm.sh` используют один и тот же файл диска `/var/lib/libvirt/images/ubuntu-cli-vm.qcow2`. `create_cloud_vm.sh` его **удаляет** при запуске, поэтому не используйте оба скрипта для одной и той же ВМ.

---

## 🪟 Вариант B: Windows 10 (VMware Workstation)

Для Windows есть два скрипта. Они делают одно и то же (cloud-образ Debian 13 → VMDK → ВМ в VMware), но по-разному обращаются с уже существующими ВМ:

| | `create_vmware_vm.ps1` | `Auto-creating-vmware-debian_numbered.ps1` |
|---|---|---|
| Сколько ВМ | одна (`DebianCloudVM`) | сколько нужно, по одной за запуск |
| Если ВМ уже есть | останавливается с ошибкой; с `-Force` старая ВМ **удаляется** и создаётся заново | существующие ВМ не затрагиваются, создаётся следующая по номеру |
| Имя ВМ | `DebianCloudVM` | `DebianCloudVM-001`, `DebianCloudVM-002`, … |
| Пользователь в ВМ | `vmsk` | `vmsk-001`, `vmsk-002`, … (номер совпадает с номером ВМ) |
| Параметры запуска | `-Force` | нет |

### Требования (общие для обоих скриптов)

- **VMware Workstation** (с утилитой `vmrun.exe`): скрипт ищет её в `C:\Program Files (x86)\VMware\VMware Workstation\` и `C:\Program Files\VMware\VMware Workstation\`
- **QEMU for Windows** ([qemu.weilnetz.de/w64](https://qemu.weilnetz.de/w64/)): нужен только `qemu-img.exe`; скрипт находит его в `C:\Program Files\qemu\` или в `PATH`
- PowerShell 5.1 (встроен в Windows 10) **или новее**, в том числе PowerShell 7 (`pwsh`), и доступ в интернет
- Свободное место: образ (~400 МБ) скачивается один раз и кэшируется в `_cache`; диск каждой ВМ занимает до 20 ГБ

### B1. Одна ВМ: `create_vmware_vm.ps1`

#### Подготовка

Откройте `create_vmware_vm.ps1` и замените в блоке настроек свои значения:

```powershell
$sshUser   = 'vmsk'
$sshPubKey = 'ssh-ed25519 AAAA... ваш_ключ'
$passHash  = '$6$...'   # результат openssl passwd -6
```

Здесь же можно изменить имя ВМ, объём памяти (`$memMB`), число CPU (`$cpus`) и размер диска (`$diskSize`).

#### Запуск

```powershell
# Windows PowerShell 5.1 (встроенный)
powershell -ExecutionPolicy Bypass -File .\create_vmware_vm.ps1

# или PowerShell 7
pwsh -ExecutionPolicy Bypass -File .\create_vmware_vm.ps1
```

Если ВМ уже была создана этим скриптом, пересоздайте её с нуля (старая ВМ будет остановлена и удалена):

```powershell
powershell -ExecutionPolicy Bypass -File .\create_vmware_vm.ps1 -Force
```

Файлы ВМ создаются в папке `DebianCloudVM` рядом со скриптом. Для подключения используйте `ssh vmsk@<IP_АДРЕС_ВМ>`.

### B2. Серия ВМ: `Auto-creating-vmware-debian_numbered.ps1`

Скрипт предназначен для случая, когда нужно несколько одинаковых ВМ (стенд из нескольких узлов, отдельная ВМ на каждый эксперимент). Каждый запуск **добавляет одну новую ВМ** и ничего не удаляет.

#### Как выбирается номер

1. Скрипт просматривает папку, в которой лежит сам, и ищет подпапки с именем `DebianCloudVM-<число>`.
2. Выводит список найденных ВМ. Через `vmrun list` для каждой показано, запущена она или остановлена.
3. Находит наибольший номер среди найденных и прибавляет 1. Если ВМ ещё нет, создаётся `001`. Номер всегда записывается тремя цифрами.
4. По этому номеру формируются имена:

| Номер | Папка и имя ВМ | Пользователь | Hostname |
|-------|----------------|--------------|----------|
| 001 | `DebianCloudVM-001` | `vmsk-001` | `debiancloudvm-001` |
| 002 | `DebianCloudVM-002` | `vmsk-002` | `debiancloudvm-002` |
| 017 | `DebianCloudVM-017` | `vmsk-017` | `debiancloudvm-017` |

Папка `_cache` и «старая» папка `DebianCloudVM` без номера под шаблон не подходят: скрипт их не учитывает и не меняет.

#### Подготовка

Откройте скрипт и замените в блоке настроек свой публичный ключ. Хеш пароля не нужен: пароль в ВМ заблокирован, вход только по ключу.

```powershell
$vmPrefix   = 'DebianCloudVM'   # имя ВМ = <префикс>-<номер>
$userPrefix = 'vmsk'            # пользователь = <префикс>-<номер>
$sshPubKey  = 'ssh-ed25519 AAAA... ваш_ключ'
```

Здесь же можно изменить объём памяти (`$memMB`), число CPU (`$cpus`) и размер диска (`$diskSize`).

#### Запуск

```powershell
powershell -ExecutionPolicy Bypass -File .\Auto-creating-vmware-debian_numbered.ps1
```

Каждый запуск создаёт ещё одну ВМ. Пример вывода:

```
[*] Проверяю, есть ли уже созданные ВМ...
[+] Найдено существующих ВМ: 2
    DebianCloudVM-001  (запущена)
    DebianCloudVM-002  (остановлена)
[*] Создаю новую ВМ: DebianCloudVM-003 (пользователь: vmsk-003)
...
[SUCCESS] DebianCloudVM-003, IP: 192.168.x.x
    ssh vmsk-003@192.168.x.x
```

#### Что делает скрипт

1. Находит `qemu-img.exe` и `vmrun.exe`.
2. Ищет существующие ВМ и определяет номер новой (см. выше).
3. Генерирует `user-data` и `meta-data` (пользователь `vmsk-NNN`, ваш SSH-ключ, `sudo` без пароля) и собирает из них `seed.iso` (метка `cidata`, ISO9660 + **Joliet**).
4. Скачивает Debian 13 cloud image в `_cache`. Кэш общий для всех ВМ, поэтому образ скачивается один раз.
5. Расширяет диск до 20 ГБ и конвертирует qcow2 → VMDK.
6. Создаёт `.vmx` (4 CPU, 4 ГБ ОЗУ, сеть NAT, `seed.iso` как CD-ROM).
7. Запускает ВМ через `vmrun` и ждёт, пока cloud-init установит `open-vm-tools` и ВМ сообщит IP (до 8 минут).

#### Подключение

Имя пользователя содержит номер ВМ. Для `DebianCloudVM-003` это `vmsk-003`:

```powershell
ssh vmsk-003@<IP_АДРЕС_ВМ>
```

> ⚠️ Пользователя `vmsk` без номера в этих ВМ нет. Попытка зайти под ним даёт `Permission denied (publickey)`, как и при неверном ключе.

#### Удаление ВМ

Скрипт ВМ не удаляет. Чтобы убрать ненужную, остановите её и удалите папку:

```powershell
& "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe" -T ws stop .\DebianCloudVM-003\DebianCloudVM-003.vmx hard
Remove-Item .\DebianCloudVM-003 -Recurse -Force
```

#### Ограничения

- Существующие ВМ определяются **только по папкам рядом со скриптом**. ВМ, которые лежат в другом месте или были переименованы, скрипт не увидит.
- Номер — это максимальный найденный плюс 1. Если удалить последнюю ВМ (например, `005`), следующая снова получит номер `005`.
- Если запуск прервался на середине, остаётся незавершённая папка с номером. Следующий запуск посчитает её существующей ВМ и возьмёт следующий номер, поэтому такую папку лучше удалить вручную.

---

## 🐳 Демонстрация «ВМ + Контейнеризация»

Docker скриптами **не устанавливается**, поставьте его внутри ВМ самостоятельно. Например, на Ubuntu 24.04:

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2 git
```

Затем разверните тестовое приложение:

```bash
# Проверка версии Docker
docker --version

# Развёртывание тестового приложения
git clone https://github.com/dockersamples/example-voting-app.git
cd example-voting-app
sudo docker compose up -d
sudo docker compose ps          # опубликованные порты приложений
```

Приложение доступно по IP виртуальной машины на портах, указанных в `docker compose ps`.

---

## 🩺 Решение проблем

| Симптом | Что делать |
|---------|------------|
| `ssh` отвечает отказом в первые минуты после старта | Cloud-init ещё настраивает систему. Подождите 1–3 минуты и повторите |
| `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED` после пересоздания ВМ | Новая ВМ получила тот же IP, но другие ключи хоста: `ssh-keygen -R <IP>` |
| `Permission denied (publickey)` | В `user-data` / `$sshPubKey` не тот публичный ключ. Сверьте отпечатки: `ssh-keygen -lf ~/.ssh/id_ed25519.pub` |
| `Permission denied (publickey)` на ВМ из `..._numbered.ps1` | Проверьте имя пользователя: оно с номером (`vmsk-003`), а не просто `vmsk`. Скрипт печатает готовую команду `ssh` в конце |
| Не работает вход по паролю | Пароль заблокирован cloud-init по умолчанию. Добавьте `lock_passwd: false` (см. раздел про ключ и пароль) |
| `create_cloud_vm.sh` падает на копировании образа | Базовый образ не скачан в `/var/lib/libvirt/images/` или называется иначе (см. шаг 2 варианта A) |
| ВМ в VMware не получает IP | Проверьте, что ВМ загрузилась и cloud-init дошёл до конца: внутри ВМ `cloud-init status --long` |
| `..._numbered.ps1` создал ВМ с неожиданным номером | Скрипт считает только папки `DebianCloudVM-<число>` рядом с собой. Проверьте, где лежат ВМ и нет ли лишних или недоделанных папок |

---

# С любовью от **Vmsk_Wivi** 🌸
