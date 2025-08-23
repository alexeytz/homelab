


kubectl apply -f redis-enterprise-k8s-docs-7.22.0-16/AA-rse-rec-8x-secret.yaml -n rse
kubectl apply -f redis-enterprise-k8s-docs-7.22.0-16/AA-rse-rec-18x-secret.yaml -n rse

kubectl create -f redis-enterprise-k8s-docs-7.22.0-16/AA-rse-rec-8x-rerc.yaml -n rse
kubectl create -f redis-enterprise-k8s-docs-7.22.0-16/AA-rse-rec-18x-rerc.yaml  -n rse



apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseActiveActiveDatabase
metadata:
  name: reaadb-rse
spec:
  globalConfigurations:
    databaseSecretName: reaadb-rse-secret
    memorySize: 200MB
    shardCount: 1
  participatingClusters:
      - name: rerc-rse-rec-8x
      - name: rerc-rse-rec-18x