#!/bin/bash
#-/usr/bin/env bash

# Check if namespace and version-bundle-folder parameters are provided, exit with message if not.
test "$1" = '' && echo "Execution is: ./_REC-ingress.sh <NAMESPACE> <VERSION-BUNDLE-FOLDER>";
test "$1" = '' && exit 1;
test "$2" = '' && echo "Execution is: ./_REC-ingress.sh <NAMESPACE> <VERSION-BUNDLE-FOLDER>";
test "$2" = '' && exit 1;

echo "Starting $0."

# Create the Ingress UI YAML file
echo " [+] Create ./$2/$1-ingress-ui.yaml"
cat <<EOF | tee ./$2/$1-ingress-ui.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $1-rec-ui-ingress
  namespace: $1
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
spec:
  ingressClassName: nginx
  rules:
    - host: $1-rec-ui.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: $1-rec-ui
                port:
                  number: 8443
EOF

# Create the Ingress REST YAML file
echo " [+] Create ./$2/$1-ingress-rest.yaml"
cat <<EOF | tee ./$2/$1-ingress-rest.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $1-rec-rest-ingress
  namespace: $1
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
spec:
  ingressClassName: nginx
  rules:
    - host: $1-rec-rest.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: $1-rec
                port:
                  number: 9443
EOF

# Apply the Ingress UI YAML file to Kubernetes cluster
echo " [+] Running: kubectl apply -n $1 -f ./$2/$1-ingress-ui.yaml" && \
kubectl apply -f ./$2/$1-ingress-ui.yaml && \

# Apply the Ingress REST YAML file to Kubernetes cluster
echo " [+] Running: kubectl apply -n $1 -f ./$2/$1-ingress-rest.yaml" && \
kubectl apply -f ./$2/$1-ingress-rest.yaml && \

echo "$0 done."
