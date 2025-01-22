#!/bin/bash

# Script pre-run warning
echo -e "Executing full-fledged.sh..."

# Check whether the user is root or not
if (( "$EUID" != 0 )); then
    echo "You are not root. Please run as root, now exiting."
    exit
fi

echo "------------> UNFINISHED SCRIPT <------------"
echo "Do not execute this script in a deployment-ready server!"

while true; do
read -rp "(P)roceed          (A)bort : " WARNING
  case "$WARNING" in
      p|P)
      echo "Note that you do this with your own decision!"
      break
      ;;

      a|A)
      echo "Exiting."
      break
      ;;

      *)
      echo "Not a valid option."
      ;;
  esac
done

echo -e "Main packages that will be installed :\nWeb Server\t: Apache2\nMail Server\t: Postfix, Dovecot (POP3 and IMAP), Roundcube\nDatabase\t: MariaDB Server, Phpmyadmin\nMonitoring\t: Cacti\nCMS\t\t: Wordpress"; sleep 1
echo -e "Before installing, please make sure that this host is able to reach the internet. Ctrl+C to cancel in 5 seconds..."; sleep 5
echo "Starting installation!";

# Repository update
echo "Updating repositories..."
apt update ## > /dev/null 2>&1; export pid=$!; wait $pid
echo "Repository cache has been updated. Now checking for necessary packages..."

packageChecker () {
    local packagename="$1"
    if ! hash "$packagename" 2> /dev/null; then
        echo "The command '$packagename' is not installed, will install now."
        apt install "$packagename" -y
    else
        echo "'$packagename' is already installed."
    fi
}

for x in net-tools sed wget unzip curl awk; do
    packageChecker "$x" -y
done

# Apache2 install and configuration
echo "Installing necessary packages..."
apt install apache2 libapache2-mod-php -y ## > /dev/null 2>&1
CONF_PATH=/etc/apache2/sites-available

cp $CONF_PATH/000-default.conf $CONF_PATH/template.conf
sed -i '22,28d' $CONF_PATH/template.conf
sed -i '14,19d' $CONF_PATH/template.conf
sed -i '2,8d' $CONF_PATH/template.conf

echo "Apache2 configuration section. Input carefully."
while true; do
    while true; do
        read -rp "What is the name for the vhost config file? [web.conf] : " VHOST_FILENAME
        read -rp "What domain name would you like to point the vhost to? [example.com] : " DOMAIN_NAME
        read -rp "Set up an alias (ServerAlias directive)? Empty for none : " ALIAS_NAME
        read -rp "Specify the path of this website's directory [/var/www/html] : " ROOT_WEBDIR

        VHOST_FILENAME=${VHOST_FILENAME:-web.conf}
        DOMAIN_NAME=${DOMAIN_NAME:-example.com}
        if [[ -z $ROOT_WEBDIR ]]; then
            ROOT_WEBDIR="/var/www/html"
        fi

        cp $CONF_PATH/template.conf $CONF_PATH/$VHOST_FILENAME
        sed -i "s/#ServerName www.example.com/ServerName $DOMAIN_NAME/" $CONF_PATH/$VHOST_FILENAME

        if [[ -d $ROOT_WEBDIR ]]; then
            sed -i "s|DocumentRoot /var/www/html|DocumentRoot $ROOT_WEBDIR|" $CONF_PATH/$VHOST_FILENAME
        else
            mkdir -p $ROOT_WEBDIR
            sed -i "s|DocumentRoot /var/www/html|DocumentRoot $ROOT_WEBDIR|" $CONF_PATH/$VHOST_FILENAME
        fi

        if [[ -n $ALIAS_NAME ]]; then
            TMPFILE=$(mktemp /tmp/apache2-config-XXX.tmp)
            awk "/ServerName/ { print; print \"\tServerAlias $ALIAS_NAME\"; next }1" $CONF_PATH/$VHOST_FILENAME > $TMPFILE
            cat $TMPFILE | tee $CONF_PATH/$VHOST_FILENAME
            rm $TMPFILE
        fi

        echo "Since you are root, the user:group of the $ROOT_WEBDIR is probably root:root."
        while true; do
            read -rp "Change user:group ownership of $ROOT_WEBDIR? [y/N] : " OWNER_CHANGE_DECISION
            case "$OWNER_CHANGE_DECISION" in
                y|Y)
                read -rp "Chown to [user:group] : " CHOWN
                chown -R $CHOWN $ROOT_WEBDIR
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
                a2ensite $VHOST_FILENAME
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

systemctl restart apache2 && systemctl status apache2

# Bind9 install and configuration
echo "Will install and configure Bind9..."
apt install bind9 bind9utils dnsutils -y ##> /dev/null 2>&1
echo "We will configure Bind9 now..."; sleep 2


function ZoneFileEdit {
    local filename="$1"
    local domain_name="$2"

    sed -i "s/localhost/$domain_name/" /etc/bind/db.$filename
    sed -i "s/.localhost/.$domain_name/" /etc/bind/db.$filename
    cat /etc/bind/db.$filename
}

function PointerFileEdit {
    local filename="$1"
    local domain_name="$2"
    local ip_host="$3"

    sed -i "s/localhost/$domain_name/" /etc/bind/db.$filename /etc/bind/db.$filename
    sed -i "s/.localhost/.$domain_name/" /etc/bind/db.$filename /etc/bind/db.$filename
    sed -e "s/localhost/$domain_name/" -e "s/.localhost/.$filename/" /etc/bind/db.$filename
}

function SubdomainCreate {
    local root_domain="$1"
    local subdomain="$2"
    local record="$3"
    local ip="$4"
    local priority="$5"

    ## Additional information needed for SRV records
    local service="$6"
    local protocol="$7"
    local ttl="$8"
    local weight="$9"
    local port="${10}"

    if [[ $record != "MX" ]] && [[ $record != "SRV" ]]; then
        echo -e "$subdomain\tIN\t$record\t$ip"
        echo -e "$subdomain\tIN\t$record\t$ip" >> /etc/bind/db.$FILE_NAME
    fi

    if [[ $record == "CNAME" ]]; then
        echo -e "$subdomain.$root_domain\tIN\tCNAME\t$target"
        echo -e "$subdomain.$root_domain\tIN\tCNAME\t$target" >> /etc/bind/db.$FILE_NAME
    fi

    if [[ $record == "MX" ]]; then
        echo -e "$root_domain.\tIN\tMX\t$priority\t$subdomain.$root_domain."
        echo -e "$root_domain.\tIN\tMX\t$priority\t$subdomain.$root_domain." >> /etc/bind/db.$FILE_NAME
    fi

    if [[ $record == "SRV" ]]; then
        echo -e "_$service._$protocol.$root_domain.\t$ttl\tIN\tSRV\t$priority $weight $port\t$subdomain.$root_domain."
        echo -e "_$service._$protocol.$root_domain.\t$ttl\tIN\tSRV\t$priority $weight $port\t$subdomain.$root_domain." >> /etc/bind/db.$FILE_NAME
    fi
}

function BindScriptConfig() {
    read -rp "What is the top-level domain (TLD) that will be used? [example.net] : " BIND_TLD_NAME

    while true; do
        read -rp "Will create a zone file, what is the name? [db.((name))] : " FILE_NAME

        while true; do
            read -rp "What subdomain would you like to create? [ns1/www/ftp/mail/other] : " SUBDOMAIN
            read -rp "What kind of record is it? [A/AAAA/CNAME/MX/NS/SRV/TXT] : " RECORD

            while true; do
                read -rp "To what IP it belongs to? [192.168.0.3] : " SUBDOMAIN_IP
                SUBDOMAIN_IP=${SUBDOMAIN_IP:-192.168.0.3}
                if [[ ! $SUBDOMAIN_IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                    echo "Invalid IP address format. Please try again."
                else
                    break
                fi
            done

            if [[ $RECORD == "MX" ]]; then
                read -rp "What is the priority? [0-65535] : " PRIORITY
                SubdomainCreate "$BIND_TLD_NAME" "$SUBDOMAIN" "$RECORD" "$SUBDOMAIN_IP" "$PRIORITY"
                break
            elif [[ $RECORD == "SRV" ]]; then
                read -rp "What service is this intended for? (sip/xmpp/ldap)[sip] : " SERVICE
                SERVICE=${SERVICE:-sip}

                read -rp "Which protocol does this service use? (tcp/udp)[udp] : " PROTOCOL
                PROTOCOL=${PROTOCOL:-udp}

                read -rp "What is the TTL for this record? [3600] : " TTL
                TTL=${TTL:-3600}

                read -rp "What is the priority? [1] : " PRIORITY
                PRIORITY=${PRIORITY:-1}

                read -rp "What is the weight? [1] : " WEIGHT
                WEIGHT=${WEIGHT:-1}

                read -rp "What is the port? [5060] : " PORT
                PORT=${PORT:-5060}

                SubdomainCreate "$BIND_TLD_NAME" "$SUBDOMAIN" "$RECORD" "$SUBDOMAIN_IP" "$PRIORITY" "$SERVICE" "$PROTOCOL" "$TTL" "$WEIGHT" "$PORT"
                break
            else
                SubdomainCreate "$BIND_TLD_NAME" "$SUBDOMAIN" "$RECORD" "$SUBDOMAIN_IP"
                break
            fi
        done

        while true; do
            read -rp "Create another subdomain? [y/N] : " SUBDOMAIN_RECREATE_DECISION
            case "$SUBDOMAIN_RECREATE_DECISION" in
                y|Y)
                break
                ;;

                n|N)
                break 2
                ;;

                *)
                echo "Not valid."
                ;;
            esac
        done
    done

    ZoneFileEdit "$BIND_TLD_NAME" "$FILE_NAME"
}

while true; do
    read -rp "Edit another zone file? : " ZONE_FILE_EDIT_DECISION
    case "$ZONE_FILE_EDIT_DECISION" in
        y|Y)
        BindScriptConfig()
        ;;

        n|N)
        echo "Finished this zone file configuration, now exiting"
        break
        ;;

        *)
        echo "Not valid"
        ;;
    esac
done


while true; do
    read -rp "Input the name for zone file. db.((name)) : " FILE_NAME
    read -rp "Input the name for PTR record file. db.((number)) : " PTR_FILE_NAME

    cp /etc/bind/db.local /etc/bind/db.$FILE_NAME
    cp /etc/bind/db.127 /etc/bind/db.$PTR_FILE_NAME

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
            nano /etc/bind/db.$FILE_NAME
            nano /etc/bind/db.$PTR_FILE_NAME
            nano /etc/bind/named.conf.local
            nano /etc/bind/named.conf.options
            break 2;;

            v|V)
            packageChecker "vim" -y
            vim /etc/bind/db.$FILE_NAME
            vim /etc/bind/db.$PTR_FILE_NAME
            vim /etc/bind/named.conf.local
            vim /etc/bind/named.conf.options
            break;;

            s|S)
            BindScriptConfig
            break;;

            a|A)
            break;;

            *)
            echo "Not a valid answer."
        esac
    done
done

systemctl restart bind9 && systemctl status bind9

# PHP
for pkgs in php php-mysql php-snmp php-xml php-mbstring php-json php-gd php-gmp php-zip php-ldap php-curl php-dom php-simplexml; do
    apt install $pkgs -y
done

# Database (MariaDB)
apt install mariadb-server mariadb-client
mysql_secure_installation ## Remote login option must be allowed

# Mail Server (Postfix and Dovecot)
echo "Installing Postfix, Dovecot, and related packages..."
apt install postfix dovecot-imapd dovecot-pop3d -y

DOVECOT_PATH=/etc/dovecot/conf.d

sed -i 's/home_mailbox = Maildir/#home_mailbox = Maildir/' /etc/postfix/main.cf
maildirmake.dovecot /etc/skel/Maildir
dpkg-reconfigure postfix
systemctl restart postfix

sed -i 's/# listen = */listen = */' /etc/dovecot/dovecot.conf
sed -i 's/# disable_plaintext_auth = yes/disable_plaintext_auth = no/' $DOVECOT_PATH/10-auth.conf
sed -i 's/# mail_location = maildir:~/Maildir/mail_location = maildir:~/Maildir/' $DOVECOT_PATH/10-mail.conf
sed -i 's|mail_location = mbox:~/mail:INBOX=/var/mail/%u|# mail_location = mbox:~/mail:INBOX=/var/mail/%u|' $DOVECOT_PATH/10-mail.conf
systemctl restart dovecot

# echo "home_mailbox = Maildir/" >>  /etc/postfix/main.cf
# echo "message_size_limit = 20480000" >> /etc/postfix/main.cf
# systemctl restart postfix

# Roundcube
apt install roundcube

while true; do
    while true; do
        read -rp "IMAP server domain name [example.com] : " IMAP_HOST
        read -rp "IMAP server port [143] : " IMAP_PORT
        read -rp "SMTP server domain name [example.com] : " SMTP_HOST
        read -rp "SMTP server port [25] : " IMAP_HOST

        IMAP_HOST=${IMAP_HOST:-example.com}
        IMAP_PORT=${IMAP_PORT:-143}
        SMTP_HOST=${SMTP_HOST:-example.com}
        SMTP_PORT=${SMTP_PORT:-25}

        # Deprecated
        # sed -i "s/$config['smtp_port'] = 587/$config['smtp_port'] = 25/" /etc/roundcube/config.inc.php

        sed -i "s/$config['imap_host'] = [\"localhost:143\"];/$config['imap_host'] = [\"$IMAP_HOST:$IMAP_PORT\";]/" /etc/roundcube/config.inc.php
        sed -i "s/$config['smtp_host'] = 'localhost:587';/$config['smtp_host'] = \"$SMTP_HOST:$SMTP_PORT\";/" /etc/roundcube/config.inc.php
        sed -i "s/$config['smtp_user'] = '%u';/$config['smtp_user'] = '';/" /etc/roundcube/config.inc.php
        sed -i "s/$config['smtp_pass'] = '%p';/$config['smtp_pass'] = '';/" /etc/roundcube/config.inc.php

        while true; do
            read -rp "Reconfigure Roundcube? This will run 'dpkg-reconfigure roundcube-core' [y/N]: " RECONFIG
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
for pkgs in rrdtool mariadb-client snmp snmpd; do
    apt install $pkgs -y
done

apt install cacti -y