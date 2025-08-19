#!/bin/bash
#-/usr/bin/env bash

source ../../common/bash_lib.sh

msg info "Starting $0."

test "$1" = '' && echo "Execution is: $0 <config_file_to_source>"
test "$1" = '' && exit 1

source $1

hostname -I|grep $controlPLANE_IP;hostname_result=$?
test $hostname_result -eq 0 && echo " . . Control Plane node. Continue..." || \
msg error " . . You shall not run this script on the non Control Plane nodes. Exiting."
test $hostname_result -eq 0 || exit 0

until [ "$(curl -k https://$controlPLANE_IP:$controlPLANE_PORT/livez)" == "ok" ]; do echo "Waiting for Control Plane $controlPLANE_IP:$controlPLANE_PORT..."; curl -k https://$controlPLANE_IP:$controlPLANE_PORT/livez?verbose; sleep 10; done

# Install Calico - K8 requires CNI plugin for pod network: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network
msg info "Install calico."
#kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/release-v3.25/manifests/tigera-operator.yaml
cat <<EOF | tee /root/calico-installation.yaml
# This section includes base Calico installation configuration.
# For more information, see: https://docs.projectcalico.org/v3.19/reference/installation/api#operator.tigera.io/v1.Installation
apiVersion: operator.tigera.io/v1
kind: Installation
apiVersion: operator.tigera.io/v1
metadata:
  name: default
spec:
  # Configures Calico networking.
  calicoNetwork:
    bgp: Enabled  
    # Note: The ipPools section cannot be modified post-install.
    ipPools:
    - blockSize: 26
      cidr: $podNETWORKcidr
      encapsulation: IPIP
      natOutgoing: Enabled
      nodeSelector: all()
EOF
kubectl apply -f /root/calico-installation.yaml
msg info "Wait for calico-system controller pod."
while [ $(kubectl get pods -n calico-system |grep 'calico-kube-controllers.* *1/1 *Running'|wc -l) -lt 1 ] ; do kubectl get pods -n calico-system -o wide; sleep 20; done; kubectl get pods -n calico-system -o wide
msg info "Install calico. Done."

msg info "Install calicoctl."
# Install calicoctl https://docs.tigera.io/calico/latest/operations/calicoctl/install#install-calicoctl-as-a-binary-on-a-single-host
curl -L https://github.com/projectcalico/calico/releases/download/v3.25.0/calicoctl-linux-amd64 -o calicoctl
chmod +x calicoctl
mv calicoctl /usr/local/bin/
#sudo mkdir /etc/calico
#sudo cp /vagrant/calicoctl.cfg /etc/calico/
mkdir -p /etc/calico
cat <<EOF | tee /etc/calico/calicoctl.cfg 
apiVersion: projectcalico.org/v3
kind: CalicoAPIConfig
metadata:
spec:
  datastoreType: "kubernetes"
  kubeconfig: "/root/.kube/config"
EOF

msg info "Install calicoctl. Done."


msg info "$0 done."