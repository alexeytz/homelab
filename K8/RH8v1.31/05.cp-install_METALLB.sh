#!/bin/bash
#-/usr/bin/env bash

source ../../common/bash_lib.sh

msg info "Starting $0."

test "$1" = '' && echo "Execution is: $0 <config_file_to_source>"
test "$1" = '' && exit 1

source $1

hostname -I|grep $controlPLANE_IP;hostname_result=$?
#echo $hostname_result
test $hostname_result -eq 0 && echo " . . Control Plane node. Continue..." || \
msg error " . . You shall not run this script on the non Control Plane nodes. Exiting."
test $hostname_result -eq 0 || exit 0

msg info "Need at least one worker node being ready to proceed with METALLB installation. Waiting for worker nodes to be ready..."
while [ $(kubectl get nodes|grep -v control-plane|grep -w Ready|wc -l) -lt 1 ] ; do kubectl get nodes -o wide; sleep 20; done;
msg info "At least one worker node is available, proceeding with installation."
kubectl get nodes -o wide

msg info "Install https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml
msg info "Wait for metallb-system controller pod..."
while [ $(kubectl get pods -n metallb-system |grep 'controller.* *1/1 *Running'|wc -l) -lt 1 ] ; do kubectl get pods -n metallb-system -o wide; sleep 20; done; kubectl get pods -n metallb-system -o wide
msg info "Install https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml. Done."

kubectl get pods -A -o wide

cat <<EOF | tee /root/$1-metalLB.yaml
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - ${metalLB_IPRange}
  autoAssign: true
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default
EOF
kubectl apply -f /root/$1-metalLB.yaml

sleep 30


msg info "$0 done."