ENV_NAME="_RHEL9_Vagrant-BOX"
# Host prefix for VMs
host_prefix=vagrant

# IP prefix for VMs in Vagrantfile
ip_prefix=192.168.69.9
#ip_prefix=192.168.45.1

# The box used to create VM nodes (CentOS 9 in this case)
vmbox="centos/stream9"
vmbox_guest_additions_installed=false
vmbox_guest_additions_installation_script="../COMMON/RHx-guest_additions-script.sh"

# Mount point of the shared directory within each VM
SHARED_mount_point="/vagrant"

# Local path for the shared folder on your machine
SHARED_LOCAL_point="../SHARED"

# Type of network (public is used in this case)
network_type=public_network
#network_type=private_network

# Amount of RAM allocated to each VM, in megabytes
ram_size=2048

# Number of CPU cores allocated to each VM
cpu_count=2

# Total number of nodes to create
node_count=1

# Root password for accessing the VMs (it's a good idea to secure your VMs with strong passwords)
root_password="root@123"

# Config used to customize each VM as per environment needs.
common_customization_config="../COMMON/RHx-common-config.sh"

# Script used to customize each VM as per environment needs.
common_customization_script="../COMMON/RHx-common-script.sh"

# Config used to customize each VM after it is created.
#customization_config="./COMMON/RH10_customization_config.sh"

# Script used to customize each VM after it is created.
customization_script="./COMMON/RH10_customization_script.sh"