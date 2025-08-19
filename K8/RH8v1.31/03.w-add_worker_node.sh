#!/bin/bash
#-/usr/bin/env bash

source ../../common/bash_lib.sh

msg info "Starting $0."

test "$1" = '' && echo "Execution is: $0 <config_file_to_source>"
test "$1" = '' && exit 1

source $1

K8_subnet=$(echo "$controlPLANE_IP" | sed -E 's/^(.+)\.[0-9]+$/\1/')
K8_self_IP=$(hostname -I|sed "s/.*\($K8_subnet\.[0-9]\+\).*/\1/")
msg info "K8_self_IP: $K8_self_IP"

msg info "Waiting for kube-apiserver being ready (curl -k https://$controlPLANE_IP:$controlPLANE_PORT/livez)"
until [ "$(curl -k https://$controlPLANE_IP:$controlPLANE_PORT/livez)" == "ok" ]; do echo "Waiting for Control Plane $controlPLANE_IP:$controlPLANE_PORT..."; curl -k https://$controlPLANE_IP:$controlPLANE_PORT/livez?verbose; sleep 10; done

# Just to be on a safe side since it may fluctuate sometimes.
sleep 5

touch /etc/sysconfig/kubelet
echo "KUBELET_EXTRA_ARGS=--node-ip=$K8_self_IP" > /etc/sysconfig/kubelet
systemctl enable kubelet

msg info "Executing: kubeadm join --token $k8Token $controlPLANE_IP:$controlPLANE_PORT --discovery-token-unsafe-skip-ca-verification"
kubeadm join --token $k8Token $controlPLANE_IP:$controlPLANE_PORT --discovery-token-unsafe-skip-ca-verification
#kubeadm join --token $k8Token $controlPLANE_IP:$controlPLANE_PORT --discovery-token-unsafe-skip-ca-verification --v=10

#https://github.com/kubernetes-sigs/cri-tools/issues/153
msg info "Apply: crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock --set image-endpoint=unix:///run/containerd/containerd.sock ..."
crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock --set image-endpoint=unix:///run/containerd/containerd.sock


msg info "$0 done."