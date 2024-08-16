#!/bin/bash

if (( $EUID != 0 )); then
    echo "Please execute as root, now exiting."
fi

apt update

for pkgs in apache2 rrdtool mariadb-server mariadb-client snmp snmpd php php-mysql php-snmp php-xml php-mbstring php-json php-gd php-gmp php-zip php-ldap php-mc; do
    apt install $pkgs -y
done

function cactiGit() {
    apt install git -y

    git clone -b 1.2.x  https://github.com/Cacti/cacti.git

    while true; do
        read -rp "Move cacti to /var/www/html? [y/n] : " movecacti
        case "$movecacti" in
            y|Y)
            mv cacti /var/www/html
            cp /var/www/html/config.php.dist /var/www/htmlconfig.php
            break;;

            n|N)
            echo "Cacti won't be moved."
            break;;

            *)
            echo "Not a valid answer."
        esac
    done
}

function dbCreation() {
    mysql_secure_installation

    read -rp "Root account password for cacti database : " PASS

mysql -u root -p <<EOF
CREATE DATABASE cacti DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
GRANT ALL PRIVILEGES ON cacti.* TO 'cacti'@'localhost' IDENTIFIED BY 'cacti';
GRANT SELECT ON mysql.time_zone_name TO cacti@localhost;
ALTER DATABASE cacti CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
FLUSH PRIVILEGES;

EOF

    mysql -u root cacti < /var/www/html/cacti/cacti.sql
}

while true; do
    echo -e "Which version of cacti that should be used?"
    read -rp "(g)it   (d)eb   (h)elp : " CACTI_VER
    case "$CACTI_VER" in
        g|G)
        cactiGit
        while true; do
            read -rp "Preconfigure the database? [y/N] : " DB_CONFIG
            case "$DB_CONFIG" in
                y|Y)
                echo "The preconfigured database information is saved in /root/cactidb.info."
                dbCreation
                break;;

                n|N)
                echo "You will need to create the database manually."
                break;;

                *)
                echo "Not a valid answer"
            esac
        done
        break;;

        d|D)
        apt install cacti -y
        break;;

        h|H)
        echo -e "\n---> Git version\nChoosing this will install git and clone cacti from https://github.com/Cacti/cacti.git\nThen you can choose to prepopulate the database or configure it manually."
        echo -e "\n---> Debian package version\nChoosing this will install cacti using apt.\nDpkg will summon the database configuration for you.\n"
        ;;

        *)
        echo -e "\nNot a valid answer. Choose between g/d/h"
    esac
done