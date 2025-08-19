#!/bin/bash
#-/usr/bin/env bash

test "$1" = '' && echo "Execution is: $0 <config_file_to_source>"
test "$1" = '' && exit 1

./00-prerequisites.sh
./01-containerd.io.sh
./02-kubernetes.sh
./03.cp-kubernetes_cluster_create.sh $1
./04.cp-install_CNI_calico.sh $1