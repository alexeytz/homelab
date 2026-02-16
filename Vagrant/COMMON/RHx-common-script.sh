cat $0
echo
echo Executing common customization script: $0

echo " [+] $(date) Stop and Disable firewall..."
systemctl stop firewalld
systemctl disable firewalld