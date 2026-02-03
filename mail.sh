#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Jalankan sebagai root."
  exit 1
fi

clear
echo "======================================"
echo " DEBIAN 10 MAIL SERVER INSTALLER BY FarizGD"
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
  echo "Domain kosong. Ini pemborosan konfigurasi."
  exit 1
fi

HOSTIP="127.0.0.1"

echo "[+] Set /etc/hosts"
grep -q "$DOMAIN" /etc/hosts || echo "$HOSTIP $DOMAIN mail.$DOMAIN" >> /etc/hosts

echo "[+] apt update"
apt update

echo "[+] Install paket mail & webmail"
DEBIAN_FRONTEND=noninteractive apt install -y \
postfix dovecot-core dovecot-pop3d \
apache2 php php-imap php-mbstring curl unzip telnet

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
echo "======================================"
echo " INSTALLASI SELESAI"
echo " DOMAIN   : $DOMAIN"
echo " WEBMAIL  : http://$DOMAIN"
echo " SMTP     : telnet mail.$DOMAIN 25"
echo " POP3     : telnet mail.$DOMAIN 110"
echo " USER     : tamu"
echo " PASS     : tamu"
echo "======================================"
