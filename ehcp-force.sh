#!/bin/bash

read -p "Ketik yes kalau jaringan mau direstart. Restart jaringan? : " restartInput

## Ini untuk mengubah input user ke lowercase agar inputnya case-insensitive
restartInputLower=$(echo "$restartInput" | tr '[:upper:]' '[:lower:]')

## Restart jaringan
if [ "$restartInputLower" == "yes" ]; then
    echo "Jaringan bakal diatur ulang..."
    echo -e "# This file describes the network interfaces available on your system\n\
    # and how to activate them. For more information, see interfaces(5).\n\n\
    source /etc/network/interfaces.d/*\n\n\
    # The loopback network interface\n\
    auto lo\n\
    iface lo inet loopback\n\n\
    # The primary network interface\n\
    auto enp0s3\n\
    iface enp0s3 inet dhcp" > /etc/network/interfaces
    systemctl restart networking
    export pid=$!
    wait $pid
    echo "Konfigurasi IP yang baru setelah direstart :"
    sleep 3
    ip a
else
    echo "Jaringan gak bakal di restart :)"
fi

## Ganti Repo
echo -e "\n\n\nGanti repositori ke repositori default Debian?\nBiasanya, repo default dari vmdk SMK 22 itu repo.antix.or.id."
read -p "Ketik yes untuk ganti, no kalau nggak mau : " repoInput

repoInputLower=$(echo "$repoInput" | tr '[:upper:]' '[:lower:]')

if [ "$repoInputLower" == "yes" ]; then
    echo "Repositori diganti ke default, edit /etc/apt/sources.list untuk mengganti."
    sleep 3
    echo -e "deb http://deb.debian.org/debian bullseye main contrib non-free\n\
    deb-src http://deb.debian.org/debian bullseye main contrib non-free\n\n\
    deb http://deb.debian.org/debian-security/ bullseye-security main contrib non-free\n\
    deb-src http://deb.debian.org/debian-security/ bullseye-security main contrib non-free\n\n\
    deb http://deb.debian.org/debian bullseye-updates main contrib non-free\n\
    deb-src http://deb.debian.org/debian bullseye-updates main contrib non-free" > /etc/apt/sources.list
    
    apt update
else
    echo "Repositori tidak diganti. Pastikan repositori yang dipakai aktif!"
fi

## Update Repo
echo "Lagi update repo... Sabar yah"
apt update > /dev/null 2>&1
export pid=$!
wait $pid
apt install wget sudo -y

## Instal EHCP
adduser ehcp
usermod -aG sudo ehcp

wget -O "ehcpforce_stable_snapshot.tar.gz" -N https://github.com/earnolmartin/EHCP-Force-Edition/releases/download/1.1.1.1/ehcpforce_stable_snapshot.tar.gz
tar -zxvf "ehcpforce_stable_snapshot.tar.gz"
cd ehcp
sudo bash install.sh
