#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Jalankan sebagai root."
  exit 1
fi

clear
echo "======================================"
echo " DEBIAN 10 MAIL SERVER INSTALLER - by FarizGD"
echo "======================================"
echo
echo "MASUKKAN DEBIAN 10 CD/DVD 1"
echo "Lalu tekan ENTER..."
read
apt-cdrom add

echo
echo "MASUKKAN DEBIAN 10 CD/DVD 2"
echo "Lalu tekan ENTER..."
read
apt-cdrom add

echo "[+] CD-ROM berhasil ditambahkan"

echo
echo "Masukkan nama domain (contoh: fariz.com)"
read DOMAIN

if [ -z "$DOMAIN" ]; then
  echo "Domain kosong. Konfigurasi nol nilai."
  exit 1
fi

HOSTIP="127.0.0.1"

echo "[+] Set /etc/hosts"
grep -q "$DOMAIN" /etc/hosts || echo "$HOSTIP $DOMAIN mail.$DOMAIN" >> /etc/hosts

echo "[+] apt update"
apt update

echo "[+] Install paket"
DEBIAN_FRONTEND=noninteractive apt install -y \
postfix dovecot-core dovecot-pop3d \
apache2 php php-imap php-mbstring curl unzip telnet iproute2

echo "[+] Konfigurasi Postfix"
postconf -e "myhostname = mail.$DOMAIN"
postconf -e "mydomain = $DOMAIN"
postconf -e "inet_interfaces = all"
postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain"
postconf -e "home_mailbox = Maildir/"
echo "$DOMAIN" > /etc/mailname
systemctl restart postfix

echo "[+] Konfigurasi Dovecot (POP3 Telnet)"
sed -i 's/^#disable_plaintext_auth.*/disable_plaintext_auth = no/' /etc/dovecot/conf.d/10-auth.conf
sed -i 's|^mail_location.*|mail_location = maildir:~/Maildir|' /etc/dovecot/conf.d/10-mail.conf
sed -i 's/^#port = 110/port = 110/' /etc/dovecot/conf.d/10-master.conf
systemctl restart dovecot

echo "[+] Install SquirrelMail via curl"
cd /var/www/html
curl -L https://downloads.sourceforge.net/project/squirrelmail/stable/1.4.23/squirrelmail-webmail-1.4.23.zip -o squirrelmail.zip
unzip -q squirrelmail.zip
mv squirrelmail-webmail-1.4.23 squirrelmail
chown -R www-data:www-data squirrelmail

echo "[+] Apache VirtualHost"
cat <<EOF >/etc/apache2/sites-available/squirrelmail.conf
<VirtualHost *:80>
  ServerName $DOMAIN
  ServerAlias mail.$DOMAIN
  DocumentRoot /var/www/html/squirrelmail

  <Directory /var/www/html/squirrelmail>
    AllowOverride All
    Require all granted
  </Directory>
</VirtualHost>
EOF

a2ensite squirrelmail
systemctl reload apache2

echo "[+] Buat user mail"
id tamu &>/dev/null || useradd -m tamu
echo "tamu:tamu" | chpasswd
mkdir -p /home/tamu/Maildir
chown -R tamu:tamu /home/tamu/Maildir

echo
echo "[+] Konfigurasi Host-Only Network"

IFACE="enp0s3"

ip link set $IFACE up
ip addr flush dev $IFACE
ip addr add 192.168.100.1/24 dev $IFACE

grep -q "$IFACE" /etc/network/interfaces || cat <<EOF >> /etc/network/interfaces

auto $IFACE
iface $IFACE inet static
  address 192.168.100.1
  netmask 255.255.255.0
EOF

echo
echo "[+] Konfigurasi DNS (/etc/resolv.conf)"

chattr -i /etc/resolv.conf 2>/dev/null || true
cat <<EOF >/etc/resolv.conf
nameserver 192.168.100.1
nameserver 8.8.8.8
search $DOMAIN
EOF
chattr +i /etc/resolv.conf

echo
echo "======================================"
echo " INSTALLASI SELESAI"
echo " DOMAIN   : $DOMAIN"
echo " WEBMAIL  : http://192.168.100.1"
echo " SMTP     : telnet mail.$DOMAIN 25"
echo " POP3     : telnet mail.$DOMAIN 110"
echo " DNS      : 8.8.8.8 / 1.1.1.1 (LOCKED)"
echo " USER     : tamu"
echo " PASS     : tamu"
echo "======================================"
