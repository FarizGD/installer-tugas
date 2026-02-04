#!/bin/bash
set -e
echo "[+] Installer by FarizGD"
echo "[*] Mail Server Installer Debian 10 (Non-Interactive)"
sleep 3
### VARIABLES
HOSTNAME=$(hostname)
DOMAIN="${HOSTNAME}.com"
IP_HOSTONLY="192.168.100.1"
NETMASK="/24"
INTERFACE="enp0s3"

### FIX REPO DEBIAN 10 (ARCHIVE)
cat > /etc/apt/sources.list <<EOF
deb http://archive.debian.org/debian buster main contrib non-free
deb http://archive.debian.org/debian-security buster/updates main contrib non-free
EOF

echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid

apt update

### INSTALL PACKAGES
DEBIAN_FRONTEND=noninteractive apt install -y \
postfix \
dovecot-pop3d \
dovecot-imapd \
telnet \
apache2 \
php \
php-mbstring \
php-imap \
wget \
tar

### HOSTS
grep -q "$DOMAIN" /etc/hosts || echo "127.0.0.1 $DOMAIN" >> /etc/hosts

### POSTFIX CONFIG
postconf -e "myhostname = $DOMAIN"
postconf -e "mydomain = $DOMAIN"
postconf -e "myorigin = /etc/mailname"
postconf -e "inet_interfaces = all"
postconf -e "home_mailbox = Maildir/"

echo "$DOMAIN" > /etc/mailname

### DOVECOT CONFIG
sed -i 's|^#mail_location =.*|mail_location = maildir:~/Maildir|' /etc/dovecot/conf.d/10-mail.conf
sed -i 's|^#disable_plaintext_auth = yes|disable_plaintext_auth = no|' /etc/dovecot/conf.d/10-auth.conf
sed -i 's|^#listen = \*, ::|listen = *|' /etc/dovecot/dovecot.conf

### USER MAILDIR
id tamu &>/dev/null || useradd -m tamu
echo "tamu:tamu" | chpasswd
mkdir -p /home/tamu/Maildir
chown -R tamu:tamu /home/tamu/Maildir

### SQUIRRELMAIL INSTALL
cd /var/www/html
wget -q https://github.com/FarizGD/installer-tugas/raw/refs/heads/main/files/squirrelmail-webmail-1.4.22.tar.gz
tar xzf squirrelmail-webmail-1.4.22.tar.gz
mv squirrelmail-webmail-1.4.22 squirrelmail
chown -R www-data:www-data squirrelmail

### APACHE
systemctl restart apache2

### NETWORK (HOST-ONLY)
cat > /etc/network/interfaces.d/hostonly <<EOF
auto $INTERFACE
iface $INTERFACE inet static
 address $IP_HOSTONLY
 netmask 255.255.255.0
EOF

### RESOLV.CONF
cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF

### RESTART SERVICES
systemctl restart postfix
systemctl restart dovecot
systemctl restart networking

echo "================================="
echo " INSTALLATION COMPLETE"
echo " Domain      : $DOMAIN"
echo " Webmail     : http://$DOMAIN/squirrelmail"
echo " POP3        : telnet $DOMAIN 110"
echo " User        : tamu"
echo " Password    : tamu"
echo ""
echo " Untuk ganti domain:"
echo " - /etc/hosts"
echo " - /etc/mailname"
echo " - postfix: myhostname"
echo "================================="
