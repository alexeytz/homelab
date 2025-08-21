#!/bin/bash
#-/usr/bin/env bash

# Check if namespace and version-bundle-folder parameters are provided, exit with message if not.
test "$1" = '' && echo "Execution is: ./_REC-credentials.sh <NAMESPACE>";
test "$1" = '' && exit 1;

echo "$(kubectl get secret $1-rec -n $1 -o jsonpath='{.data.username}' | base64 --decode)/$(kubectl get secret $1-rec -n $1 -o jsonpath='{.data.password}' | base64 --decode)"