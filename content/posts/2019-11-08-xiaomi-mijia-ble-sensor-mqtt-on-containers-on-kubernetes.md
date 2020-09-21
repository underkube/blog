---
title: "Xiaomi Mijia Ble Sensor MQTT on containers on Kubernetes"
date: 2019-11-08T13:26:20+01:00
draft: false
---

## Intro

As I mentioned in my [previous post](https://www.underkube.com/posts/xiaomi-mijia-ble-sensor-mqtt-on-containers/), everything was working flawlessly... except for a bluetooth issue in my raspberry pi 3 that basically renders bluetooth unusuable... but it is rebooted daily via a cron job, so minor issue :) (I know I know, I'm planning to do a better workaround...)

This was good enough, but a few days ago I decided to give [k3sup](https://github.com/alexellis/k3sup) a chance and install [k3s](https://k3s.io/) (a lightweight Kubernetes distribution focused on ARM/IoT devices) in a spare [pine64](https://www.pine64.org/devices/single-board-computers/pine-a64/) that was gathering dust in a drawer :)

## Entering k3s

The process was really straightforward, download the `k3sup` binary and run it against an already installed raspbian/armbian. Then I decided to add the raspberry pi 3 as a node as well. Again, straightforward procedure, `k3sup join` and that's it, I have a `k3s` cluster:


```shell
NAME            STATUS   ROLES    AGE   VERSION
pi3.minwi.lan   Ready    worker   47h   v1.15.4-k3s.1
pine64          Ready    master   2d    v1.15.4-k3s.1
```

> NOTE: Not so straightforward... there is an issue in k3s if using `iptables > 1.8` so I've created a PR to document the issue in [k3sup](https://github.com/alexellis/k3sup/pull/92)

So... what to do next? The answer was to move the cron docker run to a proper [Kubernetes CronJob](https://kubernetes.io/docs/tasks/job/automated-tasks-with-cron-jobs/)... but first, let me introduce multi architecture builds.

## Multi Architecture builds

This fancy term basically means that when you pull a image from a container registry, it is smart enough to pull the proper image depending on your CPU architecture (x86_64, arm flavors, etc.), so you can just `podman pull myfancyimage:latest` and it just simply works.

In order to enable this for the `xiaomi-ble-mqtt` image, I:

* Created a compatible multi architecture Dockerfile:

```Dockerfile
FROM registry.fedoraproject.org/fedora:30

VOLUME /config
WORKDIR /usr/src/app

RUN dnf install glib2-devel make gcc python3-pip -y && \
    pip3 install --no-cache-dir mitemp_bt bluepy paho-mqtt && \
    dnf clean all

RUN groupadd -g 9999 appuser && \
    useradd -r -u 9999 -g appuser appuser && \
    chown appuser.appuser /usr/src/app/
USER appuser

COPY . /usr/src/app/

CMD [ "/usr/src/app/run.sh" ]
```

* Built a `xiaomi-ble-mqtt:amd64` image in my laptop and pushed it to dockerhub

```shell
docker build -t docker.io/myuser/xiaomi-ble-mqtt:amd64 -f contrib/Dockerfile .
docker login
docker push docker.io/myuser/xiaomi-ble-mqtt:amd64
```

* Built a `xiaomi-ble-mqtt:armv7` image in my rpi3 and pushed it on dockerhub

```shell
docker build -t docker.io/myuser/xiaomi-ble-mqtt:armv7 -f contrib/Dockerfile .
docker login
docker push docker.io/myuser/xiaomi-ble-mqtt:armv7
```

* Created a `multi-arch-manifest.yaml` file with the following content:

```yaml
image: eminguez/xiaomi-ble-mqtt:latest
manifests:
  - image: eminguez/xiaomi-ble-mqtt:amd64
    platform:
      architecture: amd64
      os: linux
  - image: eminguez/xiaomi-ble-mqtt:armv7
    platform:
      architecture: arm
      os: linux
      variant: v7
```

* Uploaded the manifest with [manifest-tool](https://github.com/estesp/manifest-tool):

```shell
manifest-tool --username youruser --password yourpassword push from-spec contrib/multi-arch-manifest.yaml
```

So, you just now simply `podman pull eminguez/xiaomi-ble-mqtt:latest` and it will get the proper one :)

> NOTE: As you may noticed, I've mixed docker/podman. I did it just because it seems [OCI images pushed to dockerhub don't show up and aren't available](https://github.com/docker/hub-feedback/issues/1871)

I've already created a PR to the [xiaomi-ble-mqtt](https://github.com/algirdasc/xiaomi-ble-mqtt/pull/14) with the changes.

## Back to the CronJob

Once the builds were properly set, I just needed to create a Kubernetes CronJob to run the container every X minutes... with a few limitations:

* Bluetooth device must be used by the container (I've used hostNetwork and scc privileged... pending to improve this)
* The config files are stored in a directory (`/home/edu/xiaomi-ble-mqtt`, pending to move it to a configmap)
* I don't want (and cannot) have two process querying the sensors at the same time (`concurrencyPolicy: Forbid`)
* I can only use the rpi3 to run the container (use `nodeSelector`)

With those limitations, this is the CronJob yaml file:

```yaml
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: xiaomi-ble-mqtt
spec:
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - image: eminguez/xiaomi-ble-mqtt
            imagePullPolicy: Always
            name: xiaomi-ble-mqtt
            securityContext:
              privileged: true
            volumeMounts:
            - mountPath: /config
              name: xiaomi-ble-mqtt-config
          hostNetwork: true
          nodeSelector:
            bluetooth: enabled
          volumes:
          - hostPath:
              path: /home/edu/xiaomi-ble-mqtt/
              type: Directory
            name: xiaomi-ble-mqtt-config
  schedule: '*/5 * * * *'
```

I've labeled the raspberry pi 3 with the 'bluetooth: enabled' label and created the CronJob:

```shell
kubectl label node/pi3.minwi.lan "bluetooth=enabled"
kubectl get nodes -o wide --show-labels

NAME            STATUS   ROLES    AGE   VERSION         INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION   CONTAINER-RUNTIME          LABELS
pi3.minwi.lan   Ready    worker   47h   v1.15.4-k3s.1   192.168.3.109   <none>        Raspbian GNU/Linux 10 (buster)   4.19.66-v7+      containerd://1.2.8-k3s.1   beta.kubernetes.io/arch=arm,beta.kubernetes.io/os=linux,bluetooth=enabled,kubernetes.io/arch=arm,kubernetes.io/hostname=pi3.minwi.lan,kubernetes.io/os=linux,node-role.kubernetes.io/worker=true
pine64          Ready    master   2d    v1.15.4-k3s.1   192.168.3.104   <none>        Debian GNU/Linux 10 (buster)     5.3.8-sunxi64    containerd://1.2.8-k3s.1   beta.kubernetes.io/arch=arm64,beta.kubernetes.io/os=linux,kubernetes.io/arch=arm64,kubernetes.io/hostname=pine64,kubernetes.io/os=linux,node-role.kubernetes.io/master=true

kubectl apply -f cronjob.yaml
```

## Results

```shell
kubectl get po
NAME                               READY   STATUS      RESTARTS   AGE
xiaomi-ble-mqtt-1573216800-6frsr   0/1     Completed   0          14m
xiaomi-ble-mqtt-1573217100-nff4l   0/1     Completed   0          9m5s
xiaomi-ble-mqtt-1573217400-v8n9n   0/1     Completed   0          4m3s

kubectl logs xiaomi-ble-mqtt-1573217400-v8n9n
2019-11-08 12:50:45.286570 habitacion  :  {"temperature": 17.7, "humidity": 49.9, "battery": 84}
```

w00h00!