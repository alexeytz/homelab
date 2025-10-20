#!/bin/bash

# Print usage message
usage() {
    cat <<EOF
Usage: $0 -c <CONFIG> [-f] [-h]

  -c CONFIG   Path to configuration file (required)
  -f          Force the operation
  -h          Show this help message
EOF
    exit 1
}

# Parse options
while getopts ":c:fh" opt; do
  case $opt in
    c) CONFIG_FILE=$OPTARG ;;
    f) FORCE=1 ;;
    h) usage ;;
    \?) echo "Error: Unknown option -$OPTARG" >&2; usage ;;
    :)  echo "Error: Option -$OPTARG requires an argument" >&2; usage ;;
  esac
done

# Check if CONFIG is provided and exists, then source the config file
if [[ -z "$CONFIG_FILE" || ! -r "$CONFIG_FILE" ]]; then
  echo "Error: -c <CONFIG> is required and the file must exist." >&2
  usage
else
  source "$CONFIG_FILE" || { echo "Error: Failed to source $CONFIG_FILE, check file for errors."; exit 1; }
fi


# If FORCE is not set and ENV folder already exists, show an error message
if [[ -z "$FORCE" && -d "./$ENV_NAME" ]]; then
  echo "Error: Folder ./$ENV_NAME already exists. Use -f to overwrite." >&2
  exit 1
fi

# Create a folder for the environment and copy content from BluePrint into it
mkdir -p "$ENV_NAME" && cp -r "./BluePrint/"* "$ENV_NAME/"
if [[ $? -ne 0 ]]; then
  echo "Error: Failed to create environment '$ENV_NAME' or copy the blueprint." >&2
  exit 1
fi

# Check if config.yaml exists in the created ENV folder
if [[ ! -r "./$ENV_NAME/config.yaml" ]]; then
  echo "Error: File ./$ENV_NAME/config.yaml must exist." >&2
  exit 1
fi

# Apply parameters from CONFIG to config.yaml using sed
sed -i "s|ENV_NAME:.*|ENV_NAME: $ENV_NAME|g" ./$ENV_NAME/config.yaml
sed -i "s|host_prefix:.*|host_prefix: $host_prefix|g" "./$ENV_NAME/config.yaml"
sed -i "s|ip_prefix:.*|ip_prefix: $ip_prefix|g" "./$ENV_NAME/config.yaml"
sed -i "s|vm_box:.*|vm_box: $vm_box|g" "./$ENV_NAME/config.yaml"
sed -i "s|SHARED_mount_point:.*|SHARED_mount_point: $SHARED_mount_point|g" "./$ENV_NAME/config.yaml"
sed -i "s|SHARED_LOCAL_point:.*|SHARED_LOCAL_point: $SHARED_LOCAL_point|g" "./$ENV_NAME/config.yaml"
sed -i "s|network_type:.*|network_type: $network_type|g" "./$ENV_NAME/config.yaml"
sed -i "s|ram_size:.*|ram_size: $ram_size|g" "./$ENV_NAME/config.yaml"
sed -i "s|cpu_count:.*|cpu_count: $cpu_count|g" "./$ENV_NAME/config.yaml"
sed -i "s|node_count:.*|node_count: $node_count|g" "./$ENV_NAME/config.yaml"
sed -i "s|root_password:.*|root_password: $root_password|g" "./$ENV_NAME/config.yaml"
sed -i "s|common_customization_config:.*|common_customization_config: $common_customization_config|g" "./$ENV_NAME/config.yaml"
sed -i "s|common_customization_script:.*|common_customization_script: $common_customization_script|g" "./$ENV_NAME/config.yaml"

# If ENV specific configuration files exist, copy these into the ENV folder
if [[ -f "$customization_config" ]]; then
  cp "$customization_config" "./$ENV_NAME/customization_config.sh"
  echo "File $customization_config copied to ./$ENV_NAME/customization_config.sh."
fi
if [[ -f "$customization_script" ]]; then
  cp "$customization_script" "./$ENV_NAME/customization_script.sh"
  echo "File $customization_script copied to ./$ENV_NAME/customization_script.sh."
fi

# Make all *.sh scripts in the ENV folder executable
chmod +x ./$ENV_NAME/*.sh || { echo "Error: Failed to make scripts executable"; exit 1; }

echo "Environment $ENV_NAME set up successfully."
exit 0