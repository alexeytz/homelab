# How to get VLESS running for VPN and as a reverse proxy.

The assumption is that you have your own domain and certbot supports your provider: https://eff-certbot.readthedocs.io/en/latest/using.html#dns-plugins

The entire configuration was done as root.

This setup has been tested and successfully worked on Ubuntu 24.04.

## Install snap (if not there yet)

```
apt install -y snap
```

## Install certbot

https://certbot.eff.org/instructions?ws=other&os=snap&tab=wildcard

```
snap install --classic certbot
```

Make sure certbot is available:

```
which certbot
```

if not, softlink it:

```
ln -s /snap/bin/certbot /usr/local/bin/certbot
```

Confirm plugin containment level:

```
snap set certbot trust-plugin-with-root=ok
```

Install correct DNS plugin (https://eff-certbot.readthedocs.io/en/latest/using.html#dns-plugins):

```
snap install certbot-dns-cloudflare
```

Follow your plugin steps (https://eff-certbot.readthedocs.io/en/latest/using.html#dns-plugins) to create certificates.

### Create certificate

This example is for Cloudflare (https://certbot-dns-cloudflare.readthedocs.io/en/stable/). Instructions for token creation: https://developers.cloudflare.com/fundamentals/api/get-started/create-token/.

```
echo "dns_cloudflare_api_token = <YOUR API KEY for DNS changes in Cloudflare>" > ~/cloudflare.ini
```
Create certificates (At this time, you must have your host ports 80/443 exposed to the internet, enable NAT/Firewall Port Forwarding rules as required):

```
certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials ~/cloudflare.ini \
  --dns-cloudflare-propagation-seconds 30 \
  -d *.youdomain.xyz
```

E.g.

```
root@us24-04-vless:~# certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials ~/cloudflare.ini \
  --dns-cloudflare-propagation-seconds 30 \
  -d *.t-v.net
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Requesting a certificate for *.t-v.net
Unsafe permissions on credentials configuration file: /root/cloudflare.ini
Waiting 30 seconds for DNS changes to propagate

Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/t-v.net/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/t-v.net/privkey.pem
This certificate expires on 2026-05-23.
These files will be updated when the certificate renews.
Certbot has set up a scheduled task to automatically renew this certificate in the background.

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
If you like Certbot, please consider supporting our work by:
 * Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
 * Donating to EFF:                    https://eff.org/donate-le
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
root@us24-04-vless:~#
```

Note the certificate location.

Certbot scheduled a task for automated certificate renewal:

```
root@us24-04-vless:~# systemctl list-timers|grep certbot
Mon 2026-02-23 07:26:00 UTC      11h Sun 2026-02-22 19:38:25 UTC 22min ago snap.certbot.renew.timer       snap.certbot.renew.service
root@us24-04-vless:~#
root@us24-04-vless:~# systemctl list-timers snap.certbot.renew.timer
NEXT                        LEFT LAST                           PASSED UNIT                     ACTIVATES                 
Mon 2026-02-23 07:26:00 UTC  11h Sun 2026-02-22 19:38:25 UTC 24min ago snap.certbot.renew.timer snap.certbot.renew.service

1 timers listed.
Pass --all to see loaded but inactive timers, too.
root@us24-04-vless:~#
```

It checks the certificate's validity date and updates it only when the validity period ends. To check the log, use:

```
journalctl -u  snap.certbot.renew.timer
```

#### Set certificate permissions, so XRAY would be able to read them.

```
chmod -R o+rx /etc/letsencrypt/*
```

## Install and configure XRAY.

### Make sure "brb" is enabled.

```
sysctl -a | grep net.ipv4.tcp_congestion_control
```

If it is not

```
root@us24-04-vless:~# sysctl -a | grep net.ipv4.tcp_congestion_control
net.ipv4.tcp_congestion_control = cubic
root@us24-04-vless:~#
```

enable it:

```
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
```

E.g.

```
root@us24-04-vless:~# sysctl -a | grep net.ipv4.tcp_congestion_control
net.ipv4.tcp_congestion_control = bbr
root@us24-04-vless:~#
```

### Install XRAY

https://github.com/XTLS/Xray-install

```
bash -c "$(curl -4 -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
```

Confirm it is successfully installed from the output on the screen.

### Configure XRAY

#### Set environment

The assumption is that only one domain is served by the server (i.e., there is only one folder inside /etc/letsencrypt/archive/).

```
mkdir ~/xray && \
echo "export domain=$(ls /etc/letsencrypt/archive/)" >> ~/xray/xray.env && \
echo "export certificate=/etc/letsencrypt/live/$(ls /etc/letsencrypt/archive/)/fullchain.pem" >> ~/xray/xray.env && \
echo "export keyfile=/etc/letsencrypt/live/$(ls /etc/letsencrypt/archive/)/privkey.pem" >> ~/xray/xray.env && \
echo "export proxy_ip=127.0.0.1" >> ~/xray/xray.env && \
echo "export proxy_port=80" >> ~/xray/xray.env || echo -e "\n\n\n. . . ERROR: ~/xray folder already exists . . ."
```
Inspect and adjust ~/xray/xray.env as per your needs, E.g.:

```
root@us24-04-vless:~/xray# cat ~/xray/xray.env 
export domain=tubearchivist.t-v.net
export certificate=/etc/letsencrypt/live/t-v.net/fullchain.pem
export keyfile=/etc/letsencrypt/live/t-v.net/privkey.pem
export proxy_ip=10.69.2.3 # IP where the tubearchivist is running
export proxy_port=8000 # PORT of the tubearchivist
root@us24-04-vless:~/xray#
```


#### Create config.json in ~/xray

```
chmod +x create_config.json.sh && ./create_config.json.sh 
```

Inspect and adjust ~/xray/config.json. 

#### Copy config.json to XRAY config folder

```
cp ~/xray/config.json /usr/local/etc/xray/config.json && \
chmod +r /usr/local/etc/xray/config.json
```

#### Restart XRAY

```
systemctl restart xray; sleep 1; systemctl status xray
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

## Add XRAY restart hook to certbot post renewal

```
certbot reconfigure --cert-name yourdomain.xyz --deploy-hook "chmod -R o+rx /etc/letsencrypt/* && systemctl restart xray"
```