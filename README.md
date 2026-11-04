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

Данный репозиторий содержит практические материалы, скрипты автоматизации и конфигурационные файлы, разработанные в рамках курсового проекта:

Проект посвящен исследованию возможностей технологии виртуализации и её практическому применению для решения типовых задач системного и сетевого администрирования с использованием подходов **Infrastructure as Code (IaC)**.

---

## 🛠️ Технологический стек

| Категория | Технологии |
|---|---|
| **Хост-система** | Debian 13 (Trixie) |
| **Гипервизор и управление** | KVM, QEMU, `libvirt`, `virsh`, `virt-install` |
| **Автоматизация деплоя** | Cloud-init (`user-data`, `meta-data`), Bash-скрипты |
| **Контейнеризация** | Docker, Docker Compose (стек `example-voting-app`) |

---

## 📂 Структура репозитория

```text
.
├── 📜 create_vm.sh        # Скрипт создания ВМ из ISO-образа через virt-install
├── ⚡ create_cloud_vm.sh  # IaC-скрипт деплоя cloud-образа (авторасширение диска + cloud-init)
├── ⚙️ user-data         # Декларативная конфигурация пользователей, SSH-ключей и пакетов
└── 🌐 meta-data         # Метаданные хоста (hostname, instance-id)