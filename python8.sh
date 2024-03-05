#!/bin/bash

## Taken from https://computingforgeeks.com/how-to-install-php-on-debian-linux/
echo -e "auto lo\niface lo inet loopback\n\nauto enp0s3\niface enp0s3 inet dhcp" > /etc/network/interfaces
systemctl restart networking

apt update
sleep 2

echo "Installing necessary packages first..."
sleep 1
apt install wget -y

while true; do
    read -p "Do you want to upgrade your system? (yes/no): " answer

    case $answer in
        [Yy]|[Yy][Ee][Ss])
            sudo apt upgrade
            break
            ;;
        [Nn]|[Nn][Oo])
            echo "Your system won't be upgraded."
            break
            ;;
        *)
            echo "Please answer with yes or no!"
            ;;
    esac
done

echo "Adding deb.sury.org repository to /etc/apt/sources.list."
sleep 3
echo "Installing necessary packages first..."
sleep 3
apt install -y lsb-release ca-certificates apt-transport-https software-properties-common gnupg2
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
wget -qO - https://packages.sury.org/php/apt.gpg | apt-key add -

apt update

echo -e "\n\nSury repository for PHP 8 has been added\nThe current repository have PHP version of 8.0 and 8.2\nPut this command on your terminal for checking PHP version: php -v\nTo install php modules/extensions, use this format (without the <>):\napt install php8.0-<extension>"
sleep 2
echo -e "\nNeed further information? Contact me on Instagram @envrmore, or Github @Envrmore"