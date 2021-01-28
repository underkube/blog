---
title: "Nextcloud with podman rootless containers and user systemd services. Part I - Nextcloud pod"
date: 2021-01-28T8:30:00+00:00
draft: false
tags: ["nextcloud", "podman", "rootless", "systemd"]
---

## Running a rootless Nextcloud pod

Instead of running Nextcloud as independant containers, I've decided to leverage
one of the multiple podman features which is being able to run multiple
containers as a [pod](https://github.com/containers/podman/blob/master/docs/source/markdown/podman-pod-create.1.md)
(like a kubernetes pod!)

The main benefit to me of doing so is they they use a single network namespace,
meaning all the containers running in the same pod can reach each other using
localhost and you only need to expose the web interface. So for instance the
mysql or redis traffic doesn't leave the pod. Pretty cool huh?

First thing first, I created a folder to host some data, scripts, etc. as:

```bash
export PODNAME="nextcloud"
mkdir -p ~/containers/nextcloud/{db,nginx,html}
```

Where:

* `db` will host the database
* `nginx` contains the custom nginx.conf file
* `html` will host the Nextcloud content

And created an empty pod exposing port 8080/tcp only

```bash
podman pod create --hostname ${PODNAME} --name ${PODNAME} -p 8080:80
```

Next step... start adding containers by running them with the `--pod` flag.

### MariaDB container

```bash
podman run \
  -d --restart=always --pod=${PODNAME} \
  -e MYSQL_ROOT_PASSWORD="myrootpass" \
  -e MYSQL_DATABASE="nextcloud" \
  -e MYSQL_USER="nextcloud" \
  -e MYSQL_PASSWORD="mynextcloudpass" \
  -v ${HOME}/containers/nextcloud/db:/var/lib/mysql:Z \
  --name=${PODNAME}-db docker.io/library/mariadb:latest \
  --transaction-isolation=READ-COMMITTED --binlog-format=ROW
```

As you careful reader has probably observed, I didn't used the `-p` flag to
expose the container to the outside world... because running it in a pod makes
it reachable as localhost 3306/tcp port.

#### Selinux disclaimer

The `:z` and `:Z` flags are important if you use SElinux... because you use
SElinux [right](https://stopdisablingselinux.com/)?

Quoting the `podman-run` [man](https://github.com/containers/podman/blob/master/docs/source/markdown/podman-run.1.md):

> To change a label in the container context, you can add either of two suffixes :z or :Z to the volume mount. These suffixes tell Podman to relabel file objects on the shared volumes. The z option tells Podman that two containers share the volume content. As a result, Podman labels the content with a shared content label. Shared volume labels allow all containers to read/write content. The Z option tells Podman to label the content with a private unshared label.

### Redis

```bash
podman run \
  -d --restart=always --pod=${PODNAME} \
  --name=${PODNAME}-redis docker.io/library/redis:alpine \
  redis-server --requirepass yourpassword
```

It will listen into the 6379/tcp port ONLY within the pod.

### Nextcloud App

```bash
podman run \
  -d --restart=always --pod=${PODNAME} \
  -e REDIS_HOST="localhost" \
  -e REDIS_HOST_PASSWORD="yourpassword" \
  -e MYSQL_HOST="localhost" \
  -e MYSQL_USER="nextcloud" \
  -e MYSQL_PASSWORD="mynextcloudpass" \
  -e MYSQL_DATABASE="nextcloud" \
  -v ${HOME}/containers/nextcloud/html:/var/www/html:z \
  --name=${PODNAME}-app docker.io/library/nextcloud:fpm-alpine
```

It will listen into the 9000/tcp port ONLY within the pod.

### Nextcloud Cron

```bash
podman run \
  -d --restart=always --pod=${PODNAME} \
  -v ${HOME}/containers/nextcloud/html:/var/www/html:z \
  --entrypoint=/cron.sh \
  --name=${PODNAME}-cron docker.io/library/nextcloud:fpm-alpine
```

### Nginx

I've copied the ['official'](https://github.com/nextcloud/docker/blob/master/.examples/docker-compose/with-nginx-proxy/mariadb-cron-redis/fpm/web/nginx.conf) `nginx.conf` to the proper location:

```bash
curl -o ~/containers/nextcloud/nginx/nginx.conf https://raw.githubusercontent.com/nextcloud/docker/master/.examples/docker-compose/with-nginx-proxy/mariadb-cron-redis/fpm/web/nginx.conf 
```

Then to run the container:

```bash
podman run \
  -d --restart=always --pod=${PODNAME} \
  -v ${HOME}/containers/nextcloud/html:/var/www/html:ro,z \
  -v ${HOME}/containers/nextcloud/nginx/nginx.conf:/etc/nginx/nginx.conf:ro,Z \
  --name=${PODNAME}-nginx docker.io/library/nginx:alpine
```

It will listen into the 80/tcp port... and as the pod expose that port as
8080/tcp in the host, you will be able to reach the app!

## Nextcloud installation

Once all the pods are up and running, it is time to tweak the Nextcloud
default deployment to fit our environment:

* Connect to the nextcloud-app container:

```bash
podman exec -it -u www-data nextcloud-app /bin/sh
```

* Perform the installation:

```bash
php occ maintenance:install \
  --database "mysql" \
  --database-host "127.0.0.1" \
  --database-name "nextcloud" \
  --database-user "nextcloud" \
  --database-pass "mynextcloudpass" \
  --admin-pass "password" \
  --data-dir "/var/www/html"
```

* Configure a few settings such as the trusted domains:

```bash
php occ config:system:set \
  trusted_domains 1 --value=192.168.1.98
php occ config:system:set \
  trusted_domains 2 --value=nextcloud.example.com
php occ config:system:set \
  overwrite.cli.url --value "https://nextcloud.example.com"
php occ config:system:set \
  overwriteprotocol --value "https"
```

NextCloud resets the data directory permissions to 770, but nginx requires to
access that folder, otherwise it complains about file not found. I tried to use
`--group-add` flags to force group allocation of the user running both nginx and
nextcloud but they run as root and then they change to a different user
(`www-data` and `nginx`) so the group is not inherited...

```bash
php occ config:system:set \
  check_data_directory_permissions --value="false" --type=boolean
```

The reason behind the directory permissions is [here](https://help.nextcloud.com/t/nextcloud-data-directory-permissions-resetting-to-770/13849). 

```bash
sudo chmod 775 ~/containers/nextcloud/html
podman pod restart nextcloud
```

## Firewall

In order to be able to reach the pod from the outside world, you just need to
open the 8080/tcp port as:

```bash
sudo firewall-cmd --add-port=8080/tcp
sudo firewall-cmd --add-port=8080/tcp --permanent
```

At this point, you have a proper Nextcloud pod running in your box that you can
start using!!!

## Next post

In the next post I will explain how to expose your Nextcloud instance using
[bunkerized-nginx](https://github.com/bunkerity/bunkerized-nginx) and how to
create proper systemd unit files to be able to treat the pods and containers as
services.

Stay tuned!