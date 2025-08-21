#!/bin/bash

# This script adds a Redis Enterprise Database to a namespace with specified version bundle folder.
echo "Starting $0."

# Check if the first argument (namespace) is provided.
test "$1" = '' && echo "Execution is: ./_REDB-add.sh <NAMESPACE> <VERSION-BUNDLE-FOLDER> [DB name (redis-enterprise-database)] [DBport (10001)]";
test "$1" = '' && exit 1;

# Check if the second argument (version-bundle-folder) is provided.
test "$2" = '' && echo "Execution is: ./_REDB-add.sh <NAMESPACE> <VERSION-BUNDLE-FOLDER> [DB name (redis-enterprise-database)] [DBport (10001)]";
test "$2" = '' && exit 1;

# Get modules version for Redis Enterprise Cluster.
ReJSON_version=$(kubectl describe rec -n $1 $1-rec|grep -A 2 ReJSON|tail -1|tr -d ' ')
search_version=$(kubectl describe rec -n $1 $1-rec|grep -A 2 search|tail -1|tr -d ' ')

# Output the path to the generated Redis Enterprise Database YAML file.
echo " [+] Create ./$2/$1-enterprise-database.yaml"

test "$3" = '' && DB_NAME="redis-enterprise-database" || DB_NAME=$3
test "$4" = '' && DB_PORT="redis-enterprise-database" || DB_PORT=$4

# Generate and save the Redis Enterprise Database YAML file.
cat <<EOF | tee ./$2/$DB_NAME.yaml
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseDatabase
metadata:
  name: $DB_NAME
spec:
  memorySize: 100MB
  tlsMode: enabled
  redisEnterpriseCluster:
    name: $1-rec
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
echo " [+] Running: kubectl apply -n $1 -f ./$2/$1-enterprise-database.yaml" && \
kubectl apply -n $1 -f ./$2/$1-enterprise-database.yaml

# Inform user how to delete the created Redis Enterprise Database.
echo " [+] To delete DB $DB_NAME, use: kubectl delete redb $DB_NAME -n $1"

# Signal completion of script execution.
echo "$0 done."


# 1.  Remember the namespace that is currently active
CUR_NS=$(kubectl config view --minify \
        -o jsonpath='{.contexts[0].context.namespace}')

# 2.  Switch to the namespace you want for this session
kubectl config set-context --current --namespace=my‑ns

# ------------------------------------------------------------------
# 3.  Run whatever kubectl commands you need…
# ------------------------------------------------------------------
kubectl get pods           # …in my‑ns, automatically

# 4.  When you’re finished, restore the original namespace
kubectl config set-context --current --namespace=${CUR_NS:-default}