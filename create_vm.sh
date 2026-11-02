#!/bin/bash

echo "Создание и запуск виртуальной машины..."

sudo virt-install \
  --name ubuntu-vm-cli \
  --memory 2048 \
  --vcpus 2 \
  --disk path=/var/lib/libvirt/images/ubuntu-cli-vm.qcow2,size=20,format=qcow2 \
  --cdrom  /home/vmsk/Documents/oc/ubuntu-26.04-live-server-amd64.iso \
  --os-variant ubuntu24.04 \
  --network network=default \
  --graphics vnс
