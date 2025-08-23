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

kubectl_output_rec=$(kubectl get rec $REC_NAME -o json -n $NAMESPACE)

echo " [+] Create ./$BUNDLE_NAME/AA-$REC_NAME-rerc.yaml"
cat <<EOF | tee ./$BUNDLE_NAME/AA-$REC_NAME-rerc.yaml
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseRemoteCluster
metadata:
  name: rerc-$(echo "$kubectl_output_rec" | jq -r .metadata.name)
spec:
  recName: $(echo "$kubectl_output_rec" | jq -r .metadata.name)
  recNamespace: $(echo "$kubectl_output_rec" | jq -r .metadata.namespace)
  apiFqdnUrl: $(kubectl get ingress $REC_REST_INGRESS_NAME -n $NAMESPACE -o jsonpath='{.spec.rules[*].host}')
  dbFqdnSuffix: $AA_dbFqdnSuffix
  secretName: redis-enterprise-rerc-$(echo "$kubectl_output_rec" | jq -r .metadata.name)
EOF