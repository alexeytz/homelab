# How to CREATE a Vagrant environment(s)

These CREATE_ENV_config.sh and config_*.sh files are intent to automate the creation of a Vagrant-based test environment by copying custom scripts into a dedicated environment folder and configuring a `config.yaml` file with environment-specific parameters.

**Suggestion:**

* If you're using Windows, consider disabling Hyper-V, as it can interfere with VirtualBox. To get a Bash shell on Windows, install MobaXterm (https://mobaxterm.mobatek.net/download.html ) or Git.

---

## 3 precooked config files

* config_RHEL8.sh - RedHat 8
* config_RHEL10.sh - RedHat 10
* config_U2204.sh - Ubuntu 22.04
* config_ALPINE322.sh - Alpine 3.2.2

### 1. `config*.sh` File (Environment Variables and Defaults)

This file defines environment variables and default values used to configure the Vagrant environment.

**Purpose:**  Centralized configuration of environment-specific settings.

**Variables:**

*   **`ENV_NAME`**: (String) A unique name for the environment (e.g., `_RHEL8`). This name is used as the directory name for the environment’s configuration files.  The underscore prefix is used as a convention.
*   **`host_prefix`**: (String)  A prefix for the hostnames of the virtual machines (e.g., `rh8-n`). VMs will be named based on this prefix and a numerical suffix (e.g., `rh8-n1`, `rh8-n2`).
*   **`ip_prefix`**: (String) The base IP address for the virtual machines (e.g., `192.168.69.8`).  Subsequent VMs will receive concatinated+incremented IP addresses (192.168.69.81, 192.168.69.82, etc).
*   **`vm_box`**: (String) The base box (virtual machine image) to use for the VMs (e.g., `"generic/centos8s"`).  See https://portal.cloud.hashicorp.com/vagrant/discover/generic/centos8s for example.
*   **`SHARED_mount_point`**: (String) The mount point *inside* each VM where the shared folder will be accessible (e.g., `"/vagrant"`).
*   **`SHARED_LOCAL_point`**: (String) The local path on the host machine that will be shared with the VMs (e.g., `"../SHARED"`).  This allows you to share files between your host machine and the VMs.
*   **`network_type`**: (String) The network configuration for the VMs. Supported values are generally `public_network` or `private_network`. `public_network` assigns a public IP address to the VMs, allowing them to be accessed from other machines on the network. `private_network` creates an isolated network for the VMs.
*   **`ram_size`**: (Integer) The amount of RAM (in megabytes) allocated to each VM (e.g., `8192` for 8GB).
*   **`cpu_count`**: (Integer) The number of CPU cores allocated to each VM (e.g., `8`).
*   **`node_count`**: (Integer) The total number of virtual machines to create (e.g., `2`).
*   **`root_password`**: (String) The root password for accessing the VMs.
*   **`common_customization_config`**: (String) The path to a common configuration file that applies to all VMs in the alike environment (E.g. RHEL8).
*   **`common_customization_script`**: (String) The path to a common script that executes on all VMs in the alike environment (E.g. RHEL8).
*   **`customization_config`**: (String)  The path to an environment-specific configuration file.
*   **`customization_script`**: (String) The path to an environment-specific script that executes on the VMs.

**Usage:**  This file is sourced by the `CREATE_ENV_config.sh` script to configure the environment.  Changing the values in this file allows you to customize the environment for different needs.

---

### 2. `CREATE_ENV_config.sh` Script (Environment Setup)

This script automates the creation of a Vagrant environment by:

1.  Parsing command-line arguments.
2.  Sourcing the `config` file to load environment variables.
3.  Creating an environment directory.
4.  Copying a "BluePrint" directory (assumed to contain base Vagrant files) into the environment directory.
5.  Modifying the `config.yaml` file within the environment directory using `sed` to reflect the values from the `config` file.
6.  Copying environment-specific configuration and script files (if they exist) into the environment directory.
7.  Making the script files executable.

**Purpose:** Automated environment creation and configuration.

**Command-line Arguments:**

*   **`-c <CONFIG>`**:  Specifies the path to the `config` file. This is a required argument.
*   **`-f`**:  Force overwrite. If the environment directory already exists, this flag will overwrite it. Without this flag, the script will exit with an error if the directory exists.
*   **`-h`**:  Displays a help message.

**Usage:**

```bash
./CREATE_ENV_config.sh -c config
```

This command will create or overwrite an environment directory based on the settings in the `config` file.

**Important Notes:**

*   **BluePrint Directory:** This script relies on the existence of a "BluePrint" directory in the same location as the script. This directory is expected to contain the base Vagrant files (e.g., `Vagrantfile`, `config.yaml`).