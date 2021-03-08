---
title: "Customizing OpenShift 4 baremetal IPI network at installation time"
date: 2021-03-08T8:30:00+00:00
draft: false
tags: ["openshift", "baremetal", "ipi", "network"]
---

When deploying OpenShift IPI on baremetal, there is only so much you can tweak
at installation time in terms of networking. Of course you can do changes after
the installation, such as applying bonding configurations or vlan settings via
machine configs... but what if you need those changes at installation time?

In my case, I have an OpenShift environment composed by physical servers where
each of them have 4 NICs. 1 unplugged NIC, 1 NIC connected to the provisioning
network and 2 NICs connected to the same switch and to the same baremetal
subnet. This is used to configure a bonding interface composed of those two
NICs, but I wanted to use just a single NIC or switch to bonding without
modifying the switches' configuration... so to me, one NIC is the 'good one'
and it has a dhcp reservation and a DNS hostname already configured.
As RHCOS requests a dhcp address on all NICs, I ended up with two different IPs
for the baremetal subnet. This means that depending on which NIC gets the IP
first (guess which one wins all the time), the hostname is either the proper one
or one assigned via dhcp as well as the primary IP... which turns out bad for
certificates and for kubernetes itself.

Let's start with the basics, disabling `ens3f1` at day 2.

## Day 2

The easiest way [I've found](https://unix.stackexchange.com/a/467085) is
basically creating a `machine-config` to disable the NIC completely, using some
udev magic:

```bash
ACTION=="add", SUBSYSTEM=="net", ENV{INTERFACE}=="ens3f1", RUN+="/bin/sh -c 'echo 1 > /sys$DEVPATH/device/remove'"
```

The avid reader would ask... Why udev instead of just disabling it via
NetworkManager? Because I wanted to test Contrail and the operator requires to
[disable NetworkManager](https://raw.githubusercontent.com/Juniper/contrail-operator/R2011/deploy/openshift/openshift/99_master_network_manager_stop_service.yaml) :)

The `machine-config` will look like:

```yaml
---
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: master
  name: masters-disable-ens3f1
spec:
  config:
    ignition:
      config: {}
      security:
        tls: {}
      timeouts: {}
      version: 2.2.0
    networkd: {}
    passwd: {}
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,QUNUSU9OPT0iYWRkIiwgU1VCU1lTVEVNPT0ibmV0IiwgRU5We0lOVEVSRkFDRX09PSJlbnMzZjEiLCBSVU4rPSIvYmluL3NoIC1jICdlY2hvIDEgPiAvc3lzJERFVlBBVEgvZGV2aWNlL3JlbW92ZSciCg==                                                      
          verification: {}
        filesystem: root
        mode: 420
        path: /etc/udev/rules.d/90-disable-ens3f1.rules
---
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: workers-disable-ens3f1
spec:
  config:
    ignition:
      config: {}
      security:
        tls: {}
      timeouts: {}
      version: 2.2.0
    networkd: {}
    passwd: {}
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,QUNUSU9OPT0iYWRkIiwgU1VCU1lTVEVNPT0ibmV0IiwgRU5We0lOVEVSRkFDRX09PSJlbnMzZjEiLCBSVU4rPSIvYmluL3NoIC1jICdlY2hvIDEgPiAvc3lzJERFVlBBVEgvZGV2aWNlL3JlbW92ZSciCg==                                                      
          verification: {}
        filesystem: root
        mode: 420
        path: /etc/udev/rules.d/90-disable-ens3f1.rules
```

But... what if you need to do this at installation time? Imagine you need to
configure your network settings (like vlan) at installation time in order to
pull all the required assets for the installation to happen...

## Install time

Doing this at installation time is a little bit more complex. There are a few
places where the network configuration is set using IPI on bare metal.

1. At installation time the hosts are booted via the baremetal operator using a
'discovery' iso that performs some hardware inspection and writes the RHCOS base
image in order to perform the OpenShift installation. This is fine and there is
no need to tweak it as it is only a temporary state.

2. The first time RHCOS boots it requests a dhcp address on all network
interfaces in order to be able to get the igntion configuration (served by the
bootstrap VM) to customize itself. This is done via dracut at an early boot
stage.

3. Then, when RHCOS is installed, it is already configured as 'request dhcp on
all interfaces'

The proper way is being worked on. You can read about it in
[this](https://github.com/openshift/enhancements/blob/master/enhancements/machine-config/custom-ignition-machineconfig.md)
OpenShift Enhancement (PS.- to me it is a good exercise to take a look at the
OpenShift Enhancements to understand what is being cooked and all the machinery
under the hood).

In the meantime, we will do a TOTALLY UNSUPPORTED and not recommended procedure.
Basically we will disable RHCOS to request a dhcp address on the aforedmentioned
NIC at boot as well as disable the NIC via a machine config at a later step.

### Disable RHCOS dhcp request

Basically the idea is to override the proper
[dracut parameter](https://man7.org/linux/man-pages/man7/dracut.cmdline.7.html)
that disables dhcp requests on a particular interface. In this case:

```bash
ip=ens3f1:off
```

The RHCOS iso already has a mechansim enabled to override parameters at boot
via [this commit](https://github.com/coreos/ignition/commit/a65ec1667338518a44c75a21ceb955408c3061da).

As the commit mentions, the content of the `/boot/ignition.firstboot` file will
be used as network kcmdline arguments... so we just need to do the modifications
we need there :)

It is important to mention that in order to enable it, we need to carry over
the `rd.neednet=1` parameter to bring up network even without netroot.

Also, we want to request dhcp in all other interfaces, so the line we need looks
like:

```bash
rd.neednet=1 ip=dhcp ip=ens3f1:off
```

That's basically it... BUT as of today, there isn't a mechanism to provide
extra variables like those... so we need to get our hands dirty...

### Modifying the RHCOS image

Again, this is totally UNSUPPORTED so don't blame me if your cluster is on fire
after this modification :)

The baremetal IPI procedure uses the RHCOS OpenStack QCOW2 image (the baremetal
operator uses ironic under the hood), so we will modify it using the awesome
[`guestfish`](http://libguestfs.org/) cli
(`sudo dnf install -y libguestfs-tools-c` if using Fedora).

NOTE: The RHCOS image and in particular the partition schema has changed during
the different OpenShift versions. I've tested this procedure with OpenShift 4.6
but probably won't work on 4.5 or 4.7 if the partitions are different, you need
to figure out by yourself if that's the case :)

```bash
VERSION=4.6
IFACE=ens3f1
mkdir -p ~/html
curl -s -o ~/html/rhcos-openstack.x86_64.qcow2.gz https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/${VERSION}/latest/rhcos-openstack.x86_64.qcow2.gz
gunzip -c ~/html/rhcos-openstack.x86_64.qcow2.gz > ~/html/rhcos-openstack.qcow2

cat << EOF > ~/html/ignition.firstboot
set ignition_network_kcmdline='rd.neednet=1 ip=dhcp ip=${IFACE}:off'
EOF
chmod 600 ~/html/ignition.firstboot

pushd ~/html
guestfish -a rhcos-openstack.qcow2 -m /dev/sda1 copy-in ignition.firstboot /
# Just to check
guestfish -a rhcos-openstack.qcow2 -m /dev/sda1 cat /ignition.firstboot
SHA256=$(sha256sum < rhcos-openstack.qcow2 | awk '{ print $1 }')
gzip -k rhcos-openstack.qcow2
rm -f rhcos-openstack.x86_64.qcow2.gz ignition.firstboot
popd
echo "Append platform.baremetal.clusterOSImage: http://path/to/rhcos-openstack.qcow2.gz?sha256=${SHA256} to your install-config.yaml"
```

Take note at the output as we will need it later, in particular the SHA256 sum
of the uncompressed image.

### Serving the image

The easy part. You just need to serve that image somewhere via http. You can
either install a webserver or run a container or reuse any webserver you already
have (or use just `python3 -m http.server`, totally not recommended)

Also make sure the file is reachable from the hosts that will be part of the
OpenShift cluster and note the URL and note the URL (something like 
`http://imawesome.com:8080/images/rhcos-openstack.qcow2.gz`)

### Modifying the install-config.yaml file

To be able to use that particular image, you need to modify the
`platform.baremetal.clusterOSImage` parameter in the `install-config.yaml` file
as:

```yaml
...
platform:
  baremetal:
    ...
    clusterOSImage: http://imawesome.com:8080/images/rhcos-openstack.qcow2.gz?sha256=f209b731fff0cb5523f17953e69371469c0b2b80f6976cdb77abf59ee6c872ad
```

Where the `?sha256=f20...` parameter is mandatory and it should match the one
from the output of the command you already executed before.

NOTE: As a reminder, the SHA256 sum is for the uncompressed image.

### Disabling the NIC via udev at install time

The OpenShift installation allows you to inject extra manifests at installation
time. So we will take advantage of that feature to disable the NIC via udev at
installation time as well.

With our cooked `install-config.yaml` file in place, we can create the manifests
as:

```bash
cd /path/to/my/install/config/file
openshift-install create manifests
```

Then, we can copy the `masters-disable-ens3f1` and `workers-disable-ens3f1`
machine configs in the `openshift/` folder with a proper name and order like:

```bash
99_masters-disable-ens3f1.yaml
99_workers-disable-ens3f1.yaml
```

Then, just deploy OpenShift as:

```bash
openshift-install create cluster --dir=./ --log-level=debug
```

Profit! :)