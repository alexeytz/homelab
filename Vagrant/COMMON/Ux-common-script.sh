cat $0
echo
echo Executing common customization script: $0

echo " [+] $(date) Stop and Disable ufw (firewall)..."
ufw disable
systemctl disable ufw

echo " [+] $(date) Stop and Disable systemd-resolved..."
systemctl stop systemd-resolved
systemctl disable systemd-resolved

echo " [+] $(date) Set /etc/resolv.conf..."
rm -f /etc/resolv.conf
cat >/etc/resolv.conf<<EOF
options timeout:30
nameserver $NAMESERVER
EOF
chattr +i /etc/resolv.conf

echo " [+] $(date) Install tools (net-tools, etc)..."
apt install -y net-tools