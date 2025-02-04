#!/bin/bash

# Script pre-run warning
echo -e "Executing full-fledged.sh..."

# Check whether the user is root or not
if (( "$EUID" != 0 )); then
    echo "You are not root. Please run as root, now exiting."
    exit
fi

echo "-----------------> UNFINISHED SCRIPT <-----------------"
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
      exit 0
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

# Apache2 install and configuration + WordPress download
echo "Installing necessary packages..."
apt install apache2 libapache2-mod-php -y ## > /dev/null 2>&1

echo "Downloading WordPress..."
curl -L https://wordpress.org/latest.zip -o /var/www/html/latest.zip

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
        read -rp "Specify the root directory of the website [/var/www/html] : " ROOT_WEBDIR
        read -rp "Should WordPress be installed on $ROOT_WEBDIR? [y/N] : " WP_INSTALL

        VHOST_FILENAME=${VHOST_FILENAME:-web.conf}
        DOMAIN_NAME=${DOMAIN_NAME:-example.com}

        if [[ -z $ROOT_WEBDIR ]]; then
            ROOT_WEBDIR="/var/www/html"
        fi

        cp $CONF_PATH/template.conf $CONF_PATH/$VHOST_FILENAME
        sed -i "s/#ServerName www.example.com/ServerName $DOMAIN_NAME/" $CONF_PATH/$VHOST_FILENAME
        sed -i "s|DocumentRoot /var/www/html|DocumentRoot $ROOT_WEBDIR|" $CONF_PATH/$VHOST_FILENAME

        if [[ -n $ALIAS_NAME ]]; then
            TMPFILE=$(mktemp /tmp/apache2-config-XXX.tmp)
            awk "/ServerName/ { print; print \"\tServerAlias $ALIAS_NAME\"; next }1" $CONF_PATH/$VHOST_FILENAME > $TMPFILE
            cat $TMPFILE | tee $CONF_PATH/$VHOST_FILENAME
            rm $TMPFILE
        fi

        while true; do
            case "$WP_INSTALL" in
                y|Y)
                TMPDIR=$(echo "$ROOT_WEBDIR" | sed -E 's#(/[^/]+)$##')

                mkdir -p $TMPDIR
                rm -rf $ROOT_WEBDIR
                unzip /var/www/html/latest.zip -d /var/www/html
                mv /var/www/html/wordpress $ROOT_WEBDIR
                break
                ;;

                n|N)
                break
                ;;

                *)
                echo "Not a valid answer."
                ;;
            esac
        done

        chown -R www-data:www-data $ROOT_WEBDIR

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

function BindScriptConfig() {
    while true; do
        read -rp "Input the name for forward zone file : " FILE_NAME
        read -rp "Input the name for reverse zone file : " PTR_FILE_NAME

        if [ ! -f /etc/bind/$FILE_NAME ]; then
            TLD=''
        fi

        if [ ! -f /etc/bind/$FILE_NAME ]; then
            cp /etc/bind/db.local /etc/bind/$FILE_NAME

            read -rp "What is the top-level domain (TLD) that will be used? [example.net] : " TLD
            read -rp "What is the IP Address of $TLD NS? [192.168.0.3] : " IP

            sed -i "s/localhost/$TLD/" /etc/bind/$FILE_NAME
            sed -i "s/.localhost/.$TLD/" /etc/bind/$FILE_NAME
            sed -i "s/127.0.0.1/$IP/" /etc/bind/$FILE_NAME

            # Delete IPv6 option
            sed -i "/::1$/d" /etc/bind/$FILE_NAME
        fi

        if [ ! -f /etc/bind/$PTR_FILE_NAME ]; then
            cp /etc/bind/db.127 /etc/bind/$PTR_FILE_NAME
            sed -i "/^1.0.0/d" /etc/bind/$PTR_FILE_NAME
        fi

        while true; do
            read -rp "What subdomain would you like to create? [ns1/www/ftp/mail/other] : " SUBDOMAIN
            read -rp "What kind of record is it? [A/AAAA/CNAME/MX/NS/SRV/TXT] : " RECORD

            if [[ $RECORD == "A" ]] || [[ $RECORD == "AAAA" ]] || [[ $RECORD == "NS" ]]; then
                while true; do
                    if [[ -z $IP ]]; then
                        IP=${IP:-192.168.0.3}
                    fi
                    read -rp "To what IP it belongs to? [$IP] : " IP
                    HOST_IP=$(echo $IP | awk -F. '{print $4}')

                    if [[ ! $IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                        echo "Invalid IP address format. Please try again."
                    else
                        break
                    fi
                done
            fi

            case "$RECORD" in
                "A"|"AAAA"|"NS")
                echo -e "$SUBDOMAIN\tIN\t$RECORD\t$IP"
                echo -e "$SUBDOMAIN\tIN\t$RECORD\t$IP" >> /etc/bind/$FILE_NAME
                echo -e "$HOST_IP\tIN\tPTR\t$SUBDOMAIN.$TLD." >> /etc/bind/$PTR_FILE_NAME

                if [[ $SUBDOMAIN.$TLD =~ ^cacti.*$ ]]; then
                    CACTI_DOMAIN=$SUBDOMAIN.$TLD
                fi
                ;;

                "MX")
                read -rp "What is the priority? [0-65535] : " PRIORITY
                echo -e "$TLD.\tIN\tMX\t$PRIORITY\t$SUBDOMAIN.$TLD."
                echo -e "$TLD.\tIN\tMX\t$PRIORITY\t$SUBDOMAIN.$TLD." >> /etc/bind/$FILE_NAME
                ;;

                "SRV")
                read -rp "What service is this intended for? (sip/xmpp/ldap)[sip] : " service
                read -rp "Which protocol does this service use? (tcp/udp)[udp] : " protocol
                read -rp "What is the TTL for this record in seconds? [3600] : " ttl
                read -rp "What is the priority? [1] : " priority
                read -rp "What is the weight? [1] : " weight
                read -rp "What is the port? [5060] : " port

                service=${service:-sip}
                protocol=${protocol:-udp}
                ttl=${ttl:-3600}
                priority=${priority:-1}
                weight=${weight:-1}
                port=${port:-5060}

                echo -e "_$service._$protocol.$TLD.\t$ttl\tIN\tSRV\t$priority $weight $port\t$SUBDOMAIN.$TLD."
                echo -e "_$service._$protocol.$TLD.\t$ttl\tIN\tSRV\t$priority $weight $port\t$SUBDOMAIN.$TLD." >> /etc/bind/$FILE_NAME
                ;;

                "CNAME")
                read -rp "What domain should this CNAME record points to : " target
                echo -e "$SUBDOMAIN.$TLD\tIN\tCNAME\t$target."
                echo -e "$SUBDOMAIN.$TLD\tIN\tCNAME\t$target." >> /etc/bind/$FILE_NAME
                ;;
            esac

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

        while true; do
            read -rp "Create and edit another zone files? [y/N] : " ZONE_FILE_EDIT_DECISION
            case "$ZONE_FILE_EDIT_DECISION" in
                y|Y)
                break
                ;;

                n|N)
                echo "Finished doing zone file configuration, now exiting"
                break 2
                ;;

                *)
                echo "Not valid"
                ;;
            esac
        done
    done


    while true; do
        read -rp "Configure the local DNS zone in named.conf.local? [y/N] : " LOCAL_DNS_DECISION
        case "$LOCAL_DNS_DECISION" in
            y|Y)
            while true; do
                read -rp "Which zone to configure [$TLD] : " ZONE
                read -rp "File path (specify full path, e.g /etc/bind/db.local) [$FILE_NAME] : " ZONE_FILEPATH

                ZONE=${ZONE:-$TLD}
                ZONE_FILEPATH=${ZONE_FILEPATH:-$FILE_NAME}

                echo -e "zone \"$ZONE\" {\n\ttype master;\n\tfile \"$ZONE_FILEPATH\";\n};\n" >> /etc/bind/named.conf.local

                while true; do
                    read -rp "Reconfigure another zone? [y/N] : " RECONFIG
                    case "$RECONFIG" in
                        y|Y)
                        break
                        ;;

                        n|N)
                        echo "Finished configuring local zone file"
                        break 3
                        ;;

                        *)
                        echo "Not a valid answer"
                        ;;
                    esac
                done
                break
            done
            ;;

            n|N)
            break
            ;;

            *)
            echo "Not a valid option"
            ;;
        esac
    done

    while true; do
        read -rp "Configure the reverse DNS lookup (in.addr-arpa) in named.conf.local? [y/N] : " REVERSE_DNS_DECISION
        case "$REVERSE_DNS_DECISION" in
            y|Y)
            while true; do
                read -rp "What IP to configure [$(echo $IP | awk -F. '{print $2"."$1'})] : " REVERSE_ZONE
                read -rp "File path (specify full path, e.g /etc/bind/db.192) [$PTR_FILE_NAME] : " REVERSE_ZONE_FILEPATH

                REVERSE_ZONE=${REVERSE_ZONE:-$(echo $IP | awk -F. 'print $2"."$1')}
                REVERSE_ZONE_FILEPATH=${REVERSE_ZONE_FILEPATH:-$FILE_NAME}

                echo -e "zone \"$REVERSE_ZONE.in-addr.arpa\" {\n\ttype master;\n\tfile \"$REVERSE_ZONE_FILEPATH\";\n};\n" >> /etc/bind/named.conf.local
                cat /etc/bind/named.conf.local
                echo "Finished reverse zone file configuration"
                break 2
            done
            ;;

            n|N)
            break
            ;;

            *)
            echo "Not a valid option"
            ;;
        esac
    done
}


while true; do
    echo "You will need to edit these files :"
    echo -e "- The zone file (db.$FILE_NAME)\n\
- PTR records file (db.$PTR_FILE_NAME)\n\
- Local DNS server configuration file (named.conf.local)\n\
- Bind9 settings (named.conf.options)\n\n\
Choose which tool to use : "
    read -rp "(N)ano       (V)im       (S)cript       (A)bort: " EDIT_METHOD
    case "$EDIT_METHOD" in
        n|N)
        packageChecker "nano" -y
        nano /etc/bind/$FILE_NAME
        nano /etc/bind/$PTR_FILE_NAME
        nano /etc/bind/named.conf.local
        nano /etc/bind/named.conf.options
        break
        ;;

        v|V)
        packageChecker "vim" -y
        vim /etc/bind/$FILE_NAME
        vim /etc/bind/$PTR_FILE_NAME
        vim /etc/bind/named.conf.local
        vim /etc/bind/named.conf.options
        break
        ;;

        s|S)
        BindScriptConfig
        break
        ;;

        a|A)
        break
        ;;

        *)
        echo "Not a valid answer."
    esac
done

systemctl restart bind9 && systemctl status bind9

# PHP
for pkgs in php php-mysql php-snmp php-xml php-mbstring php-json php-gd php-gmp php-zip php-ldap php-curl php-dom php-simplexml; do
    apt install $pkgs -y
done

# Database (MariaDB)
apt install mariadb-server mariadb-client -y
mysql_secure_installation ## Remote login option must be allowed

# Mail Server (Postfix and Dovecot)
echo "Installing Postfix, Dovecot, and related packages..."
apt install postfix dovecot-imapd dovecot-pop3d -y

read -rp "Hostname of this mail server [example.net] : " POSTFIX_HOST
cp /etc/postfix/main.cf /etc/postfix/main.cf.bak
sed -i "s/^myhostname = .*/myhostname = $(printf '%s' "$POSTFIX_HOST" | sed 's/[&/\]/\\&/g')/" /etc/postfix/main.cf
sed -i 's|mynetworks = 127.0.0.0/8 \[::ffff:127.0.0.0\]/104 \[::1\]/128|mynetworks = 127.0.0.0/8 \[::ffff:127.0.0.0\]/104 \[::1\]/128 0.0.0.0/0|' /etc/postfix/main.cf
sed -i 's/inet_interfaces = loopback-only/inet_interfaces = all/' /etc/postfix/main.cf
sed -i 's/inet_protocols = all/inet_protocols = ipv4/' /etc/postfix/main.cf
#sed -i 's/default_transport = error/default_transport = smtp/' /etc/postfix/main.cf
#sed -i 's/relay_transport = error/relay_transport = smtp/' /etc/postfix/main.cf

echo "default_transport = smtp" >> /etc/postfix/main.cf
echo "relay_transport = smtp" >> /etc/postfix/main.cf
echo "home_mailbox = Maildir/" >> /etc/postfix/main.cf

sed -i 's/#listen = \*, ::/listen = */' /etc/dovecot/dovecot.conf
sed -i 's/#disable_plaintext_auth = yes/disable_plaintext_auth = no/' /etc/dovecot/conf.d/10-auth.conf
sed -i 's|mail_location = mbox:~/mail:INBOX=/var/mail/%u|mail_location = maildir:~/Maildir|' /etc/dovecot/conf.d/10-mail.conf

maildirmake.dovecot /etc/skel/Maildir
systemctl restart postfix dovecot

# echo "home_mailbox = Maildir/" >>  /etc/postfix/main.cf
# echo "message_size_limit = 20480000" >> /etc/postfix/main.cf
# systemctl restart postfix

# Roundcube
apt install roundcube -y

while true; do
    while true; do
        read -rp "IMAP server domain name [example.com] : " IMAP_HOST
        read -rp "IMAP server port [143] : " IMAP_PORT
        read -rp "SMTP server domain name [example.com] : " SMTP_HOST
        read -rp "SMTP server port [25] : " SMTP_PORT

        IMAP_HOST=${IMAP_HOST:-example.com}
        IMAP_PORT=${IMAP_PORT:-143}
        SMTP_HOST=${SMTP_HOST:-example.com}
        SMTP_PORT=${SMTP_PORT:-25}

        # Deprecated
        # sed -i "s/$config['smtp_port'] = 587/$config['smtp_port'] = 25/" /etc/roundcube/config.inc.php

        sed -i "s/\$config\['imap_host'\] = \[\"localhost:143\"\];/\$config\['imap_host'\] = \[\"$IMAP_HOST:$IMAP_PORT\"\];/" /etc/roundcube/config.inc.php
        sed -i "s/\$config\['smtp_host'\] = 'localhost:587';/\$config\['smtp_host'\] = '$SMTP_HOST:$SMTP_PORT';/" /etc/roundcube/config.inc.php
        sed -i "s/\$config\['smtp_user'\] = '%u';/\$config\['smtp_user'\] = '';/" /etc/roundcube/config.inc.php
        sed -i "s/\$config\['smtp_pass'\] = '%p';/\$config\['smtp_pass'\] = '';/" /etc/roundcube/config.inc.php

        while true; do
            read -rp "Reconfigure Roundcube? This will run 'dpkg-reconfigure roundcube-core' [y/N]: " RECONFIG
            case "$RECONFIG" in
                y|Y)
                dpkg-reconfigure roundcube-core
                break
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

# SNMP and Cacti
for pkgs in rrdtool mariadb-client snmp snmpd cacti; do
    apt install $pkgs -y
done

read -rp "SNMP community profile to create (any string) [snmp1] : " SNMP_COM
read -rp "IP address to monitor with SNMP [$IP] : " IP
read -rp "SNMP agent address [$IP] : " AA_IP

SNMP_COM=${SNMP_COM:-snmp1}
IP=${IP:-IP}
AA_IP=${AA_IP:-IP}

sed -i "s/^agentaddress.*$/agentaddress $AA_IP,127.0.0.1/" /etc/snmp/snmpd.conf

TMPFILE=$(mktemp /tmp/snmpd-config-XXX.tmp)
awk "/rocommunity  public/ { print; print \"rocommunity  $SNMP_COM $IP\"; next }1" /etc/snmp/snmpd.conf > $TMPFILE
cat $TMPFILE | tee /etc/snmp/snmpd.conf
rm $TMPFILE

TMPFILE=$(mktemp /tmp/cacti-config-XXX.tmp)
sed -e '1,2d;10,20d' -e '3,22s/^/\t/' -e '3i<VirtualHost \*:80>' -e "3iServerName $CACTI_DOMAIN" -e '3iDocumentRoot /usr/share/cacti/site' -e '23i<VirtualHost>' /etc/apache2/conf-available/cacti.conf > $TMPFILE
cat $TMPFILE | sed -e '2,3s/^/\t/' > /etc/apache2/sites-available/cacti.conf
rm $TMPFILE

chmod 755 /usr/share/cacti/site/poller.php
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/share/cacti/site/poller.php -with args") | crontab -

a2ensite cacti.conf
systemctl restart cron snmpd