---
title: "Using an external registry with OpenShift 4"
date: 2021-02-11T8:30:00+00:00
draft: false
tags: ["openshift", "registry", "machine-config-operator", "podman"]
---

In this blog post I'm trying to perform the integration of an external registry
with an OpenShift environment.

The external registry can be any container registry, but in this case I've
configured [harbor](https://github.com/goharbor/harbor) to use certificates
(self generated), the 'library' repository in the harbor registry to be private
(aka. require user/pass) and created an 'edu' user account with permissions on
that 'library' repository.

## Harbor installation

Pretty straightforward if following the
[docs](https://goharbor.io/docs/2.1.0/install-config/), but for RHEL7:

* You need to install the `docker-ce` packages (the installer doesn't like the
one included in RHEL7) by following [this](https://docs.docker.com/engine/install/centos/)
and modifying the `baseurls` in the `/etc/yum.repos.d/docker-ce.repo` file 
to use `7` instead `7Server`

```bash
sudo sed -i -e 's/$releasever/7/g' /etc/yum.repos.d/docker-ce.repo
```

* [The installation script doesn't work with RHEL7](https://github.com/goharbor/harbor/issues/9160#issuecomment-533860991)
* And you need to use the [root](https://github.com/goharbor/harbor/issues/9728) user to install it

I've generated a self signed certificate and it works via https.

### Podman testing

I've tested from podman perspective by:

* Login into the registry, pulling an external image in my workstation and pushing it to harbor:

```bash
podman login edu-playground.example.com --cert-dir harbor/ --username edu
podman pull docker.io/openshift/hello-openshift:latest
podman tag 7af3297a3fb4 edu-playground.example.com/library/h-o:latest
podman push --cert-dir harbor/ edu-playground.example.com/library/h-o:latest
podman rmi edu-playground.example.com/library/h-o:latest
podman rmi 7af3297a3fb4
```

Where --cert-dir is the location where my registry certificate is.

* Then run the image:

```bash
podman pull --cert-dir harbor/ edu-playground.example.com/library/h-o:latest
podman run --rm -d -p 8080:8080 -p 8888:8888 --name h-o edu-playground.example.com/library/h-o:latest

curl localhost:8080
Hello OpenShift!

curl localhost:8888
Hello OpenShift!

podman rm -f h-o
```

So this works.

For OpenShift I tried a few things:

## Registry as insecure and library being public

* Edit the image.config.openshift.io/cluster to add the insecureRegistry:

```bash
oc edit image.config.openshift.io/cluster

...
spec:
  registrySources:
    insecureRegistries:
    - edu-playground.example.com
```

After the hosts are rebooted:

```bash
oc new-project external-registry

oc run ho --image=edu-playground.example.com/library/h-o:latest
NAME   READY   STATUS    RESTARTS   AGE
ho     1/1     Running   0          2m46s
```

So that works.

## Using the certificates and library = private

* Create a configmap with the registry certificate in the openshift-config
namespace. The configmap data needs to be the hostname of the registry:

```bash
oc create configmap registry-config --from-file=edu-playground.example.com=edu-playground.example.com.crt -n openshift-config

oc get configmap registry-config -n openshift-config
apiVersion: v1
kind: ConfigMap
metadata:
  name: registry-config
data:
  edu-playground.example.com: |
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
```

* Edit the image/cluster object to add the certificate and remove the registry from the insecureRegistries

```bash
oc edit image.config.openshift.io cluster

spec:
  additionalTrustedCA:
    name: registry-config
```

Without adding any user/password secret to pull the images, it will fail:

```bash
oc run ho --image=edu-playground.example.com/library/h-o:latest

oc get po
NAME   READY   STATUS         RESTARTS   AGE
ho     0/1     ErrImagePull   0          4s

oc get events
LAST SEEN   TYPE      REASON           OBJECT   MESSAGE
...
15s         Warning   Failed           pod/ho   Failed to pull image "edu-playground.example.com/library/h-o:latest": rpc error: code = Unknown desc = Error reading manifest latest in edu-playground.example.com/library/h-o: unauthorized: unauthorized to access repository: library/h-o, action: pull: unauthorized to access repository: library/h-o, action: pull
15s         Warning   Failed           pod/ho   Error: ErrImagePull
4s          Normal    BackOff          pod/ho   Back-off pulling image "edu-playground.example.com/library/h-o:latest"
4s          Warning   Failed           pod/ho   Error: ImagePullBackOff
```

* You need to create a pull secret on each namespace you want to pull images from that external registry:

```bash
oc delete po/ho
oc create secret docker-registry -n external-registry edu-playground --docker-server=edu-playground.example.com --docker-username=edu --docker-password="xxx" --docker-email=edu@redhat.com
oc secrets link default edu-playground --for=pull -n external-registry
oc get secrets -n external-registry edu-playground

NAME             TYPE                             DATA   AGE
edu-playground   kubernetes.io/dockerconfigjson   1      99s
```

Now run the image:

```bash
oc run ho --image=edu-playground.example.com/library/h-o:latest

oc get po
NAME   READY   STATUS    RESTARTS   AGE
ho     1/1     Running   0          8s

oc get events
LAST SEEN   TYPE      REASON           OBJECT   MESSAGE
...
6s          Normal    Pulling          pod/ho   Pulling image "edu-playground.example.com/library/h-o:latest"
6s          Normal    Pulled           pod/ho   Successfully pulled image "edu-playground.example.com/library/h-o:latest" in 108.257025ms
6s          Normal    Created          pod/ho   Created container ho
6s          Normal    Started          pod/ho   Started container ho
```

To avoid adding the user/password secret on each namespace, we can modify the global pull-secret...

```bash
oc delete project external-registry
oc get secret/pull-secret -n openshift-config -o jsonpath="{.data.\.dockerconfigjson}"  | base64 -d >> pull-secret.json
cp pull-secret.json{,.orig}
```

Now, we need to edit the pull-secret.json file to include the registry.
First, let's create the encrypted (base64) string,
for example "edu" as user "password" as password:

```bash
echo -n "edu:password" |base64
ZWR1OnBhc3N3b3Jk
```

Then, the pull-secret.json file should look like:

```json
{
  "auths": {
    "quay.io": {
      "auth": "xxx",
      "email": "eminguez@xxx.com"
    },
    "registry.connect.redhat.com": {
      "auth": "xxx",
      "email": "eminguez@xxx.com"
    },
    "registry.redhat.io": {
      "auth": "xxx",
      "email": "eminguez@xxx.com"
    },
    "edu-playground.example.com": {
      "auth": "ZWR1OnBhc3N3b3Jk",
      "email": "edu@xxx.com"
    }
  }
}
```

And then, modify the global pull-secret:

```bash
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=pull-secret.json
```

This will trigger a reboot in all the hosts. Then:

```bash
oc new-project ext-reg
oc run ho --image=edu-playground.example.com/library/h-o:latest

oc get po
NAME   READY   STATUS    RESTARTS   AGE
ho     1/1     Running   0          5s

oc get events
LAST SEEN   TYPE     REASON           OBJECT   MESSAGE
9s          Normal   Scheduled        pod/ho   Successfully assigned ext-reg/ho to kni1-worker-0.example.com
7s          Normal   AddedInterface   pod/ho   Add eth0 [10.131.0.83/23]
6s          Normal   Pulling          pod/ho   Pulling image "edu-playground.example.com/library/h-o:latest"
6s          Normal   Pulled           pod/ho   Successfully pulled image "edu-playground.example.com/library/h-o:latest" in 94.080248ms
6s          Normal   Created          pod/ho   Created container ho
6s          Normal   Started          pod/ho   Started container ho
```

Profit!