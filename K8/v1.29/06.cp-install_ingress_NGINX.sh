#!/bin/bash
#-/usr/bin/env bash

source ../../common/bash_lib.sh

msg info "Starting $0."

msg info "Install ingress-nginx..."
#kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml
#Enable SSL passthrough, see https://redis.io/docs/latest/operate/kubernetes/networking/ingress/#prerequisites
curl -o ingress-nginx-deploy.yaml  https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml
sed -i "/- \/nginx-ingress-controller/a\ \ \ \ \ \ \ \ - --enable-ssl-passthrough" ./ingress-nginx-deploy.yaml
kubectl apply -f ./ingress-nginx-deploy.yaml

msg info "Wait for ingress-nginx controller pod..."
while [ $(kubectl get pods -n ingress-nginx |grep 'ingress-nginx-controller.* *1/1 *Running'|wc -l) -lt 1 ] ; do kubectl get pods -n ingress-nginx -o wide; sleep 20; done; kubectl get pods -n ingress-nginx -o wide
msg info "Install ingress-nginx... Done."

msg info "$0 done."