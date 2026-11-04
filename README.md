# 🚀 Применение технологии виртуальных машин для решения задач администрирования

<p align="center">
  <b>Разработка практического стенда виртуализации на базе KVM/QEMU и Cloud-init</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/OS-Debian%2013-blueviolet?style=for-the-badge&logo=debian" alt="Debian 13">
  <img src="https://img.shields.io/badge/Hypervisor-KVM%20%2F%20QEMU-orange?style=for-the-badge&logo=linux" alt="KVM">
  <img src="https://img.shields.io/badge/Automation-Cloud--init-green?style=for-the-badge" alt="Cloud-init">
  <img src="https://img.shields.io/badge/Containers-Docker-blue?style=for-the-badge&logo=docker" alt="Docker">
</p>

---

## 📌 О проекте

Данный репозиторий содержит практические материалы, скрипты автоматизации и конфигурационные файлы, разработанные в рамках курсового проекта.

Проект посвящен исследованию возможностей технологии виртуализации и её практическому применению для решения типовых задач системного и сетевого администрирования с использованием подходов **Infrastructure as Code (IaC)**[cite: 1].

---

## 🛠️ Технологический стек

| Категория | Технологии |
|---|---|
| **Хост-система** | Debian 13 (Trixie)[cite: 1] |
| **Гипервизор и управление** | KVM, QEMU, `libvirt`, `virsh`, `virt-install`[cite: 1] |
| **Автоматизация деплоя** | Cloud-init (`user-data`, `meta-data`), Bash-скрипты[cite: 1] |
| **Контейнеризация** | Docker, Docker Compose (стек `example-voting-app`)[cite: 1] |

---

## 📂 Структура репозитория

```text
.
├── 📜 create_vm.sh        # Скрипт создания ВМ из ISO-образа через virt-install
├── ⚡ create_cloud_vm.sh  # IaC-скрипт деплоя cloud-образа (авторасширение диска + cloud-init)
├── ⚙️ user-data         # Декларативная конфигурация пользователей, SSH-ключей и пакетов
└── 🌐 meta-data         # Метаданные хоста (hostname, instance-id)

```

### 💡 Краткое описание компонентов:

* **`create_vm.sh`** — bash-скрипт для классического развертывания ВМ из ISO-образа.


* **`create_cloud_vm.sh`** — скрипт автоматизированного развертывания облачного образа Ubuntu с авто-расширением хранилища до 20 ГБ с помощью `qemu-img` и подавлением консольного вывода.


* **`user-data`** — конфиг Cloud-init для автоматического создания пользователя, добавления SSH-ключей, настройки `sudo` и обновления пакетов.


* **`meta-data`** — служебный файл для инициализации сетевого имени хоста.



---

## 🚀 Быстрый старт

### 1. Подготовка хост-системы

Установите необходимый стек пакетов виртуализации:

```bash
sudo apt update
sudo apt install qemu-system libvirt-daemon-system libvirt-clients bridge-utils virtinst cloud-image-utils -y

```

Запустите службу `libvirtd` и добавьте её в автозагрузку:

```bash
sudo systemctl enable --now libvirtd

```

Добавьте вашего пользователя в группы `libvirt` и `kvm`:

```bash
sudo usermod -aG libvirt,kvm $USER
newgrp libvirt
newgrp kvm

```

---

### 2. Запуск автоматического деплоя

Перейдите в каталог с материалами репозитория:

```bash
cd /var/lib/libvirt/images/

```

Сделайте скрипт исполняемым и запустите деплой:

```bash
chmod +x create_cloud_vm.sh
./create_cloud_vm.sh

```

---

### 3. Подключение к развернутой ВМ

Узнайте IP-адрес, выданный DHCP-сервером `libvirt`:

```bash
sudo virsh net-dhcp-leases default

```

Подключитесь к виртуальной машине по SSH по вашему ключу/паролю:

```bash
ssh ubuntu_auto_1@<IP_АДРЕС_ВМ>

```

---

## 🐳 Демонстрация «ВМ + Контейнеризация»

Внутри созданной виртуальной машины развернута микросервисная среда Docker для проверки изоляции и работы приложений:

```bash
# Проверка версии Docker
docker --version

# Развертывание тестового приложения из репозитория
git clone [https://github.com/dockersamples/example-voting-app.git](https://github.com/dockersamples/example-voting-app.git)
cd example-voting-app
sudo docker compose up -d

```

---

С любовью от **Vmsk_Wivi** 🌸
=======
