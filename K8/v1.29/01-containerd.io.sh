#!/bin/bash
#-/usr/bin/env bash

source ../../common/bash_lib.sh

msg info "Starting $0."

msg info "Add Docker repository."
yum config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo

msg info "Install containerd.io."
yum install -y containerd.io

msg info "Start containerd to make sure it creates /etc/containerd."
systemctl start containerd
msg info "Apply default config as: containerd config default > /etc/containerd/config.toml"
containerd config default > /etc/containerd/config.toml
msg info "Restart and enable conteinerd service"
systemctl restart containerd
systemctl enable containerd

msg info "$0 done."