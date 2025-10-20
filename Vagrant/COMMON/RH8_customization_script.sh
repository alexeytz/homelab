cat $0
echo Executing customization script: $0
sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
sed -i "s|#baseurl=http://mirror.centos.org|baseurl=$BASEURL|g" /etc/yum.repos.d/CentOS-*

dnf install -y jq
