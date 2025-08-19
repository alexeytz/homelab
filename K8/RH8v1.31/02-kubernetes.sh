#!/bin/bash
#-/usr/bin/env bash

source ../../common/bash_lib.sh

msg info "Starting $0."

test "$1" = '' && echo "Execution is: $0 <config_file_to_source>"
test "$1" = '' && exit 1

source $1

msg info "Configure Kubernetes repo."

cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${k8Version}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${k8Version}/rpm/repodata/repomd.xml.key
#exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
msg info "Install Kubernetes."
# K8 requires iproute-tc
yum install -y kubelet kubeadm kubectl iproute-tc bash-completion screen

msg info "$0 done."