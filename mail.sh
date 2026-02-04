#!/usr/bin/env bash
set -e

# ===============================
# KONFIGURASI DASAR
# ===============================
CONF_DIR="/etc/mailserver"
CONF_FILE="$CONF_DIR/domain.conf"

MAIL_USER="tamu"
MAIL_PASS="tamu"

IFACE="enp0s3"
HOST_IP="192.168.100.1"
NETMASK="255.255.255.0"

# ===============================
# ROOT CHECK
# ===============================
if [[ $EUID -ne 0 ]]; then
  echo "Jalankan sebagai root."
  exit 1
fi

# ===============================
# SET DOMAIN DARI HOSTNAME
# ===============================
mkdir -p "$CONF_DIR"

if [[ ! -f "$CONF_FILE" ]]; then
  HOSTNAME_SYS="$(hostname -s)"
  echo "DOMAIN=${HOSTNAME_SYS}.com" > "$CONF_FILE"
fi

source "$CONF_FILE"
DOMAIN="$DOMAIN"

echo "[+] Domain aktif: $DOMAIN"

# ===============================
# SET DEBIAN 10 REPOSITORY
# ===============================
echo "[+] Mengatur Debian 10 repository"

cat <<EOF >/etc/apt/sources.list
deb http://deb.debian.org/debian buster main contrib non-free
deb http://security.debian.org/debian-security buster/updates main contrib non-free
deb http://deb.debian.org/debian buster-updates main contrib non-free
EOF

apt update

# ===============================
# INSTALL PAKET
# ===============================
DEBIAN_FRONTEND=noninteractive apt install -y \
postfix dovecot-core dovecot-pop3d \
apache2 php php-imap php-mbstring \
curl unzip telnet iproute2 e2fsprogs

# ===============================
# HOSTS
# ===============================
grep -q "$DOMAIN" /etc/hosts || \
echo "127.0.0.1 $DOMAIN mail.$DOMAIN" >> /etc/hosts

# ===============================
# POSTFIX
# ===============================
postconf -e "myhostname = mail.$DOMAIN"
postconf -e "mydomain = $DOMAIN"
postconf -e "inet_interfaces = all"
postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain"
postconf -e "home_mailbox = Maildir/"
echo "$DOMAIN" > /etc/mailname
systemctl restart postfix

# ===============================
# DOVECOT (POP3 TELNET)
# ===============================
sed -i 's/^#disable_plaintext_auth.*/disable_plaintext_auth = no/' /etc/dovecot/conf.d/10-auth.conf
sed -i 's|^mail_location.*|mail_location = maildir:~/Maildir|' /etc/dovecot/conf.d/10-mail.conf
sed -i 's/^#port = 110/port = 110/' /etc/dovecot/conf.d/10-master.conf
systemctl restart dovecot

# ===============================
# SQUIRRELMAIL
# ===============================
cd /var/www/html
curl -fsSL https://downloads.sourceforge.net/project/squirrelmail/stable/1.4.23/squirrelmail-webmail-1.4.23.zip -o squirrelmail.zip
unzip -q squirrelmail.zip
mv squirrelmail-webmail-1.4.23 squirrelmail
chown -R www-data:www-data squirrelmail

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

# ===============================
# USER MAIL
# ===============================
id "$MAIL_USER" &>/dev/null || useradd -m "$MAIL_USER"
echo "$MAIL_USER:$MAIL_PASS" | chpasswd
mkdir -p /home/$MAIL_USER/Maildir
chown -R $MAIL_USER:$MAIL_USER /home/$MAIL_USER/Maildir

# ===============================
# HOST-ONLY NETWORK
# ===============================
ip link set "$IFACE" up
ip addr flush dev "$IFACE"
ip addr add $HOST_IP/24 dev "$IFACE"

grep -q "$IFACE" /etc/network/interfaces || cat <<EOF >> /etc/network/interfaces

auto $IFACE
iface $IFACE inet static
  address $HOST_IP
  netmask $NETMASK
EOF

# ===============================
# DNS
# ===============================
chattr -i /etc/resolv.conf 2>/dev/null || true
cat <<EOF >/etc/resolv.conf
nameserver 8.8.8.8
nameserver 1.1.1.1
search $DOMAIN
EOF
chattr +i /etc/resolv.conf

echo "======================================"
echo " INSTALLASI SELESAI"
echo " DOMAIN        : $DOMAIN"
echo " EDIT DOMAIN   : $CONF_FILE"
echo " WEBMAIL       : http://$HOST_IP"
echo " SMTP          : telnet mail.$DOMAIN 25"
echo " POP3          : telnet mail.$DOMAIN 110"
echo " USER          : $MAIL_USER"
echo " PASS          : $MAIL_PASS"
echo "======================================"
