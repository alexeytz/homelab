#!/bin/bash
#-/usr/bin/env bash

echo "Starting $0."

# Check if namespace and version-bundle-folder parameters are provided, exit with message if not.
test "$1" = '' && echo "Execution is: ./_REC-install.sh <NAMESPACE> <VERSION-BUNDLE-FOLDER>";
test "$1" = '' && exit 1;
test "$2" = '' && echo "Execution is: ./_REC-install.sh <NAMESPACE> <VERSION-BUNDLE-FOLDER>";
test "$2" = '' && exit 1;

# Create REC YAML file for the specified namespace and version bundle folder.
echo " [+] Create ./$2/$1-REC.yaml"
cat <<EOF | tee ./$2/$1-REC.yaml
apiVersion: "app.redislabs.com/v1"
kind: "RedisEnterpriseCluster"
metadata:
  name: $1-rec
spec:
  username: redis@redis.com
  nodes: 3
  redisEnterpriseNodeResources:
    limits:
        cpu: 2000m
        memory: 3Gi
    requests:
        cpu: 2000m
        memory: 3Gi
  persistentSpec:
    enabled: false
    #storageClassName: "standard"
    #volumeSize: "23Gi” #optional
EOF
echo " . . . "

# Create the specified namespace if it does not exist.
echo " [+] Running: kubectl create namespace $1 || exit" && \
kubectl create namespace $1 || exit && \

# Set the context to the created namespace.
echo " [+] Running: kubectl config set-context --current --namespace=$1" && \
kubectl config set-context --current --namespace=$1 && \

# Label the namespace with its name for matching purposes later on.
echo " [+] Running: kubectl label namespaces $1 namespace-name=$1 --overwrite=true" && \
kubectl label namespaces $1 namespace-name=$1 --overwrite=true && \

# Apply the bundle.yaml file from the version-bundle-folder to create necessary components.
echo " [+] Running: kubectl apply -f ./$2/bundle.yaml" && \
kubectl apply -f ./$2/bundle.yaml && \

# Wait for the redis-enterprise-operator deployment to be ready.
echo " [+] Waiting for redis-enterprise-operator to get ready ..." && \
while [ $(kubectl get deployment|grep "^redis-enterprise-operator *1/1 *1 *1"|wc -l) -lt 1 ] ; do kubectl get deployment; sleep 5; done; kubectl get deployment && \

# Apply the REC YAML file to create the Redis Enterprise Cluster.
echo " [+] Running: kubectl apply -f ./$2/$1-REC.yaml" && \
kubectl apply -f ./$2/$1-REC.yaml && \

# Wait for the first REC pod to be ready and then wait for all pods in the statefulset to roll out.
echo " [+] Waiting for a first REC pod to get ready ..." && \
while [ $(kubectl get pods|grep "rec-0 *2/2 *Running"|wc -l) -lt 1 ] ; do kubectl get pods -o wide; sleep 20; done; kubectl get pods -o wide && \
echo " [+] First pod $1-rec0 is ready. Switching to kubectl rollout status sts/$1-rec ..." && \
echo " [+] Waiting for $1-rec cluster to get ready ..." && \
kubectl rollout status sts/$1-rec && kubectl get pods -o wide && \

# Wait for the admission-tls secret to be created.
echo " [+] Waiting for admission-tls secret to get ready ..." && \
while [ $(kubectl get secret admission-tls|grep "^admission-tls *Opaque *2"|wc -l) -lt 1 ] ; do kubectl get secret admission-tls; sleep 5; done && \

# Save cert
CERT=$(kubectl get secret admission-tls -o jsonpath='{.data.cert}') && \
echo " [+] Applying admission/webhook.yaml" && \
sed "s/namespace:.*/namespace: $1/g"           ./$2/admission/webhook.yaml | kubectl create -f - && \

# Wait for the webhook to be ready.
echo " [+] 10 seconds sleep for admission/webhook.yaml being ready..." && \
sleep 10 && \

# Create patch file
echo " [+] Create ./$2/$1-REC-modified-webhook.yaml"
cat <<EOF | tee ./$2/$1-REC-modified-webhook.yaml
webhooks:
- name: redisenterprise.admission.redislabs
  clientConfig:
    caBundle: $CERT
  admissionReviewVersions: ["v1beta1"]
  namespaceSelector:
    matchLabels:
      namespace-name: $1
EOF
# Patch webhook with caBundle
echo " [+] Patch webhook with certificate $CERT and $1" && \
kubectl patch ValidatingWebhookConfiguration redis-enterprise-admission --patch "$(cat ./$2/$1-REC-modified-webhook.yaml)" && \

# Wait for all configurations to be settled.
echo " [+] 30 seconds sleep for all configs being settled ..." && \
sleep 30

echo "$0 done."
