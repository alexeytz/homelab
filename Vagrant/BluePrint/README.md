## Disclamer

This automation streamlines the creation of isolated test environments on a single host machine. It's designed for scenarios where you have ample RAM and CPU cores available – ideal for a homelab setup. You can often acquire suitable refurbished servers with generous resources (e.g., 128GB+ RAM, 40+ cores) for a surprisingly affordable price – around $300 or less – from online marketplaces like eBay. This setup allows you to run multiple virtual machines/environments concurrently.

## 1. Setup

This Vagrantfile automates the creation and configuration of multiple virtual machines (VMs) based on a configuration file (`config.yaml`).  It allows for easily provisioning a set of VMs with consistent settings, including hostnames, IP addresses, RAM, CPU count, and custom scripts.

**Prerequisites:**

*   **Vagrant:**  Install Vagrant from [https://www.vagrantup.com/downloads](https://www.vagrantup.com/downloads).
*   **VirtualBox:** Install VirtualBox from [https://www.virtualbox.org/wiki/Downloads](https://www.virtualbox.org/wiki/Downloads).  (Or another supported Vagrant provider).
*   **`config.yaml`:** Create a `config.yaml` file (see section 2 for the expected structure).  This file defines the configuration for the VMs.
*   **Customization Scripts (Optional):**  Prepare any custom scripts you want to run during the VM provisioning process (e.g., `customization_config`, `customization_script`, `common_customization_config`, `common_customization_script`).

## 2. Configuration File (`config.yaml`)

The `config.yaml` file defines the parameters used to create and configure the VMs. Here's a breakdown of each setting:

*   **`host_prefix: bp-n`**: This defines the prefix for the hostnames of the VMs. The VMs will be named `bp-n1`, `bp-n2`, etc., based on the `node_count`.
*   **`ip_prefix: 192.168.69.1`**: This defines the base IP address for the VMs. The IPs will be assigned sequentially starting from `192.168.69.11`, i.e., `192.168.69.11`, `192.168.69.12`, etc., based on the `node_count`.
*   **`vm_box: "any"`**: This specifies the base box (virtual machine image) used to create the VMs.  "any" means Vagrant will attempt to use a default box or one configured.  It's recommended to specify a more defined box (e.g., "centos/8") for consistent results.
*   **`SHARED_mount_point: /mount_point`**: This defines the mount point inside each VM where the shared folder will be accessible. The host directory specified by `SHARED_LOCAL_point` will be mounted at `/mount_point` within the guest VM.
*   **`SHARED_LOCAL_point: ../FOLDER`**: This specifies the local directory on the host machine that will be shared with the VMs. The directory should be relative or absolute, and the VMs will be able to access files within this directory.
*   **`network_type: private_network`**: This determines how the VMs connect to the network. `private_network` creates a network isolated from the host machine's external network.
*   **`ram_size: 1024`**: This specifies the amount of RAM (in megabytes) allocated to each VM. In this case, each VM will have 1024MB (1GB) of RAM.
*   **`cpu_count: 1`**: This specifies the number of CPU cores allocated to each VM.  Each VM will have 1 CPU core assigned.
*   **`node_count: 1`**: This determines the total number of VMs to create. In this configuration, only one VM will be created.
*   **`root_password: root@bp`**: This sets the root password for accessing the VMs.  **Important:**  This is a weak password for demonstration purposes only.
*   **`common_customization_config: ../COMMON/bp-common-config.sh`**: This specifies the path to a configuration file that will be applied to all similar environments (e.g. RHEL8).
*   **`common_customization_script: ../COMMON/bp-common-script.sh`**: This specifies the path to a script that will be executed on all similar environments (e.g. RHEL8).
*   **`customization_config: customization_config.sh`**: This specifies the path to a configuration file that will be applied to each VM of this environment.
*   **`customization_script: customization_script.sh`**: This specifies the path to a script that will be executed on each VM  of this environment.

**Important:**

*   Adjust the `node_count`, `ip_prefix`, `vm_box`, and other parameters to match your environment and requirements.
*   Ensure the base box (`vm_box`) is available locally or can be downloaded by Vagrant. Run `vagrant box list` to see available boxes.
*   The shared folder settings define how your host machine's files are accessible within the VMs.

## 3. Vagrantfile Explanation

The Vagrantfile performs the following steps:

1.  **Loads Configuration:** Reads the `config.yaml` file using the YAML library. If the file cannot be loaded, the script exits with an error message.
2.  **Defines Nodes:** Creates an array of node dictionaries. Each dictionary contains the `hostname` and `ip` address for a VM, derived from the `config.yaml` settings.
3.  **Reads Provisioning Files:** Reads the content of common and custom configuration files and scripts if they exist. If files are not found, default content is used.
4.  **Configures Vagrant:**
    *   Iterates through the `NODES` array.
    *   For each node:
        *   Defines a VM using `config.vm.define`. The hostname of the VM is set using the `hostname` from the node dictionary.
        *   **VirtualBox Provider:** Configures the VirtualBox provider:
            *   `vb.name`: Sets the name of the VM in the VirtualBox manager.
            *   `vb.memory`: Sets the RAM size in MB.
            *   `vb.cpus`: Sets the number of CPUs.
        *   **Base Box and Hostname:** Sets the base box and the hostname for the VM.
        *   **Network Configuration:** Configures the network settings based on the `network_type` specified in the `config.yaml` file. It supports both `public_network` and `private_network`.
        *   **Shared Folder:** Sets up a shared folder between the host machine and the VM, allowing you to access files from both sides.
        *   **Provisioning:**  Adds several provisioning steps using the `shell` provisioner. These steps perform the following actions:
            *   Enable PasswordAuthentication and KbdInteractiveAuthentication in the sshd_config file.
            *   Permit Root Login Yes in the sshd_config file.
            *   Restart the SSH service (using `systemctl` or `rc-service` for compatibility with different Linux distributions).
            *   Set the root password using the `passwd root` command.
            *   Execute the content of the common configuration file.
            *   Execute the content of the custom configuration file.
