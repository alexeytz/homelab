#!/bin/bash
#-/usr/bin/env bash

echo "Starting $0."

# Check if namespace and version-bundle-folder parameters are provided, exit with message if not.
test "$1" = '' && echo "Execution is: ./_REC-install.sh <Config (RSE_config.sh)> <VERSION-BUNDLE-FOLDER>";
test "$1" = '' && exit 1;
test "$2" = '' && echo "Execution is: ./_REC-install.sh <Config (RSE_config.sh)> <VERSION-BUNDLE-FOLDER>";
test "$2" = '' && exit 1;

source $1

BUNDLE_NAME=$2

# Create REC YAML file for the specified namespace and version bundle folder.
echo " [+] Create ./$BUNDLE_NAME/$REC_NAME.yaml"
cat <<EOF | tee ./$BUNDLE_NAME/$REC_NAME.yaml
apiVersion: "app.redislabs.com/v1"
kind: "RedisEnterpriseCluster"
metadata:
  name: $REC_NAME
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
echo " [+] Running: kubectl create namespace $NAMESPACE || exit" && \
kubectl create namespace $NAMESPACE || exit && \

# Set the context to the created namespace.
#echo " [+] Running: kubectl config set-context --current --namespace=$NAMESPACE" && \
#kubectl config set-context --current --namespace=$NAMESPACE && \

# Label the namespace with its name for matching purposes later on.
echo " [+] Running: kubectl label namespaces $NAMESPACE namespace-name=$NAMESPACE --overwrite=true" && \
kubectl label namespaces $NAMESPACE namespace-name=$NAMESPACE --overwrite=true && \

# Apply the bundle.yaml file from the version-bundle-folder to create necessary components.
echo " [+] Running: kubectl apply -n $NAMESPACE -f ./$BUNDLE_NAME/bundle.yaml" && \
kubectl apply -n $NAMESPACE -f ./$BUNDLE_NAME/bundle.yaml && \

# Wait for the redis-enterprise-operator deployment to be ready.
echo " [+] Waiting for redis-enterprise-operator to get ready ..." && \
while [ $(kubectl get deployment -n $NAMESPACE|grep "^redis-enterprise-operator *1/1 *1 *1"|wc -l) -lt 1 ] ; do kubectl get deployment -n $NAMESPACE; sleep 5; done; kubectl get deployment -n $NAMESPACE && \

# Apply the REC YAML file to create the Redis Enterprise Cluster.
echo " [+] Running: kubectl apply -n $NAMESPACE -f ./$BUNDLE_NAME/$REC_NAME.yaml" && \
kubectl apply -n $NAMESPACE -f ./$BUNDLE_NAME/$REC_NAME.yaml && \

# Wait for the first REC pod to be ready and then wait for all pods in the statefulset to roll out.
echo " [+] Waiting for a first REC pod to get ready ..." && \
while [ $(kubectl get pods -n $NAMESPACE|grep "$REC_NAME-0 *2/2 *Running"|wc -l) -lt 1 ] ; do kubectl get pods -n $NAMESPACE -o wide; sleep 20; done; kubectl get pods -n $NAMESPACE -o wide && \
echo " [+] First pod ${REC_NAME}-0 is ready. Switching to kubectl rollout status sts/$REC_NAME -n $NAMESPACE ..." && \
echo " [+] Waiting for $REC_NAME cluster to get ready ..." && \
kubectl rollout status sts/$REC_NAME -n $NAMESPACE && kubectl get pods -n $NAMESPACE -o wide && \

# Wait for the admission-tls secret to be created.
echo " [+] Waiting for admission-tls secret to get ready ..." && \
while [ $(kubectl get secret admission-tls -n $NAMESPACE|grep "^admission-tls *Opaque *2"|wc -l) -lt 1 ] ; do kubectl get secret admission-tls -n $NAMESPACE; sleep 5; done && \

# Save cert
CERT=$(kubectl get secret admission-tls -n $NAMESPACE -o jsonpath='{.data.cert}') && \
echo " [+] Applying admission/webhook.yaml" && \
sed "s/namespace:.*/namespace: $NAMESPACE/g" ./$BUNDLE_NAME/admission/webhook.yaml | kubectl create -n $NAMESPACE -f - && \

#sed -e "s/namespace:.*/namespace: rse/g" -e "s/caBundle:.*/caBundle: XYZ/g" ./redis-enterprise-k8s-docs-7.22.0-16/admission/webhook.yaml

# Wait for the webhook to be ready.
echo " [+] 10 seconds sleep for admission/webhook.yaml being ready..." && \
sleep 10 && \

# Create patch file
echo " [+] Create ./$BUNDLE_NAME/$REC_NAME-modified-webhook.yaml"
cat <<EOF | tee ./$BUNDLE_NAME/$REC_NAME-modified-webhook.yaml
webhooks:
- name: redisenterprise.admission.redislabs
  clientConfig:
    caBundle: $CERT
  admissionReviewVersions: ["v1beta1"]
  namespaceSelector:
    matchLabels:
      namespace-name: $NAMESPACE
EOF
# Patch webhook with caBundle
echo " [+] Patch webhook with certificate $CERT and $NAMESPACE" && \
kubectl patch -n $NAMESPACE ValidatingWebhookConfiguration redis-enterprise-admission --patch "$(cat ./$BUNDLE_NAME/$REC_NAME-modified-webhook.yaml)" && \

# Wait for all configurations to be settled.
echo " [+] rec status:" && \
kubectl get rec -n $NAMESPACE && \
kubectl get pods -n $NAMESPACE

echo "$0 done."
