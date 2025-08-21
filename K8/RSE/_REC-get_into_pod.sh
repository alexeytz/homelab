#!/bin/bash
#-/usr/bin/env bash

echo "Starting $0."

test "$1" = '' && echo "Execution is: ./_REC-get_into_pod.sh <NAMESPACE> [POD id: 0/1/2/etc, defaults to 1. 0 = Operator pod.]";
test "$1" = '' && exit 1;

NS=$1 # Set the namespace variable
test "$2" = '' && ID=1 || ID=$2 # Set the pod ID variable

POD=$(kubectl get pods -n $NS -o jsonpath="{.items[$ID].metadata.name}") # Get the pod name based on the provided ID
echo " [+] kubectl exec -n $NS --stdin --tty $POD -- /bin/bash" # Print a message to indicate which command will be executed next

kubectl exec -n $NS --stdin --tty $POD -- /bin/bash # Execute a bash shell in the selected pod

