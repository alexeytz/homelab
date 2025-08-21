#!/bin/bash
#-/usr/bin/env bash

# Check is jq package is available.
if ! command -v jq >/dev/null 2>&1; then
    echo "jq binary not found in PATH. Install jq before running this script."
    exit 1
fi

# Check if namespace and version-bundle-folder parameters are provided, exit with message if not.
test "$1" = '' && echo "Execution is: ./_REC-ingress.sh <NAMESPACE> <VERSION-BUNDLE-FOLDER>";
test "$1" = '' && exit 1;
test "$2" = '' && echo "Execution is: ./_REC-ingress.sh <NAMESPACE> <VERSION-BUNDLE-FOLDER>";
test "$2" = '' && exit 1;

echo "Starting $0."

# Fetch the list of RedB database from the redis namespace
DB_LIST=$(kubectl get redb -n $1 -o jsonpath="{.items[*].metadata.name}")

for i in $DB_LIST; do

# Fetch the port number for each RedB instance
PORT=$(kubectl get redb -n rse -o json |  jq -r ".items[] | select(.metadata.name==\"$i\") | .spec.databasePort")

echo " [+] Create ./$2/$1-ingress_$i.yaml"
cat <<EOF | tee ./$2/$1-ingress_$i.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $i-ingress
  namespace: $1
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
spec:
  ingressClassName: nginx
  rules:
    - host: $i.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: $i
                port:
                  number: $PORT
EOF
done

# Apply the created Ingress resources to Kubernetes cluster
for i in $DB_LIST; do
echo " [+] Running: kubectl apply -f ./$2/$1-ingress_$i.yaml" && \
kubectl apply -f ./$2/$1-ingress_$i.yaml
done

echo "$0 done."
