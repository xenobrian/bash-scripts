#!/bin/bash

if (( $EUID != 0 )); then
    echo "Please execute as root, now exiting."
fi

function cactiDependencies() {
    apt update

    for pkgs in git apache2 rrdtool mariadb-server mariadb-client snmp snmpd php7.0 php-mysql php7.0-snmp php7.0-xml php7.0-mbstring php7.0-json php7.0-gd php7.0-gmp php7.0-zip php7.0-ldap php7.0-mc; do
        apt install $pkgs -y
    done
}

function cactiDownload() {
    git clone -b 1.2.x  https://github.com/Cacti/cacti.git
    read -rp "Move cacti to /var/www/html? [y/n] : " movecacti

    while true; do
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
    yes | mysql_secure_installation

    read -rp "Root account password for cacti database : " PASS

    mysql -u root -p "$PASS" <<EOF
CREATE DATABASE cacti DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci ;
GRANT ALL PRIVILEGES ON cacti.* TO 'cacti'@'localhost' IDENTIFIED BY 'cacti';
GRANT SELECT ON mysql.time_zone_name TO cacti@localhost;
ALTER DATABASE cacti CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
FLUSH PRIVILEGES;
EOF

    mysql -u root cacti < /var/www/html/cacti/cacti.sql
}

cactiDependencies
cactiDownload
dbCreation