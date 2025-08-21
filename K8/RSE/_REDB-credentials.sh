#!/bin/bash
#-/usr/bin/env bash

# Check if namespace parameter provided, exit with message if not.
test "$1" = '' && echo "Execution is: ./_REDB-credentials.sh <NAMESPACE>";
test "$1" = '' && exit 1;

DB_LIST=$(kubectl get redb -n $1 -o jsonpath="{.items[*].metadata.name}")

for i in $DB_LIST; do

DB_SECRET=$(kubectl get redb -n $1 $i -o jsonpath="{.spec.databaseSecretName}")
DB_PASSWORD_TEXT=$(kubectl get secret -n $1 $DB_SECRET -o jsonpath="{.data.password}" | base64 --decode)

echo "$i: $DB_PASSWORD_TEXT"

done