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

msg info "Running: kubeadm config images pull."
kubeadm config images pull --kubernetes-version stable-${k8Version}

# Set the --node-ip argument for kubelet
touch /etc/sysconfig/kubelet
echo "KUBELET_EXTRA_ARGS=--node-ip=$controlPLANE_IP" > /etc/sysconfig/kubelet
systemctl enable kubelet

msg info "Apply: kubeadm init --kubernetes-version stable-${k8Version} --token $k8Token --apiserver-advertise-address $controlPLANE_IP --apiserver-bind-port $controlPLANE_PORT --pod-network-cidr=$podNETWORKcidr"
kubeadm init --kubernetes-version stable-${k8Version} --token $k8Token --apiserver-advertise-address $controlPLANE_IP --apiserver-bind-port $controlPLANE_PORT --pod-network-cidr=$podNETWORKcidr

# Copy the kube config file to home directories
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

msg info "Set aliases and TAB completion."
echo "alias oc=kubectl" >> /root/.bashrc
echo "alias kc=kubectl" >> /root/.bashrc
echo 'source <(kubectl completion bash)' >>/root/.bashrc
echo 'complete -o default -F __start_kubectl kc' >> /root/.bashrc
echo 'complete -o default -F __start_kubectl oc' >> /root/.bashrc
msg info "Set aliases and TAB completion. Done."

#https://github.com/kubernetes-sigs/cri-tools/issues/153
msg info "Apply: crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock --set image-endpoint=unix:///run/containerd/containerd.sock (https://github.com/kubernetes-sigs/cri-tools/issues/153)"
crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock --set image-endpoint=unix:///run/containerd/containerd.sock

msg info "$0 done."