# How to run VLESS on top of Hysteria 2

You might want to take some time to explore https://github.com/XTLS/Xray-core.

You must have Hysteria 2 running as described in https://github.com/alexeytz/homelab/tree/main/VPN/Hysteria2.

The entire configuration was done as root.

This setup has been tested and successfully worked on Ubuntu 24.04.

## Install XRAY

https://github.com/XTLS/Xray-install

```
bash -c "$(curl -4 -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
```

## Configure XRAY

### Set XRAY running under the hysteria user

We want the hysteria user access to the log folder.

```
chmod 777 /var/log/xray && rm -f /var/log/xray/*
```

### Set histeria user in systemd for XRAY

```
cp /etc/systemd/system/xray.service ~/xray.service && \
sed -i 's|User=.*|User=hysteria|' ~/xray.service
cp ~/xray.service /etc/systemd/system/xray.service
```

Reload daemons to apply the change.

```
systemctl daemon-reload
```

### Create XRAY config.json

Take a copy of config-template.json and rename it to config.json, modifying it as per your setup. There are copies of the working/tested config-example and the one used for YouTube. It is straightforward.

```
(base) bb@dell7820:~/homelab/VPN/VLESS-over-Hysteria2$ diff ./config-template.json ./config-example.json
3c3
<       "addr": "REPLACE-DOMAIN"
---
>       "addr": "forest.chickenkiller.com"
52c52
<                   "id": "REPLACE-UUID",
---
>                   "id": "812cc04b-c89e-4758-beed-33b3780c516d",
60,61c60,61
<                   "name": "REPLACE-DOMAIN",
<                   "dest": "REPLACE-IP:REPLACE-PORT"
---
>                   "name": "forest.chickenkiller.com",
>                   "dest": "10.69.2.3:8000"
76,78c76,78
<                      "certificateFile": "REPLACE-CERTIFICATE",
<                      "keyFile": "REPLACE-KEYFILE",
<                      "serverName": "REPLACE-DOMAIN"
---
>                      "certificateFile": "/var/lib/hysteria/acme/certificates/acme-v02.api.letsencrypt.org-directory/forest.chickenkiller.com/forest.chickenkiller.com.crt",
>                      "keyFile": "/var/lib/hysteria/acme/certificates/acme-v02.api.letsencrypt.org-directory/forest.chickenkiller.com/forest.chickenkiller.com.key",
>                      "serverName": "forest.chickenkiller.com"
(base) bb@dell7820:~/homelab/VPN/VLESS-over-Hysteria2$
```

Legend:

```
"addr": - is a customization for this repo to make helper scripts work. Use `your FQDN`
"id": - use `xray uuid` to generate one for your user.
"name": - FQDN you plan to use for VLESS.
"dest": - destination to your fallback/masquerade page (set it to 127.0.0.1:80 if your page is on localhost or just remove and keep only { "dest": 80 }, where it defaults)
"certificateFile": - path to your certificate created by hysteria.
"keyFile":  - path to your private key created by hysteria.
"serverName": - `your FQDN`, where the certificate/key belongs.
```

Config file location:

```
/usr/local/etc/xray/config.json
```

### Restart XRAY

```
systemctl restart xray; sleep 1; systemctl status --no-pager xray
```

#### Check XRAY ports

```
ss -tulp|grep -i xray
```

```
root@us24-04-vless:~/xray# ss -tulp|grep -i xray
tcp   LISTEN 0      4096                 *:9999              *:*    users:(("xray",pid=3224,fd=6))
tcp   LISTEN 0      4096                 *:https             *:*    users:(("xray",pid=3224,fd=7))
root@us24-04-vless:~/xray#
```


## Helper scripts

### Install prereq packages

```
apt install -y qrencode jq
```

### Script list

```
xray_add_user.sh - to add user.
xray_list_users.sh - to list users.
xray_rm_user.sh - to remove the user.
xray_uri_user.sh - to print the user's connection URI and QR code.
```


