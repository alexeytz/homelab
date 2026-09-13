# Syncthing is an excellent tool for remote sync/backup

[Windows installer](https://syncthing.net/downloads/)

[GitHub](https://github.com/syncthing/syncthing)

[Documentation](https://docs.syncthing.net/)

## Run in podman container

Install podman:

```
apt -y install podman podman-compose
```

Make sure you can pull the image:

```
podman pull lscr.io/linuxserver/syncthing:latest
```

Adjust `podman-compose.yml` as necessary, then compose the `Syncthing`.

```
podman compose -f ./podman-compose.yml up
```

Or with detach option:

```
podman compose -f ./podman-compose.yml up -d
```

Enable podman-restart.

```
systemctl start podman-restart.service
systemctl status podman-restart.service
systemctl enable podman-restart.service
```
