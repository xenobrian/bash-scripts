#!/bin/bash

# Changes static network config to DHCP
echo -e "THIS SCRIPT IS NOT FINISHED YET!\nThis script will install mail server related packages (Postfix, Dovecot, Apache2, Roundcube)"; sleep 1
echo -e "Are you sure about this?\n Ctrl+C in 5 seconds to cancel!"; sleep 5
echo "Starting installation!"; sleep 1
echo "Making sure your internet is DHCP first..."
echo -e "auto lo\niface lo inet loopback\n\n# The Primary network interface\nauto enp0s3\niface enp0s3 inet dhcp" > /etc/network/interfaces
systemctl restart networking
export pid=$!; wait $pid
echo "Your updated IP Configuration :"; sleep 1; ip a; sleep 3
apt -y install sudo

# DNS Server
echo "Making sure your DNS is set to 8.8.8.8 first..."; sleep 1
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Repository update
echo "Updating repositories..."
sudo apt update > /dev/null 2>&1; export pid=$!; wait $pid
echo "Repositories has been updated."

# Sed install and IP Configuration
while true; do
    echo "Network configuration, please use lowercase on all"; sleep 1
    read -rp "Network configuration method, static or dhcp? [static/dhcp]:" NWMETHOD
    case "$NWMETHOD" in
        [s][t][a][t][i][c])
        while true; do
            read -rp "Which interface should be configured(e.g enp0s3, eth0): " HOSTINT 
            read -rp "Configure your IP address (192.168.0.2 for example) :" HOSTIP
            read -rp "Configure the netmask : " HOSTNETMASK
            read -rp "Configure your gateway : " HOSTGW
            echo -e "Your IP configuration as follows :/
            \nInterface\t: $HOSTINT/
            \nIP address\t: $HOSTIP/
            \nNetmask\t: $HOSTNETMASK/
            \nGateway\t: $HOSTGW"; sleep 1
            
            read -rp "Is this correct?[yes/no] :" USERDECISION
            while true; do
                case "$USERDECISION" in
                    [yY][eE][sS])
                    echo "Network will be set as the configuration above"
                    break 3;;

                    [nN][oO])
                    echo "Restarting configuration..."
                    break;;

                    *) Please choose 'yes' or 'no';;
                esac
            done
            break
        done;;

        [d][h][c][p])
        echo "You chose DHCP"
        break;;

        *) echo "Invalid option. Please choose 'static' or dhcp'";;
    esac
done


sudo apt install sed -y > /dev/null 2>&1
sudo sed -i 's|iface enp0s3 inet dhcp/iface enp0s3 inet static\n\taddress 192.168.22.6/24\n\tgateway 192.168.22.254|' /etc/network/interfaces
sudo systemctl restart networking

# Static to dhcp[[:space:]]\+[0-9.] is looking for a sequence of one or more whitespace characters followed by digits and/or dots.
sudo sed -i '/iface enp0s3 inet static/ {
    s/iface enp0s3 inet static/iface enp0s3 inet dhcp/
    s/address[[:space:]]\+[0-9]\+/#address/
    s/netmask[[:space:]]\+[0-9]\+/#netmask/
    s/gateway[[:space:]]\+[0-9]\+/#gateway/
}' /etc/network/interfaces

# Necessary packages installation
echo "Installing necessary packages..."
sudo apt install apache2 libapache2-mod-php wget unzip curl -y > /dev/null 2>&1
export pid=$!; wait $pid
echo "Packages have been installed, will configure Apache2 in 3 seconds..."; sleep 3

# Apache2 for website configuration
read -p "What domain name would you like to use?(use FQDN)[www.example.org]" domainname
sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/website.conf
sudo sed -i 's/ServerName www.example.com/ServerName $domainname/' /etc/apache2/sites-available/website.conf
sudo sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/website/|' /etc/apache2/sites-available/website.conf
sudo a2ensite smkdki.conf && sudo a2dissite 000-default.conf 
sudo systemctl restart apache2.service && sudo systemctl status apache2
echo "Will install and configure Bind9 in 3 seconds..."
sleep 3

# Bind9 configuration
sudo apt install bind9 bind9utils dnsutils -y > /dev/null 2>&1
export pid $!; wait $pid
echo "Packages installed. Configuring Bind9 in 3 seconds..."; sleep 3

read -p "Please input the name that should be used for naming the db :" dbname
read -p "Please input your network IP ([192].168.0.0) :" ip
sudo cp /etc/bind/db.local /etc/bind/db.$dbname && sudo cp /etc/bind/db.127 /etc/bind/db.$ip
sudo tail -n 20 /etc/bind/named.conf.default-zones >> /etc/bind/named.conf.local
sudo sed -i "s/file /"

# Postfix and Dovecot
echo "Installing Postfix, Dovecot, and related packages..."
sudo apt install postfix dovecot-imapd dovecot-pop3d -y > /dev/null 2>&1
export pid=$!
wait $pid
echo "Postfix and Dovecot related packages has been installed."
sleep 1
echo "Now configuring mail server..."
echo "home_mailbox = Maildir/" >>  /etc/postfix/main.cf
echo "message_size_limit = 20480000" >> /etc/postfix/main.cf
sudo systemctl restart postfix
