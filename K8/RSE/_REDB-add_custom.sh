#!/bin/bash

# This script adds a Redis Enterprise Database to a namespace with specified version bundle folder.

# Check if the first argument (namespace) is provided.
test "$1" = '' && echo "Execution is: ./_REDB-add_custom.sh <Config (RSE_config.sh)> <VERSION-BUNDLE-FOLDER> [DB name] [DBport]";
test "$1" = '' && exit 1;

source $1

# Check if the second argument (version-bundle-folder) is provided.
test "$2" = '' && echo "Execution is: ./_REDB-add_custom.sh <Config (RSE_config.sh)> <VERSION-BUNDLE-FOLDER> [DB name ($DEFAULT_DB_NAME)] [DBport ($DEFAULT_DB_PORT)]";
test "$2" = '' && exit 1;

BUNDLE_NAME=$2

echo "Starting $0."

# Get modules version for Redis Enterprise Cluster.
ReJSON_version=$(kubectl describe rec -n $NAMESPACE $REC_NAME|grep -A 2 ReJSON|tail -1|tr -d ' ')
search_version=$(kubectl describe rec -n $NAMESPACE $REC_NAME|grep -A 2 search|tail -1|tr -d ' ')



test "$3" = '' && DB_NAME="$DEFAULT_DB_NAME" || DB_NAME=$3
test "$4" = '' && DB_PORT="$DEFAULT_DB_PORT" || DB_PORT=$4

# Output the path to the generated Redis Enterprise Database YAML file.
echo " [+] Create ./$BUNDLE_NAME/$DB_NAME.yaml"
# Generate and save the Redis Enterprise Database YAML file.
cat <<EOF | tee ./$BUNDLE_NAME/$DB_NAME.yaml
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseDatabase
metadata:
  name: $DB_NAME
spec:
  memorySize: 100MB
  tlsMode: enabled
  redisEnterpriseCluster:
    name: $REC_NAME
  databasePort: $DB_PORT
  replication: true
  memorySize: 250MB
  modulesList:
    - name: search
      version: $search_version
      #config:
    - name: ReJSON
      version: $ReJSON_version
EOF

# Apply the generated Redis Enterprise Database YAML file using kubectl.
echo " [+] Running: kubectl apply -n $NAMESPACE -f ./$BUNDLE_NAME/$DB_NAME.yaml" && \
kubectl apply -n $NAMESPACE -f ./$BUNDLE_NAME/$DB_NAME.yaml

# Inform user how to delete the created Redis Enterprise Database.
echo " [+] To delete DB $DB_NAME, use: kubectl delete redb $DB_NAME -n $NAMESPACE"

# Signal completion of script execution.
echo "$0 done."