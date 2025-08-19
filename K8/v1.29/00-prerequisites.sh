#!/bin/bash
#-/usr/bin/env bash

source ../../common/bash_lib.sh

msg info "Starting $0."

msg info "Disable swap, as required by kubelet."
swapoff -a
sed -i '/swap/d' /etc/fstab

msg info "Add br_netfilter to kernel and enable ip_forward."
# Need this module in Kernel
echo br_netfilter > /etc/modules-load.d/br_netfilter.conf
systemctl restart systemd-modules-load.service

# it should be 1 by default, but just in case.
echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
# Allow IP forwarding.
echo 1 > /proc/sys/net/ipv4/ip_forward

msg info "$0 done."