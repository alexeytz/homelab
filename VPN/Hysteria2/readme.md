# Hysteria2 with Obfuscation

The entire installation routine runs as the root user.

You must have your host ports 80/443 exposed to the internet, enable NAT/Firewall Port Forwarding and/or rules as required

You might want to take some time to explore the full server configuration details at https://v2.hysteria.network/docs/advanced/Full-Server-Config/.

This setup has been tested and successfully worked on Ubuntu 24.04.

## Install Hysteria2

https://v2.hysteria.network/docs/getting-started/Installation/#deployment-script-for-linux-servers

```
bash <(curl -fsSL https://get.hy2.sh/)
```

## Install a "masquerade" page

Run the below from the Hysteria2 folder of this GitHub repo.

```
sudo -u hysteria mkdir /var/lib/hysteria/www && \
cp ./webpage/index.html /var/lib/hysteria/www/ && \
chown hysteria:hysteria /var/lib/hysteria/www/* && \
ls -l /var/lib/hysteria/www/ || echo -e "\n\n\n . . . ERROR: Something went wrong . . ."

```

## Obtain geosite.dat

Check https://v2.hysteria.network/docs/advanced/Full-Server-Config/?h=geosite.#acl, first NOTE.

The below one is for RUNET:

```
wget -O /var/lib/hysteria/geosite.dat https://github.com/runetfreedom/russia-v2ray-rules-dat/releases/latest/download/geosite.dat >/dev/null 2>&1
```

## Create config.json

Take a copy of config-template.json and adjust it as per your needs.

Place it into /etc/hysteria/config.json

There are copies of the working/tested config-example and the one used for YouTube. It is straightforward.

```
(base) bb@dell7820:~/homelab/VPN/Hysteria2$ diff config-template.json config-example.json
3c3
<       "addr": "yourdomain2.com"
---
>       "addr": "hy2test2.chickenkiller.com"
9,10c9,10
<          "forest.chickenkiller.com",
<          "yourdomain2.com"
---
>          "hy2test1.chickenkiller.com",
>          "hy2test2.chickenkiller.com"
12c12
<       "email": "your_email@foracme-notifications.com"
---
>       "email": "blah@mail.com"
17c17
<          "password": "REPLACE-PASSWORD"
---
>          "password": "6cc4d27c9bc9a99bba092394e9f95436"
23c23
<          "pioneer": "REPLACE-UUID"
---
>          "pioneer": "c57382e7e6ffb8a2dc4b0489e17d3456561c77618c58f783eaee7e895cb16bf0"
85c85
<       "listenHTTPS": ":8443",
---
>       "listenHTTPS": ":4443",
(base) bb@dell7820:~/homelab/VPN/Hysteria2$
```

Legend:

```
"addr": - is a customization for this repo to make helper scripts work. Use `your FQDN`
"forest.chickenkiller.com", "yourdomain2.com" - FQDNs for your setup.
"email": - an email you'd like to get notifications from acme about your certificates.
"pioneer": - a first user, replace with a new UUID.
"listenHTTPS": - port where hysteria2 listens for https trafic. use 443 is you do not plan to run XRAY+VLESS on top of the hysteria.
```

## Adjust Hysteria service file to use JSON

```
cp /etc/systemd/system/hysteria-server.service ~/hysteria-server.service && \
sed -i 's|ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/config.*|ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/config.json|' ~/hysteria-server.service
cp ~/hysteria-server.service /etc/systemd/system/hysteria-server.service
```

## Enable and start the service

```
systemctl daemon-reload && \
systemctl enable hysteria-server && \
systemctl start hysteria-server && \
sleep 1 && \
systemctl status --no-pager hysteria-server
```

## Check log files to confirm everything is fine.

https://v2.hysteria.network/docs/getting-started/Server-Installation-Script/?h=log#logs

```
journalctl --no-pager -e -u hysteria-server.service
```

## Hysteria2 maintains its certificates in

```
ls -l /var/lib/hysteria/acme/
```

According to my findings, it will renew certificates upon renewal.

## Time to check your webpage

I hope it works. :)

## Helper scripts

### Install prereq packages

```
apt install -y qrencode jq
```

### Script list

```
hy2_add_user.sh - to add user.
hy2_list_users.sh - to list users.
hy2_rm_user.sh - to remove the user.
hy2_uri_user.sh - to print the user's connection URI and QR code.
```
