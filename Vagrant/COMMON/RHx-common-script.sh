cat $0
echo
echo Executing common customization script: $0

echo " [+] $(date) Stop and Disable firewall..."
systemctl stop firewalld
systemctl disable firewalld

echo " [+] $(date) Set /etc/resolv.conf..."
rm -f /etc/resolv.conf
cat >/etc/resolv.conf<<EOF
options timeout:30
nameserver $NAMESERVER
EOF
chattr +i /etc/resolv.conf