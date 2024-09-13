#!/bin/bash

# Script pre-run warning
echo -e "Executing full-fledged.sh..."

# Check whether the user is root or not
if (( "$EUID" != 0 )); then
    echo "You are not root. Please run as root, now exiting."
    exit
fi

read -rp "######### UNFINISHED SCRIPT #########\n\
Do not execute this script in a deployment-ready server!\n\
(P)roceed       (A)bort : " WARNING
case "$WARNING" in
    p|P)
    echo "Note that you do this with your own decision!"
    break;;

    a|A)
    echo "Exiting."
    exit;;
esac

echo -e "Main packages that will be installed :\nWeb Server\t: Apache2\nMail Server\t: Postfix, Dovecot (POP3 and IMAP), Roundcube\nDatabase\t: MariaDB Server, Phpmyadmin\nMonitoring\t: Cacti\nCMS\t\t: Wordpress"; sleep 1
echo -e "Before installing, please make sure that this host is able to reach the internet. Ctrl+C to cancel in 5 seconds..."; sleep 5
echo "Starting installation!";

# Repository update
echo "Updating repositories..."
apt update > /dev/null 2>&1; export pid=$!; wait $pid
echo "Repositories has been updated. Now checking for necessary packages..."

packageChecker () {
    local packagename="$1"
    if ! hash "$packagename" 2> /dev/null; then
        echo "The command '$packagename' is not installed, will install now."
        apt install "$packagename" -y
    else
        echo "'$packagename' is already installed."
    fi
}

for x in net-tools sed wget unzip curl; do
    packageChecker "$x" -y
done

# Network Configuration
# while true; do
#     echo "Network configuration, please use lowercase on all."; sleep 1
#     read -rp "Do you use NetworkManager as your main network manager? [yes/no] : " NMEXIST
#     case "$NMEXIST" in
#         [y][e][s])
#         break;;

#         [n][o])
#         read -rp "Network configuration method, static or dhcp? [dhcp]: " NWMETHOD
#         NWMETHOD=${NWMETHOD:-dhcp}

#         case "$NWMETHOD" in
#             [s][t][a][t][i][c])
#             while true; do
#                 read -rp "Which interface should be configured(e.g enp0s3, eth0)[enp0s3]: " HOSTINT
#                 HOSTINT=${HOSTINT:-enp0s3}

#                 while true; do
#                     read -rp "Configure your IP address [192.168.0.2] : " HOSTIP
#                     HOSTIP=${HOSTIP:-192.168.0.2}
#                     if [[ $HOSTIP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
#                         break
#                     else
#                         echo "Invalid host IP address format. Please try again."
#                     fi
#                 done

#                 while true; do
#                     read -rp "Configure your netmask [255.255.255.0] : " HOSTNETMASK
#                     HOSTNETMASK=${HOSTNETMASK:-255.255.255.0}
#                     if [[ $HOSTNETMASK =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
#                         break
#                     else
#                         echo "Invalid network mask format. Please try again."
#                     fi
#                 done

#                 while true; do
#                 read -rp "Configure your gateway [192.168.0.1] : " HOSTGW
#                 HOSTGW=${HOSTGW:-192.168.0.1}
#                     if [[ $HOSTGW =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
#                         break
#                     else
#                         echo "Invalid gateway IP address format. Please try again."
#                     fi
#                 done

#                 while true; do
#                 read -rp "Configure which DNS nameserver(s) to use [192.168.0.1] : " HOSTDNS
#                 HOSTDNS=${HOSTDNS:-192.168.0.1}
#                     if [[ $HOSTDNS =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
#                         break
#                     else
#                         echo "Invalid DNS name server address format. Please try again."
#                     fi
#                 done

#                 while true; do
#                     echo "### Review your configuration"
#                     while true; do
#                         echo -e "Your IP configuration as follows :\nInterface\t: $HOSTINT\nIP address\t: $HOSTIP\nNetmask\t\t: $HOSTNETMASK\nGateway\t\t: $HOSTGW\nDNS server\t: $HOSTDNS"
#                         read -rp "Is this correct?[yes/no] : " USERDECISION

#                     case "$USERDECISION" in
#                         [yY][eE][sS])
#                         echo "Network will be set as the configuration above"
#                         interfaceConfig () {
#                             local int="$HOSTINT"; local ip="$HOSTIP"; local mask="$HOSTNETMASK"; local gw="$HOSTGW"; local dns="$HOSTDNS"

#                             sed -i "s|allow-hotplug $HOSTINT|auto $HOSTINT|" /etc/network/interfaces
#                             sed -i "s|iface $int inet dhcp|iface $int inet static\n\taddress $ip\n\tnetmask $mask\n\tgateway $gw\n\tdns-nameservers $dns|" /etc/network/interfaces
#                         }

#                         interfaceConfig "$HOSTINT"
#                         break 4;;

#                         [nN][oO])
#                         echo "Restarting configuration..."
#                         break 2;;

#                         *)
#                         echo "Please choose 'yes' or 'no'"
#                         break;;
#                     esac
#                     done

#                 done
#                 break
#             done;;

#             [d][h][c][p])
#             echo "You chose DHCP. Now sending DHCPREQUEST..."; sleep 5
#             ## cp /etc/network/interfaces /etc/network/interfaces.bak; echo -e "\n\n\nThis file is the backup for the original file"
#             ## DHCP request command
#             export pid=$!; wait $pid
#             echo "DHCP request succesfully done"
#             break;;
#         esac
#     esac
# done

# echo "Succesfully changed the network configuration!"

# systemctl restart networking
# export pid=$!; wait $pid

# # Static to dhcp[[:space:]]\+[0-9.] is looking for a sequence of one or more whitespace characters followed by digits and/or dots.
# sed -i '/iface enp0s3 inet static/ {
#     s/iface enp0s3 inet static/iface enp0s3 inet dhcp/
#     s/address[[:space:]]\+[0-9]\+/#address/
#     s/netmask[[:space:]]\+[0-9]\+/#netmask/
#     s/gateway[[:space:]]\+[0-9]\+/#gateway/
# }' /etc/network/interfaces

# Apache2 install and configuration
echo "Installing necessary packages..."
apt install apache2 libapache2-mod-php -y ## > /dev/null 2>&1
export VHOST_PATH=/etc/apache2/sites-available

echo "Apache2 configuration section. Input carefully."
while true; do
    while true; do
        read -rp "What domain name would you like to use?(use FQDN)[www.example.org] : " DOMAIN_NAME
        DOMAIN_NAME=${DOMAIN_NAME:-www.example.com}
        cp $VHOST_PATH/000-default.conf $VHOST_PATH/template.conf
        sed -i '22,28d' $VHOST_PATH/template.conf
        sed -i '14,19d' $VHOST_PATH/template.conf
        sed -i '2,8d' $VHOST_PATH/template.conf

        cp $VHOST_PATH/template.conf $VHOST_PATH/$DOMAIN_NAME.conf
        sed -i "s/#ServerName www.example.com/ServerName $DOMAIN_NAME/" $VHOST_PATH/$DOMAIN_NAME.conf

        echo "Make sure that your website directory exists."
        read -rp "Specify the path of this website's directory [/var/www/html] : " WEB_PATH
        WEB_PATH=${WEB_PATH:-/var/www/html}
        sed -i "s|DocumentRoot /var/www/html|DocumentRoot $WEB_PATH|" $VHOST_PATH/$DOMAIN_NAME.conf

        echo "Since you are root, the user:group of the $WEB_PATH is probably root:root."
        while true; do
            read -rp "Change user:group ownership of $WEB_PATH? [y/N] : " OWNER_CHANGE_DECISION
            case "$OWNER_CHANGE_DECISION" in
                y|Y)
                read -rp "Chown to [user:group] : " CHOWN
                chown $CHOWN $WEB_PATH
                break;;

                n|N)
                break;;

                *)
                echo "Not a valid answer."
            esac
        done

        while true; do
            read -rp "Enable the website now? [y/N] : " ENABLE_WEB_DECISION
            case "$ENABLE_WEB_DECISION" in
                y|Y)
                a2ensite $DOMAIN_NAME
                break;;

                n|N)
                break;;

                *)
                echo "Not a valid answer."
            esac
        done

        while true; do
            read -rp "Create another website? [y/N] : " CREATE_WEB_DECISION
            case "$CREATE_WEB_DECISION" in
                y|Y)
                break 2;;

                n|N)
                break 3;;

                *)
                echo "Not a valid answer."
            esac
        done
    done
done

systemctl restart apache2.service && systemctl status apache2

# Bind9 install and configuration
echo "Will install and configure Bind9..."
apt install bind9 bind9utils dnsutils -y ##> /dev/null 2>&1
echo "We will configure Bind9 now..."; sleep 2

BIND_PATH=/etc/bind

function zoneFileCreate {
    local filename="$1"
    local ptrfile="$2"
    cp $BIND_PATH/db.local $BIND_PATH/db.$filename
    cp $BIND_PATH/db.127 $BIND_PATH/db.$ptrfile
}

function zoneFileEdit {
    local filename="$1"
    local ns="$2"
    sed -i "s/localhost/$ns"
}

function subdomainCreate {
    local subdomain="$1"
    local record="$2"
    local ip="$3"

    echo -e "$subdomain\tIN\t$record\t$ip" >> $BIND_PATH/db.$FILE_NAME
}

function bindscriptconfig {
    read -rp "Replace 'localhost' in db.$FILE_NAME with your own domain [example.net] : " REPLACE
    sed -e "s/localhost/$REPLACE/" -e "s/.localhost/.$REPLACE/" $BIND_PATH/db.$FILE_NAME

    while true; do
        read -rp "What subdomain would you like to create? [ns1/www/ftp/other] : " SUBDOMAIN
        read -rp "What kind of record is it? [A/AAAA/CNAME/MX/NS/SRV] : " RECORD

        while true; do
        read -rp "To which IP it belongs to? [192.168.0.3] : " SUBDOMAIN_IP
            SUBDOMAIN_IP=${SUBDOMAIN_IP:-192.168.0.3}
            if [[ $SUBDOMAIN_IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                subdomainCreate "$SUBDOMAIN" "$RECORD" "$SUBDOMAIN_IP"
                break 2
            else
                echo "Invalid IP address format. Please try again."
            fi
        done

        while true; do
            read -rp "Create another subdomain? [y/N] : " SUBDOMAIN_RECREATE_DECISION
            case "$SUBDOMAIN_RECREATE_DECISION" in
                y|Y)
                break;;

                n|N)
                break 2;;
            esac
        done
    done
}

while true; do
    read -rp "Input the name for zone file. db.((name)) : " FILE_NAME
    read -rp "Input the name for PTR record file. db.((number)) : " PTR_FILE_NAME
    zoneFileCreate "$FILE_NAME" "$PTR_FILE_NAME"

    while true; do
        echo "You will need to edit these files :"
        echo -e "- The zone file (db.$FILE_NAME)\n\
        - PTR records file (db.$PTR_FILE_NAME)\n\
        - Local DNS server configuration file (named.conf.local)\n\
        - Bind9 settings (named.conf.options)\n\
        Choose which tool to use : "
        read -rp "(N)ano       (V)im       (S)cript       (A)bort: " EDIT_METHOD
        case "$EDIT_METHOD" in
            n|N)
            packageChecker "nano" -y
            nano $BIND_PATH/db.$FILE_NAME
            nano $BIND_PATH/db.$PTR_FILE_NAME
            nano $BIND_PATH/named.conf.local
            nano $BIND_PATH/named.conf.options
            break 2;;

            v|V)
            packageChecker "vim" -y
            vim $BIND_PATH/db.$FILE_NAME
            vim $BIND_PATH/db.$PTR_FILE_NAME
            vim $BIND_PATH/named.conf.local
            vim $BIND_PATH/named.conf.options
            break;;

            s|S)
            bindscriptconfig
            break;;

            a|A)
            break;;

            *)
            echo "Not a valid answer."
        esac
    done

    while true; do
        read -rp "Create another file? [y/N] : " CREATE
        case "$CREATE" in
            y|Y)
            break;;

            n|N)
            break 2;;

            *)
            echo "Not a valid answer."
        esac
    done
done

systemctl restart bind9 && systemctl status bind9

# PHP
for pkgs in php php-mysql php-snmp php-xml php-mbstring php-json php-gd php-gmp php-zip php-ldap php-mc php-curl php-dom php-simplexml; do
    apt install $pkgs -y
done

# Database (MariaDB)
apt install mariadb-server
mysql_secure_installation

# Mail Server (Postfix and Dovecot)
echo "Installing Postfix, Dovecot, and related packages..."
apt install postfix dovecot-imapd dovecot-pop3d -y

PATH=/etc/dovecot/conf.d

sed -i 's/home_mailbox = Maildir/#home_mailbox = Maildir/' /etc/postfix/main.cf
maildirmake.dovecot /etc/skel/Maildir
dpkg-reconfigure postfix
systemctl restart postfix

sed -i 's/# listen = */listen = */' /etc/dovecot/dovecot.conf
sed -i 's/# disable_plaintext_auth = yes/disable_plaintext_auth = no/' $PATH/10-auth.conf
sed -i 's/# mail_location = maildir:~/Maildir/mail_location = maildir:~/Maildir/' $PATH/10-mail.conf
sed -i 's/mail_location = mbox:~/mail:INBOX=/var/mail/%u/# mail_location = mbox:~/mail:INBOX=/var/mail/%u/' $PATH/10-mail.conf
systemctl restart dovecot

# echo "home_mailbox = Maildir/" >>  /etc/postfix/main.cf
# echo "message_size_limit = 20480000" >> /etc/postfix/main.cf
# systemctl restart postfix

# Roundcube
apt install roundcube

while true; do
    while true; do
        read -rp "Mail server domain name (use FQDN) [mail.example.net] : " MAILSERV_DOM
        MAILSERV_DOM=${MAILSERV_DOM:-mail.example.net}

        read -rp "SMTP server domain name [example.net] : " SMTP_DOM
        MAILSERV_DOM=${MAILSERV_DOM:-example.net}

        sed -i "s/$config['smtp_port'] = 587/$config['smtp_port'] = 25/" /etc/roundcube/config.inc.php
        sed -i "s/$config['smtp_user'] = '%u';/$config['smtp_user'] = '';/" /etc/roundcube/config.inc.php
        sed -i "s/$config['smtp_pass'] = '%p';/$config['smtp_pass'] = '';/" /etc/roundcube/config.inc.php

        while true; do
            read -rp "Reconfigure Roundcube? This command will run dpkg-reconfigure [y/N]: " RECONFIG
            case "$RECONFIG" in
                y|Y)
                dpkg-reconfigure roundcube-core
                ;;

                n|N)
                break;;

                *)
                echo "Not a valid choice. Please choose correctly"
                ;;
            esac
        done
        break 2
    done
done

# Cacti
for pkgs in rrdtool mariadb-client snmp snmpd cacti; do
    apt install $pkgs -y
done