chmod 777 /var/log/xray
root@us-24-04-vless:~# ls -l/var/log/xray
ls: invalid option -- '/'
Try 'ls --help' for more information.
root@us-24-04-vless:~# ls -l /var/log/xray
total 0
-rw------- 1 nobody nogroup 0 Feb 24 22:10 access.log
-rw------- 1 nobody nogroup 0 Feb 24 22:10 error.log
root@us-24-04-vless:~# rm -f /var/log/xray/*



root@us-24-04-vless:~# vi /etc/systemd/system/xray.service
root@us-24-04-vless:~#
root@us-24-04-vless:~# systemctl restart xray
Warning: The unit file, source configuration file or drop-ins of xray.service changed on disk. Run 'systemctl daemon-reload' to reload units.
root@us-24-04-vless:~# systemctl daemon-reload
root@us-24-04-vless:~# systemctl restart xray
