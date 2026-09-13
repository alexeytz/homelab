#!/bin/sh
# Use ./lxc-cli_into.sh <LXC name>
#root@dell7820:~# pct list
#VMID       Status     Lock         Name
#100        running                 open-webui
#106        running                 podman
#107        running                 eggent
#109        running                 kasm
#root@dell7820:~#
pct enter $(pct list|grep $1|awk '{print $1}')
