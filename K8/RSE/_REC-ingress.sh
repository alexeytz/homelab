#!/bin/bash
#-/usr/bin/env bash

# Check if namespace and version-bundle-folder parameters are provided, exit with message if not.
test "$1" = '' && echo "Execution is: ./_REC-ingress.sh <Config (RSE_config.sh)> <VERSION-BUNDLE-FOLDER>";
test "$1" = '' && exit 1;
test "$2" = '' && echo "Execution is: ./_REC-ingress.sh <Config (RSE_config.sh)> <VERSION-BUNDLE-FOLDER>";
test "$2" = '' && exit 1;

echo "Starting $0."

source $1

BUNDLE_NAME=$2

# Create the Ingress UI YAML file
echo " [+] Create ./$BUNDLE_NAME/$REC_NAME-ingress-ui.yaml"
cat <<EOF | tee ./$BUNDLE_NAME/$REC_NAME-ingress-ui.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $REC_NAME-ui-ingress
  namespace: $NAMESPACE
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
spec:
  ingressClassName: nginx
  rules:
    - host: $REC_NAME-ui.$BASE_FQDN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: $REC_NAME-ui
                port:
                  number: 8443
EOF

# Create the Ingress REST YAML file
echo " [+] Create ./$BUNDLE_NAME/$REC_NAME-ingress-rest.yaml"
cat <<EOF | tee ./$BUNDLE_NAME/$REC_NAME-ingress-rest.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $REC_REST_INGRESS_NAME
  namespace: $NAMESPACE
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
spec:
  ingressClassName: nginx
  rules:
    - host: $REC_NAME-rest.$BASE_FQDN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: $REC_NAME
                port:
                  number: 9443
EOF

# Apply the Ingress UI YAML file to Kubernetes cluster
echo " [+] Running: kubectl apply -n $NAMESPACE -f ./$BUNDLE_NAME/$REC_NAME-ingress-ui.yaml" && \
kubectl apply -f ./$BUNDLE_NAME/$REC_NAME-ingress-ui.yaml && \

# Apply the Ingress REST YAML file to Kubernetes cluster
echo " [+] Running: kubectl apply -n $NAMESPACE -f ./$BUNDLE_NAME/$REC_NAME-ingress-rest.yaml" && \
kubectl apply -f ./$BUNDLE_NAME/$REC_NAME-ingress-rest.yaml && \

echo "$0 done."
