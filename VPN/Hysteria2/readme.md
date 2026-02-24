# Hysteria2 in addition to VLESS

The assumption is that you already have VLESS installed (https://github.com/alexeytz/homelab/tree/main/VPN/VLESS), and we'll use some Xray-installed stuff for Hysteria2.

The Hysteria2 is based on UDP and won't affect VLESS. Just make sure you have NAT/Firewall rules configured to allow UDP port 443 on your system.

You might want to take some time to explore the full server configuration details at https://v2.hysteria.network/docs/advanced/Full-Server-Config/.

This setup has been tested and successfully worked on Ubuntu 24.04.

## Set environment

We'll use the VLESS approach and all compatible stuff generated for VLESS.

```
mkdir ~/hy2 && \
echo "export domain=$(ls /etc/letsencrypt/archive/)" >> ~/hy2/hy2.env && \
echo "export certificate=/etc/letsencrypt/live/$(ls /etc/letsencrypt/archive/)/fullchain.pem" >> ~/hy2/hy2.env && \
echo "export keyfile=/etc/letsencrypt/live/$(ls /etc/letsencrypt/archive/)/privkey.pem" >> ~/hy2/hy2.env && \
echo "export bind_device=$(ls /sys/class/net | grep -v lo | head -n 1)" >> ~/hy2/hy2.env && \
echo "export hy2_port=443" >> ~/hy2/hy2.env || echo -e "\n\n\n. . . ERROR: ~/hy2 folder already exists . . ."
```

Inspect and adjust ~/hy2/hy2.env as per your needs, E.g.:

```
root@us24-04-vless:~/hy2# cat ~/hy2/hy2.env 
export domain=tubearchivist.t-v.net
export certificate=/etc/letsencrypt/live/t-v.net/fullchain.pem
export keyfile=/etc/letsencrypt/live/t-v.net/privkey.pem
export bind_device=ens18
export hy2_port=443 # PORT where we'd like Hysteria2 to listen
root@us24-04-vless:~/hy2#
```

## Create config.json in ~/hy2

```
chmod +x create_config.json.sh && ./create_config.json.sh 
```

Inspect and adjust ~/hy2/config.json. 

## Copy config.json to Hysteria2 config folder

```
cp ~/hy2/config.json /etc/hysteria/config.json && \
chmod +r /etc/hysteria/config.json
```

## Adjust Hysteria service file to use JSON

```
cp /etc/systemd/system/hysteria-server.service ~/hy2/hysteria-server.service
sed -i 's|ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/config.*|ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/config.json|' ~/hy2/hysteria-server.service
cp ~/hy2/hysteria-server.service /etc/systemd/system/hysteria-server.service
```

## Enable and start the service

```
systemctl enable hysteria-server && systemctl start hysteria-server && sleep 1 && systemctl status hysteria-server
```


