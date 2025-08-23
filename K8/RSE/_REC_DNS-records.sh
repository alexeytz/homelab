#!/bin/bash
#-/usr/bin/env bash

# Check if namespace and version-bundle-folder parameters are provided, exit with message if not.
test "$1" = '' && echo "Execution is: ./_REC_DNS-records.sh <NAMESPACE>"
test "$1" = '' && exit 1;

OLDIFS=$IFS;IFS=$'\n';for h in $(kubectl get ingress -n $1|grep ^$1|awk '{print $4" "$3}'); do echo "grep \"$h\" /etc/hosts || echo \"$h\" >> /etc/hosts"; done; IFS=$OLDIFS;