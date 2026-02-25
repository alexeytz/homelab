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

############################

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
