ENV_NAME="_ALPINE322"
# Host prefix for VMs
host_prefix=alpine-n

# IP prefix for VMs in Vagrantfile
ip_prefix=192.168.69.11
#ip_prefix=192.168.45.1

# The box used to create VM nodes (CentOS 8 in this case)
#vm_box="boxen/alpine-3.22" # This BOX version has some networking issues.
vm_box="boxomatic/alpine-3.22"

# Mount point of the shared directory within each VM
SHARED_mount_point="/vagrant"

# Local path for the shared folder on your machine
SHARED_LOCAL_point="../SHARED"

# Type of network (public is used in this case)
network_type=public_network
#network_type=private_network

# Amount of RAM allocated to each VM, in megabytes
ram_size=8192

# Number of CPU cores allocated to each VM
cpu_count=8

# Total number of nodes to create
node_count=1

# Root password for accessing the VMs (it's a good idea to secure your VMs with strong passwords)
root_password="root@123"

# Config used to customize each VM as per environment needs.
#common_customization_config="../COMMON/ALPINEx-common-config.sh"

# Script used to customize each VM as per environment needs.
#common_customization_script="../COMMON/ALPINEx-common-script.sh"

# Config used to customize each VM after it is created.
#customization_config="./COMMON/ALPINE322_customization_config.sh"

# Script used to customize each VM after it is created.
#customization_script="./COMMON/ALPINE322_customization_script.sh"