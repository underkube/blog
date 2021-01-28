---
title: "Nextcloud with podman rootless containers and user systemd services. Part I - Introduction"
date: 2021-01-28T8:30:00+00:00
draft: false
tags: ["nextcloud", "podman", "rootless", "systemd"]
---

## Introduction

I've been using [Nextcloud](https://nextcloud.com/) for a few years as my
personal 'file storage cloud'. There are official [container images](https://github.com/nextcloud/docker)
and docker-compose files to be able to run it easily.

For quite a while, I've been using the [nginx+redis+mariadb+cron docker-compose](https://github.com/nextcloud/docker/blob/master/.examples/docker-compose/with-nginx-proxy/mariadb-cron-redis/fpm/docker-compose.yml) 
file as it has all the components to be able to run an 'enterprise ready'
Nextcloud, even if I'm only using it for personal use :)

In this blog post I'm going to try to explain how do I moved from that
docker-compose setup to a podman rootless and systemd one.

### Old setup

The hardware where this has been running is a good old [HP N54L](https://h20195.www2.hpe.com/v2/default.aspx?cc=ca&lc=en&oid=6280786)
that it's been serving me since quite a while, powered by CentOS 7, docker...
and [ZFS](https://zfsonlinux.org/)!

Why ZFS? Well... there are a lot of posts out there explaining why ZFS, but the 
ability to perform automated & zero cost snapshots with
[zfs-auto-snapshot](https://github.com/zfsonlinux/zfs-auto-snapshot) was key.
On a side note, check [systemd-zpool-scrub](https://github.com/lnicola/systemd-zpool-scrub)
to automate your ZFS integrity checks (and my
[humble](https://github.com/lnicola/systemd-zpool-scrub/pull/3/files)
contribution)

The docker-compose file looks like this:

```yaml
version: '3'

services:
  db:
    image: mariadb
    command: --transaction-isolation=READ-COMMITTED --binlog-format=ROW
    restart: always
    volumes:
      - /tank/nextcloud-db/db:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD="xxx"
    env_file:
      - db.env

  redis:
    image: redis:alpine
    restart: always

  app:  
    image: nextcloud:fpm-alpine
    restart: always
    volumes:
      - /tank/nextcloud/html:/var/www/html
    environment:
      - MYSQL_HOST=db
      - REDIS_HOST=redis
    env_file:
      - db.env
    depends_on:
      - db
      - redis

  web:
    build: ./web
    restart: always
    volumes:
      - /tank/nextcloud/html:/var/www/html:ro
    environment:
      - VIRTUAL_HOST=xxx.xxx.com
      - LETSENCRYPT_HOST=xxx.xxx.com
      - LETSENCRYPT_EMAIL=xxx@xxx.com
    depends_on:
      - app
    networks:
      - proxy-tier
      - default

  cron:
    image: nextcloud:fpm-alpine
    restart: always
    volumes:
      - /tank/nextcloud/html:/var/www/html
    entrypoint: /cron.sh
    depends_on:
      - db
      - redis

  proxy:
    build: ./proxy
    restart: always
    security_opt:
      - label:disable
    ports:
      - 80:80
      - 443:443
    labels:
      com.github.jrcs.letsencrypt_nginx_proxy_companion.nginx_proxy: "true"
    volumes:
      - /tank/nextcloud/certs:/etc/nginx/certs:ro
      - /tank/nextcloud/vhost.d:/etc/nginx/vhost.d
      - /tank/nextcloud/html:/usr/share/nginx/html
      - /var/run/docker.sock:/tmp/docker.sock:ro
    networks:
      - proxy-tier

  letsencrypt-companion:
    image: jrcs/letsencrypt-nginx-proxy-companion
    restart: always
    security_opt:
      - label:disable
    volumes:
      - /tank/nextcloud/certs:/etc/nginx/certs
      - /tank/nextcloud/vhost.d:/etc/nginx/vhost.d
      - /tank/nextcloud/html:/usr/share/nginx/html
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - proxy-tier
    depends_on:
      - proxy

networks:
  proxy-tier:
```

The customizations to allow bigger uploads and the custom nginx settings can
be found [in the official Nextcloud repository](https://github.com/nextcloud/docker/tree/master/.examples/docker-compose/with-nginx-proxy/mariadb-cron-redis/fpm) as well

This was very handy for a few reasons:

* It is the 'official' way to run Nextcloud properly using containers
* It uses the [letsencrypt-nginx-proxy-companion](https://github.com/nginx-proxy/docker-letsencrypt-nginx-proxy-companion)
to provide TLS certificates without a sweat
* It works!

### Moving to CentOS 8

For quite a while, I've been struggling to move all the services I'm using at
home to a new box... because they just work!

The new box is a [Slimbook One](https://slimbook.es/one) with better specs
besides storage... so I've repurposed the old N54L to be a file storage server
only (still CentOS7 with ZFS but I'm planning to reinstall it with FreeBSD...
let's see when that happens :D)

The Slimbook One was purchased thanks to a [200 euros discount](https://slimbook.es/desarrolladores)
[I earned](https://mobile.twitter.com/minWi/status/1267440697168343042)
thanks to my contributions to open source projects... even if those are very
small... so I encourage you to be an active contributor, every small change
counts!

I decided to install CentOS 8 as a natural evolution and because I'm biased :)
The only minor detail is that CentOS 8 doesn't include moby or docker-compose
out of the box... and I'm familiar with podman... so I thought to give it a try.

### Moving to CentOS Stream

There has been a LOT of noise with regards the Red Hat [announcement to shift
from CentOS Linux to CentOS Stream](https://www.redhat.com/en/blog/centos-stream-building-innovative-future-enterprise-linux)
but I took this as an opportunity to learn more about how CentOS Stream works
and to be ahead of RHEL.

In any case, moving to CentOS Stream was as simple as:

```bash
sudo dnf install centos-release-stream
sudo dnf swap centos-{linux,stream}-repos
sudo dnf distro-sync
```

Profit!

### Podman in CentOS Stream

This took me a while as turns out podman rootless didn't work properly in 
CentOS... so I ended up using the unofficial podman builds from kubic:

```bash
sudo dnf -y module disable container-tools
sudo dnf -y install 'dnf-command(copr)'
sudo dnf -y copr enable rhcontainerbot/container-selinux
sudo curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/CentOS_8_Stream/devel:kubic:libcontainers:stable.repo
sudo dnf -y install podman
sudo dnf -y update
```

### Crun

I decided to use [crun](https://github.com/containers/crun) instead runc as
container runtime because why not?

```bash
sudo dnf install -y crun
cat << EOF > ~/.config/containers/containers.conf
[engine]
runtime="crun"
EOF
```

### Other stuff

My motto for this box is to try to install the minimum amount of stuff directly
and use everything else as containers. I've also installed `libvirt` to be
able to run VMs using my colleague Karim's [kcli](https://github.com/karmab/kcli)

## Next post

In the next post I will try to explain the process of 'installing' Nextcloud as
a pod.