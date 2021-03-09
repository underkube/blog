---
title: "Nextcloud with podman rootless containers and user systemd services. Part IV - Exposing Nextcloud externally"
date: 2021-01-28T8:30:00+00:00
draft: false
tags: ["nextcloud", "podman", "rootless", "systemd", "bunkerized-nginx"]
---

## Introducing bunkerized-nginx

I heard about 
[bunkerized-nginx](https://github.com/bunkerity/bunkerized-nginx) a while ago
and I thought it would be nice to use it as a reverse proxy so I can expose my
internal services to the internet 'safely'.

A non-exhaustive list of features (copy & paste from the README):

* HTTPS support with transparent Let's Encrypt automation
* State-of-the-art web security : HTTP security headers, prevent leaks, TLS hardening, ...
* Integrated ModSecurity WAF with the OWASP Core Rule Set
* Automatic ban of strange behaviors with fail2ban
* Antibot challenge through cookie, javascript, captcha or recaptcha v3
* Block TOR, proxies, bad user-agents, countries, ...
* Block known bad IP with DNSBL and CrowdSec
* Prevent bruteforce attacks with rate limiting
* Detect bad files with ClamAV
* Easy to configure with environment variables or web UI
* Automatic configuration with container labels

A must have for me was having support for Let's Encrypt and having an easy way
to configure it. So this was a perfect match to me!

### Firewall ports

As the container is going to be rootless, we need to open a few ports in the
host as root. We will use 8080/tcp and 8443/tcp:

```bash
sudo -s -- sh -c \
  "firewall-cmd -q --add-port=8000/tcp && \
   firewall-cmd -q --add-port=8443/tcp && \
   firewall-cmd -q --add-port=8000/tcp --permanent && \
   firewall-cmd -q --add-port=8443/tcp --permanent"
```

Then, to run the container you just need to bind to those ports as
`-p 8000:8080 -p 8443:8443`

### Directories

To store some files such as the letsencrypt certificates, custom configurations
or a cache with the denylists, a few directories are required:

```bash
mkdir -p ~/containers/bunkerized-nginx/{letsencrypt,cache,server-confs}
```

Those will be used as
`-v ${HOME}/containers/bunkerized-nginx/letsencrypt:/etc/letsencrypt:z -v ${HOME}/containers/bunkerized-nginx/cache:/cache:z -v ${HOME}/containers/bunkerized-nginx/server-confs:/server-confs:ro,z`

### Parameters

There are TONS of parameters supported by bunkerized-nginx. Some parameters can
disable some features, some others enable others, etc. so grab a coffee and 
take a good look at the
[README.md](https://github.com/bunkerity/bunkerized-nginx/blob/master/README.md)
file.

In my case:

```bash
SERVER_NAME=nextcloud.example.com someothersite.example.com
nextcloud.example.com_REVERSE_PROXY_URL=/
nextcloud.example.com_REVERSE_PROXY_HOST=http://192.168.1.98:8080
nextcloud.example.com_ALLOWED_METHODS=GET|POST|HEAD|PROPFIND|DELETE|PUT|MKCOL|MOVE|COPY|PROPPATCH|REPORT
someothersite.example.com_REVERSE_PROXY_URL=/
someothersite.example.com_REVERSE_PROXY_HOST=http://192.168.1.98:8001

# Multisite reverse

USE_REVERSE_PROXY=yes
MULTISITE=yes
SERVE_FILES=no
DISABLE_DEFAULT_SERVER=yes
REDIRECT_HTTP_TO_HTTPS=yes
AUTO_LETS_ENCRYPT=yes
USE_PROXY_CACHE=yes
USE_GZIP=yes
USE_BROTLI=yes
PROXY_REAL_IP=yes
PROXY_REAL_IP_HEADER=X-Forwarded-For
PROXY_REAL_IP_RECURSIVE=on
PROXY_REAL_IP_FROM=192.168.0.0/16 172.16.0.0/12 10.0.0.0/8

# Nextcloud specific
X_FRAME_OPTIONS=SAMEORIGIN
MAX_CLIENT_SIZE=10G
```

#### podman --env-file

Reading the [podman man](https://github.com/containers/podman/blob/master/docs/source/markdown/podman-run.1.md#--env-filefile)
I observed there was an `--env-file` parameter. So instead of having tens of
`-e` flags, you can warp them up in a file and use just `--env-file /path/to/my/envfile`

SO NICE!!!

## systemd service

In order to run the container at boot properly, we just need to create a proper
systemd file as a user such as `~/.config/systemd/user/container-bunkerized-nginx.service`:

```ini
[Unit]
Description=Podman container-bunkerized-nginx.service

[Service]
Restart=on-failure
ExecStartPre=/usr/bin/rm -f /%t/%n-pid /%t/%n-cid
ExecStart=/usr/bin/podman run --conmon-pidfile /%t/%n-pid --cidfile /%t/%n-cid \
  -d --restart=always \
  -p 8000:8080 \
  -p 8443:8443 \
  -v /home/edu/containers/bunkerized-nginx/letsencrypt:/etc/letsencrypt:z \
  -v /home/edu/containers/bunkerized-nginx/cache:/cache:z \
  -v /home/edu/containers/bunkerized-nginx/server-confs:/server-confs:ro,z \
  --env-file /home/edu/containers/bunkerized-nginx/scripts/podman.env \
  --name=bunkerized-nginx docker.io/bunkerity/bunkerized-nginx:latest
ExecStop=/usr/bin/podman stop -t 10 bunkerized-nginx
ExecStopPost=/usr/bin/sh -c "/usr/bin/podman rm -f `cat /%t/%n-cid`"
KillMode=none
Type=forking
PIDFile=/%t/%n-pid

[Install]
WantedBy=default.target
```

Notice that I didn't use `podman generate systemd` because it is very specific
to the container ID and I wanted more flexibility. You can read more about
this in this great
[Running containers with Podman and shareable systemd services](https://www.redhat.com/sysadmin/podman-shareable-systemd-services)
blog post.

Then, enable the service:

```bash
systemctl --user daemon-reload
systemctl --user enable container-bunkerized-nginx --now
```

This will enable the service after the first login of the user and killed after
the last session of the user is closed. In order to start it after boot without
requiring the user to be logged, it is required to enable `lingering` as:

```bash
sudo loginctl enable-linger username
```

Note that having the `--env-file` parameter makes running the container much
more convinient, because it is easier to read and you can tweak the parameters
in that file and just restart the service as:

```bash
systemctl --user restart container-bunkerized-nginx
```

Otherwise, you will need to modify the systemd unit file, run the daemon-reload
command and restart the service.

## Exposing it to the internet

As explained in the first post, I'm hosting all this stuff at home so I've
configured my router, running OpenWRT, to expose only the reverse proxy ports
externally (NAT) like so:

```bash
config redirect
  option dest_port '8000'
  option src 'wan'
  option name '80'
  option src_dport '80'
  option target 'DNAT'
  option dest_ip '192.168.1.98'
  option dest 'lan'
  list proto 'tcp'

config redirect
  option dest_port '8443'
  option src 'wan'
  option src_dport '443'
  option target 'DNAT'
  option dest_ip '192.168.1.98'
  option dest 'lan'
  list proto 'tcp'
  option name '443'
```

This means, that the requests incoming from the internet accessing
`http://my-ip` will be redirected to the bunkerized-nginx container listening in
port 8000, and requests accessing `https://my-ip` will be redirected to the
bunkerized-nginx container listening in port 8443... and then, depending on the
`Host` header, they will be redirected to the proper application container.

## Next post

In the next and last post of this series, I will explain how I run the Nextcloud
pod with systemd as a Kubernetes pod and how I update it.

You can read it
[here](https://www.underkube.com/posts/2021-01-28-nextcloud-podman-rootless-systemd-part-v-nextcloud-pod/)