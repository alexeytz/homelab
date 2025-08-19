#!/bin/bash
#-/usr/bin/env bash

source ../../common/bash_lib.sh

msg info "Starting $0."

test "$1" = '' && echo "Execution is: $0 <config_file_to_source>"
test "$1" = '' && exit 1

source $1

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