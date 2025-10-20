cat $0
echo
echo Executing customization script: $0

dnf install -y epel-release

dnf install -y jq net-tools
