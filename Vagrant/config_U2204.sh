ENV_NAME="_U2204"
# Host prefix for VMs
host_prefix=u2204-n

# IP prefix for VMs in Vagrantfile
ip_prefix=192.168.69.6

# The box used to create VM nodes (CentOS 8 in this case)
#vm_box="generic/ubuntu2204"
vm_box="ubuntu/jammy64"

# Mount point of the shared directory within each VM
SHARED_mount_point="/vagrant"

# Local path for the shared folder on your machine
SHARED_LOCAL_point="../SHARED"

# Type of network (public is used in this case)
network_type=public_network

# Amount of RAM allocated to each VM, in megabytes
ram_size=8192

# Number of CPU cores allocated to each VM
cpu_count=8

# Total number of nodes to create
node_count=3

# Root password for accessing the VMs (it's a good idea to secure your VMs with strong passwords)
root_password="root@123"

# Config used to customize each VM as per environment needs.
common_customization_config="../COMMON/Ux-common-config.sh"

# Script used to customize each VM as per environment needs.
common_customization_script="../COMMON/Ux-common-script.sh"

# Config used to customize each VM after it is created.
#customization_config="./COMMON/RH8_customization_config.sh"

# Script used to customize each VM after it is created.
#customization_script="./COMMON/RH8_customization_script.sh"