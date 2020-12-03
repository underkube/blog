---
title: "Deploy Inspektor Gadget on OCP 4.6.1"
date: 2020-12-03T8:30:00+00:00
draft: false
tags: ["openshift", "inspektor-gadget", "debug", "crc", "capabilities"]
---

## Introduction

[Inspektor Gadget](https://github.com/kinvolk/inspektor-gadget) is a collection
of tools (or gadgets) to debug and inspect Kubernetes applications.

Inspektor Gadget is deployed to each node as a privileged DaemonSet. It uses
in-kernel BPF helper programs to monitor events mainly related to syscalls from
userspace programs in a pod. The BPF programs are run by the kernel and gather
the log data. Inspektor Gadget's userspace utilities fetch the log data from
ring buffers and display it.

The [architecture](https://github.com/kinvolk/inspektor-gadget/blob/master/docs/architecture.md)
explains how it works under the hood, but to me it means to be able to run eBPF
programs easily on Kubernetes.

### Inspektor Gadget in OpenShift

There are a few minor details currently that 'prevents' to run it in OpenShift:

* It needs to be installed in the `kube-system` namespace (it is not recommended
to deploy things there)
* It uses `/run/` to store the `gadgettracermanager` socket (instead its own
directory)

But mainly, it doesn't recognize RHCOS and fails to be deployed.

Fortunately, there is a [fork](https://github.com/clustership/inspektor-gadget)
created by [Philippe Huet](https://github.com/xymox) that circunvent those
issues and works pretty well!

In the meantime, I opened a
[Github issue](https://github.com/kinvolk/inspektor-gadget/issues/145) to notify
the Kinvolk folks about this so in the future it can be deployed without any
forks.

NOTE: Obviously this is totally unsupported.

## OCP Requirements

AFAIK, there is no special requirements to run it, besides being cluster-admin
(well, the workers operating system is a limitation as well but we are using
Philippe's fork that allows it to run it in OCP)

In this post I'll deploy it using [crc](https://developers.redhat.com/products/codeready-containers/overview)
but I've been able to make it work using a baremetal IPI cluster as well.

NOTE: In case you don't know what crc is, check this [blog post](https://developers.redhat.com/blog/2019/09/05/red-hat-openshift-4-on-your-laptop-introducing-red-hat-codeready-containers/)
or the official [documentation](https://access.redhat.com/documentation/en-us/red_hat_codeready_containers/)
, but tl;dr.- it is a stripped version of OpenShift so you can run it in your
_beefy_ laptop (4 vCPUs, 9 GB of free memory & 35 GB of storage space is
required) in Linux/Windows/OSX as it is basically a VM with a preconfigured
single node OCP cluster in.

### Deploy OCP (using `crc`)

A Red Hat account is required to access the user pull secret. You can create a
developer account that will give you access to `crc`, RHEL and some other
goodies in the [developers.redhat.com](https://developers.redhat.com/) site.

* Download [`crc`](https://mirror.openshift.com/pub/openshift-v4/clients/crc/latest/crc-linux-amd64.tar.xz)
* Download the [pull-secret](https://cloud.redhat.com/openshift/install/crc/installer-provisioned) file
* Extract the `crc` binary `tar Jxvf crc-linux-amd64.tar.xz`
* Optionally, copy it to your `$PATH`
* Run `crc setup` and paste the pull-secret content when asked
* Run `crc start` and wait for the VM to be up
* Run `eval $(crc oc-env)` and `export KUBECONFIG=~/.crc/machines/crc/kubeconfig`

You are now cluster-admin of your own OCP cluster running on your laptop, pretty
cool right?

## Deploy Inspektor Gadget

```bash
oc apply -f https://raw.githubusercontent.com/clustership/inspektor-gadget/master/openshift/deployment.yaml
```

NOTE: There is a bug currently where the daemonset can fail with sigsev.
In that case, delete the daemonset and redeploy it again:

```bash
oc delete ds gadget -n gadget-tracing
oc apply -f https://raw.githubusercontent.com/clustership/inspektor-gadget/master/openshift/deployment.yaml
```

### Compile the client

It is required to have make, git and golang already installed. RHEL8:

```bash
sudo dnf install -y make git golang
```

Clone the inspektor-gadget fork repository:

```bash
git clone https://github.com/clustership/inspektor-gadget.git
```

Build the client:

```bash
make kubectl-gadget-linux-amd64
```

Copy the binary to the `/usr/local/bin/` directory so `oc` and `kubectl` can
recognize it as a plugin:

```bash
chmod a+x ./kubectl-gadget-linux-amd64
sudo mv kubectl-gadget-linux-amd64 /usr/local/bin/kubectl-gadget
sudo restorecon /usr/local/bin/kubectl-gadget
```

NOTE: It is required to compile your own cli because it includes fixes to make
it work with OpenShift (basically querying the inspketor-gadget pods running in
the `gadget-tracing` namespace instead of `kube-system`)

## Usage (get capabilities requested by a pod)

Deploy a demo application. Basically [this one](https://raw.githubusercontent.com/kinvolk/inspektor-gadget/master/docs/examples/app-set-priority.yaml) but in the `gadget-tracing` namespace:

```bash
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: set-priority
  namespace: gadget-tracing
  labels:
    k8s-app: set-priority
spec:
  selector:
    matchLabels:
      name: set-priority
  template:
    metadata:
      labels:
        name: set-priority
    spec:
      containers:
      - name: set-priority
        image: busybox
        command: [ "sh", "-c", "while /bin/true ; do nice -n -20 echo ; sleep 5; done" ]
EOF
```

Then, get the pod name and the worker name where the pod is running. In this
case, we will be focused on crc-tnpk6-master-0:

```bash
oc get po -o wide -n gadget-tracing

NAME                            READY   STATUS    RESTARTS   AGE   IP               NODE                 NOMINATED NODE   READINESS GATES
gadget-cf8hx                    1/1     Running   0          18h   192.168.126.11   crc-tnpk6-master-0   <none>           <none>
set-priority-5646554d9d-jcmch   1/1     Running   0          18h   10.116.0.27      crc-tnpk6-master-0   <none>           <none>
```

Run the kubectl-gadget capabilities command as:

```bash
kubectl-gadget capabilities --unique --verbose -p set-priority-5646554d9d-jcmch --node crc-tnpk6-master-0
```

or

```bash
oc gadget capabilities --verbose --unique -p set-priority-5646554d9d-jcmch --node crc-tnpk6-master-0
```

The output looks like:

```
Node numbers: 0 = crc-tnpk6-master-0
Running command: exec /opt/bcck8s/bcc-wrapper.sh --tracerid 20201203092226-55d305646fcd --gadget /usr/share/bcc/tools/capable  --namespace gadget-tracing --podname set-priority-5646554d9d-jcmch  --  --unique -v
NODE TIME      UID    PID    COMM             CAP  NAME                 AUDIT 
[ 0] 08:22:30  1000580000 16178  sh               21   CAP_SYS_ADMIN        0     
[ 0] 08:22:30  1000580000 20501  sh               21   CAP_SYS_ADMIN        0     
[ 0] 08:22:30  1000580000 20501  nice             6    CAP_SETGID           1     
[ 0] 08:22:30  1000580000 20501  nice             7    CAP_SETUID           1     
[ 0] 08:22:30  1000580000 20501  nice             23   CAP_SYS_NICE         1     
[ 0] 08:22:30  1000580000 20500  sh               21   CAP_SYS_ADMIN        0     
[ 0] 08:22:30  1000580000 20500  true             6    CAP_SETGID           1     
[ 0] 08:22:30  1000580000 20500  true             7    CAP_SETUID           1     
[ 0] 08:22:30  1000580000 20502  sh               21   CAP_SYS_ADMIN        0     
[ 0] 08:22:30  1000580000 20502  sleep            6    CAP_SETGID           1     
[ 0] 08:22:30  1000580000 20502  sleep            7    CAP_SETUID           1
^C
Terminating...
Running command: exec /opt/bcck8s/bcc-wrapper.sh --tracerid 20201123115948-c2009dae9253 --stop
```

## References

* https://github.com/clustership/inspektor-gadget/blob/master/openshift/README.md

## Notes

Yes, I've tried to resist the temptation to put an Inspector gadget image in the
post to make it look more professional... but I guess nobody reads it until
completion, so here it is! :D

![Inspector Gadget](https://pixy.org/src/441/thumbs350/4411156.jpg)
