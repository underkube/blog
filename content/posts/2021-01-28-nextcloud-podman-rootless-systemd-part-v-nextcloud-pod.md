---
title: "Nextcloud with podman rootless containers and user systemd services. Part V - Running Nextcloud as a pod with play kube"
date: 2021-03-09T8:30:00+00:00
draft: false
tags: ["nextcloud", "podman", "rootless", "systemd", "pod"]
---

## podman play kube

One of the cool things about podman is that is not just a `docker` replacement,
it can do so much more!

The feature I'm talking about is being able to run Kubernetes YAML pod
definitions! How cool is that?

You can read more about this feature in the [https://github.com/containers/podman/blob/master/docs/source/markdown/podman-play-kube.1.md](podman-play-kube) man, but essentially, you just need a proper pod yaml
definition and `podman play kube /path/to/my/pod.yaml` will run it for you.

You can even specify a path to a `ConfigMap` yaml file that contains
environmental variables so you can split the config and runtime settings. COOL!

## podman generate kube

To create a Kubernetes YAML pod definition based on a container or a pod, you
can use `podman generate kube` and it will generate it for you, there is no need
to deal with the complex YAML syntax. See the manual page for 
[https://github.com/containers/podman/blob/master/docs/source/markdown/podman-generate-kube.1.md](podman-generate-kube)
to learn more about it.

In my case, this is how it looks like:

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: nextcloud
  name: nextcloud
spec:
  containers:
  - name: db
    args:
    - --transaction-isolation=READ-COMMITTED
    - --binlog-format=ROW
    command:
    - docker-entrypoint.sh
    env:
    - name: MYSQL_ROOT_PASSWORD
      value: xxx
    - name: MYSQL_DATABASE
      value: nextcloud
    - name: MYSQL_USER
      value: nextcloud
    - name: MYSQL_PASSWORD
      value: xxx
    image: docker.io/library/mariadb:latest
    securityContext:
      allowPrivilegeEscalation: true
      capabilities:
        drop:
        - CAP_MKNOD
        - CAP_NET_RAW
        - CAP_AUDIT_WRITE
      privileged: false
      readOnlyRootFilesystem: false
      seLinuxOptions: {}
    volumeMounts:
    - mountPath: /var/lib/mysql
      name: home-edu-containers-nextcloud-data-db
    workingDir: /
  - name: app
    command:
    - php-fpm
    env:
    - name: REDIS_HOST_PASSWORD
      value: xxx
    - name: MYSQL_HOST
      value: 127.0.0.1
    - name: MYSQL_DATABASE
      value: nextcloud
    - name: REDIS_HOST
      value: 127.0.0.1
    - name: MYSQL_USER
      value: nextcloud
    - name: MYSQL_PASSWORD
      value: xxx
    image: quay.io/eminguez/nextcloud-container-fix-nfs:latest
    resources: {}
    ports:
    - containerPort: 80
      hostPort: 8080
      protocol: TCP
    securityContext:
      allowPrivilegeEscalation: true
      capabilities:
        drop:
        - CAP_MKNOD
        - CAP_NET_RAW
        - CAP_AUDIT_WRITE
      privileged: false
      readOnlyRootFilesystem: false
      seLinuxOptions: {}
    volumeMounts:
    - mountPath: /var/www/html
      name: home-edu-containers-nextcloud-data-html
    workingDir: /var/www/html
  - name: redis
    command:
    - redis-server
    - --requirepass
    - xxx
    image: docker.io/library/redis:alpine
    resources: {}
    securityContext:
      allowPrivilegeEscalation: true
      capabilities:
        drop:
        - CAP_MKNOD
        - CAP_NET_RAW
        - CAP_AUDIT_WRITE
      privileged: false
      readOnlyRootFilesystem: true
      seLinuxOptions: {}
    volumeMounts:
    - mountPath: /tmp
      name: tmpfs
    - mountPath: /var/tmp
      name: tmpfs
    - mountPath: /run
      name: tmpfs
    workingDir: /data
  - name: cron
    image: quay.io/eminguez/nextcloud-container-fix-nfs:latest
    command: ["/cron.sh"]
    resources: {}
    securityContext:
      allowPrivilegeEscalation: true
      capabilities:
        drop:
        - CAP_MKNOD
        - CAP_NET_RAW
        - CAP_AUDIT_WRITE
      privileged: false
      readOnlyRootFilesystem: false
      seLinuxOptions: {}
    volumeMounts:
    - mountPath: /var/www/html
      name: home-edu-containers-nextcloud-data-html
    workingDir: /var/www/html
  - name: nginx
    command:
    - nginx
    - -g
    - daemon off;
    image: docker.io/library/nginx:alpine
    resources: {}
    securityContext:
      allowPrivilegeEscalation: true
      capabilities:
        drop:
        - CAP_MKNOD
        - CAP_NET_RAW
        - CAP_AUDIT_WRITE
      privileged: false
      readOnlyRootFilesystem: false
      seLinuxOptions: {}
    volumeMounts:
    - mountPath: /var/www/html
      name: home-edu-containers-nextcloud-data-html
    - mountPath: /etc/nginx/nginx.conf
      name: home-edu-containers-nextcloud-data-nginx-nginx.conf
      readOnly: true
    workingDir: /
  restartPolicy: Always
  volumes:
  - hostPath:
      path: /home/edu/containers/nextcloud/data/nginx/nginx.conf
      type: File
    name: home-edu-containers-nextcloud-data-nginx-nginx.conf
  - hostPath:
      path: /home/edu/containers/nextcloud/data/db
      type: Directory
    name: home-edu-containers-nextcloud-data-db
  - hostPath:
      path: /home/edu/containers/nextcloud/data/html
      type: Directory
    name: home-edu-containers-nextcloud-data-html
  - hostPath:
      path: tmpfs
      type: DirectoryOrCreate
    name: tmpfs
```

Notice that I didn't tweaked the file and it contains parameters such as
`allowPrivilegeEscalation` and some `capabilities` that probably can be
improved.

## systemd unit

Once the yaml file has been created, the systemd unit file is as simple as:

```ini
[Unit]
Description=Podman pod-nextcloud.service

[Service]
Restart=on-failure
RestartSec=30
Type=simple
RemainAfterExit=yes
TimeoutStartSec=30

ExecStartPre=/usr/bin/podman pod rm -f -i nextcloud
ExecStart=/usr/bin/podman play kube \
  /home/edu/containers/nextcloud/scripts/nextcloud.yaml

ExecStop=/usr/bin/podman pod stop nextcloud
ExecStopPost=/usr/bin/podman pod rm nextcloud

[Install]
WantedBy=default.target
```

Then, enable the service:

```bash
systemctl --user daemon-reload
systemctl --user enable pod-nextcloud.service --now
```

## Updating Nextcloud

The process I do to update Nextcloud is basically:

* Review if there are any changes in the `console.php`, `cron.php` or
`entrypoint.sh` files, and if so, fix them and build a new
https://quay.io/repository/eminguez/nextcloud-container-fix-nfs image
* Review if there are any changes in the `nginx.conf`, and if so, update the
`~/containers/nextcloud/nginx/nginx.conf` file

Then, I run the following script:

```bash
#!/bin/bash
export DIR="/home/edu/containers/nextcloud/"

systemctl --user stop pod-nextcloud
# Just to make sure
podman pod stop nextcloud
podman rm $(podman ps -a | awk '/nextcloud/ { print $1 }')
podman pod rm nextcloud

for image in docker.io/library/mariadb:latest docker.io/library/redis:alpine docker.io/library/nginx:alpine k8s.gcr.io/pause:3.2 quay.io/eminguez/nextcloud-container-fix-nfs:latest; do
  podman rmi ${image}
  podman pull ${image}
done
systemctl --user start pod-nextcloud
```

## Final words

During those blog posts I've tried to explain how I managed to setup my
Nextcloud deployment at home using podman rootless containers. If you have read
those post till the end, I hope you enjoyed it and thank you so much to dedicate
a few minutes to read them.

If you have any question or improvement, you can reach me at
[@minWi](https://twitter.com/minWi)

Thanks!!!
