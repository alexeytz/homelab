#!/bin/bash
#-/usr/bin/env bash

# Check if namespace parameter provided, exit with message if not.
test "$1" = '' && echo "Execution is: ./_REDB-list.sh <NAMESPACE>";
test "$1" = '' && exit 1;

kubectl get redb -n $1