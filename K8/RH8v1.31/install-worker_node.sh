#!/bin/bash
#-/usr/bin/env bash

test "$1" = '' && echo "Execution is: $0 <config_file_to_source>"
test "$1" = '' && exit 1

./00-prerequisites.sh
./01-containerd.io.sh
./02-kubernetes.sh $1
./03.w-add_worker_node.sh $1