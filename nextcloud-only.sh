#!/bin/bash

echo -e "This script will only install services necessary for Nextcloud 28.0.3, excluding PHP 8!\nCtrl+C in 10 seconds to cancel!"
sleep 10
echo -e "auto lo\niface lo inet loopback\n\nauto enp0s3\niface enp0s3 inet dhcp" > /etc/network/interfaces
systemctl restart networking

apt update
sleep 2

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

## Apache2 and php module
apt install -y apache2 libapache2-mod-php wget unzip
systemctl status apache2

while true; do
    echo -e "Do you want to automatically create a domain for nextcloud?\nThe created domain would be www.yourcloud.com, you can edit this later (yes/no): "
    read -p webcreate

    case $webcreate in
        [Yy]|[Yy][Ee][Ss])
            cd /etc/apache2/sites-available
            a2dissite 000-default.conf
            cp 000-default.conf nextcloud.conf
            sed -i "s/#ServerName www.example.com/ServerName www.yourcloud.com/"
            sed -i "s|/var/www/html|/var/www/nextcloud|"
            a2ensite nextcloud.conf
            break
            ;;
        [Nn]|[Nn][Oo])
            echo "Domain for your nextcloud won't be automatically created."
            break
            ;;
        *)
            echo "Please answer with yes or no!"
            ;;
    esac
done

## Necessary PHP modules
apt install -y php8.2 php8.2-gd php8.2-curl php8.2-xml php8.2-simplexml php8.2-mbstring php8.2-zip php8.2-dom

## MySQL
apt install -y mysql-server php8.2-mysql

## Downloading Nextcloud
cd /var/www
wget https://download.nextcloud.com/server/releases/nextcloud-28.0.3.zip
unzip ./nextcloud-28.0.3.zip
systemctl restart apache2 mysql-server
echo -e "\nProcesses completed. But you still NEED to configure the database and web server!"
sleep 1
echo "Here is an example of MySQL database config :"
echo -e "CREATE DATABASE nextclouddb;\
\nGRANT ALL ON nextclouddb.* TO 'nextcloud_user'@'localhost' IDENTIFIED BY 'strong password';\
\nFLUSH PRIVILEGES;\
\nEXIT;"
