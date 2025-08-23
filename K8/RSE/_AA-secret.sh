#!/bin/bash
#-/usr/bin/env bash

if ! command -v jq >/dev/null 2>&1; then
    echo "jq binary not found in PATH. Install jq before running this script."
    exit 1
fi

# Check if namespace and version-bundle-folder parameters are provided, exit with message if not.
test "$1" = '' && echo "Execution is: ./_REC-install.sh <Config (RSE_config.sh)> <VERSION-BUNDLE-FOLDER>";
test "$1" = '' && exit 1;
test "$2" = '' && echo "Execution is: ./_REC-install.sh <Config (RSE_config.sh)> <VERSION-BUNDLE-FOLDER>";
test "$2" = '' && exit 1;

source $1

BUNDLE_NAME=$2

kubectl_output=$(kubectl get secret $REC_NAME -o json -n $NAMESPACE)

echo " [+] Create ./$BUNDLE_NAME/AA-$REC_NAME-secret.yaml"
cat <<EOF | tee ./$BUNDLE_NAME/AA-$REC_NAME-secret.yaml
apiVersion: $(echo "$kubectl_output" | jq -r .apiVersion)
data:
  password: $(echo "$kubectl_output" | jq -r .data.password)
  username: $(echo "$kubectl_output" | jq -r .data.username)
kind: Secret
metadata:
  name: redis-enterprise-rerc-$(echo "$kubectl_output" | jq -r .metadata.name)
type: Opaque
EOF