#!/bin/bash

echo "Создание и запуск облачной виртуальной машины..."

# Останавливаем скрипт при любой ошибке
set -e

VM_NAME="ubuntu-cloud-cli"
DISK_PATH="/var/lib/libvirt/images/ubuntu-cli-vm.qcow2"
BASE_IMAGE="/var/lib/libvirt/images/ubuntu-24.04-server-cloudimg-amd64.img"
SEED_ISO="/var/lib/libvirt/images/seed.iso"

echo "1. Удаляем старую виртуалку и диск (если они существовали)..."
sudo virsh destroy "$VM_NAME" >/dev/null 2>&1 || true
sudo virsh undefine "$VM_NAME" --nvram >/dev/null 2>&1 || true
sudo rm -f "$DISK_PATH"

echo "2. Генерируем свежий seed.iso с настройками (cloud-init)..."
sudo cloud-localds "$SEED_ISO" user-data meta-data

echo "3. Создаем свежий диск из базового cloud-образа..."
sudo cp "$BASE_IMAGE" "$DISK_PATH"

echo "4. Автоматически расширяем диск до 20 ГБ..."
sudo qemu-img resize "$DISK_PATH" 20G

# 2. Затем запускаем виртуалку
sudo virt-install \
  --name "$VM_NAME" \
  --memory 4092 \
  --vcpus 3 \
  --disk path="$DISK_PATH",size=20,format=qcow2 \
  --cdrom "$SEED_ISO" \
  --os-variant ubuntu24.04 \
  --network network=default \
  --graphics none \
  --import \
  --noautoconsole

echo "Готово! Виртуальная машина создана, а диск сразу увеличен до 20 ГБ."
