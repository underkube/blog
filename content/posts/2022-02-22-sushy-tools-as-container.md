---
title: "Using sushy-tools in a container to simulate RedFish BMC"
date: 2022-02-21T8:30:00+00:00
draft: false
tags: ["container", "sushy-tools"]
description: "Using sushy-tools in a container to simulate RedFish BMC"
---

I wanted to simulate a RedFish BMC to be able to power on/off
libvirt virtualmachines and attach ISOs as I do for baremetal hosts.

## Entering sushy-tools

[sushy-tools](https://docs.openstack.org/sushy-tools/latest/user/dynamic-emulator.html)
include a RedFish BMC emulator as `sushy-emulator`
(see the code in the [official repo](https://opendev.org/openstack/sushy-tools)).

Basically it can connect to the libvirt socket to perform the required
actions exposing a RedFish API.

## metal3-io/sushy-tools container image

To easily consume it, the [metal3](https://metal3.io/) folks already have
[a container image](https://github.com/metal3-io/ironic-image/blob/main/resources/sushy-tools/Dockerfile)
ready for consumption at [quay.io/metal3-io/sushy-tools:latest](quay.io/metal3-io/sushy-tools:latest)

## sushy-emulator flags and configuration

There are a bunch of flags already available in the `sushy-emualtor` app. Some of them
can also be specified as environment variables for example:

```
--config CONFIG       Config file path. Can also be set via environment variable SUSHY_EMULATOR_CONFIG
```

We will leverage this one later but in the meantime, we can create a custom
configuration file for the ones we want as:

```
mkdir -p ~/sushy-tools/
cat << EOF > ~/sushy-tools/sushy-emulator.conf
SUSHY_EMULATOR_LISTEN_IP = u'0.0.0.0'
SUSHY_EMULATOR_LISTEN_PORT = 8000
SUSHY_EMULATOR_SSL_CERT = None
SUSHY_EMULATOR_SSL_KEY = None
SUSHY_EMULATOR_OS_CLOUD = None
SUSHY_EMULATOR_LIBVIRT_URI = u'qemu:///system'
SUSHY_EMULATOR_IGNORE_BOOT_DEVICE = True
SUSHY_EMULATOR_BOOT_LOADER_MAP = {
    u'UEFI': {
        u'x86_64': u'/usr/share/OVMF/OVMF_CODE.secboot.fd'
    },
    u'Legacy': {
        u'x86_64': None
    }
}
EOF
```

## Running the container

A few things to consider:

* It requires certain privileges to talk with the libvirt socket, so it will be executed with sudo + the privileged flag
* We need to specify the configuration file we created at `podman run` level using environment variables
* We will overwrite the `CMD` in the container because otherwise the configuration is hardcoded to be placed at [`/root/sushy/conf.py`](https://github.com/metal3-io/ironic-image/blob/main/resources/sushy-tools/Dockerfile#L7)

With that said:

```
sudo podman run -d --privileged --rm --name sushy-tools \
  -v ${HOME}/sushy-tools/sushy-emulator.conf:/etc/sushy/sushy-emulator.conf:Z \
  -v /var/run/libvirt:/var/run/libvirt:Z \
  -e SUSHY_EMULATOR_CONFIG=/etc/sushy/sushy-emulator.conf \
  -p 8000:8000 \
  quay.io/metal3-io/sushy-tools:latest sushy-emulator
```

## Check it

Running a simple curl to a RedFish endpoint such as `redfish/v1/Systems` would be enough:

```
$ curl -v localhost:8000/redfish/v1/Systems
*   Trying 127.0.0.1:8000...
* Connected to localhost (127.0.0.1) port 8000 (#0)
> GET /redfish/v1/Systems HTTP/1.1
> Host: localhost:8000
> User-Agent: curl/7.79.1
> Accept: */*
> 
* Mark bundle as not supporting multiuse
* HTTP 1.0, assume close after body
< HTTP/1.0 200 OK
< Content-Type: application/json
< Content-Length: 1129
< Server: Werkzeug/2.0.2 Python/3.9.9
< Date: Tue, 22 Feb 2022 16:05:08 GMT
< 
{
    "@odata.type": "#ComputerSystemCollection.ComputerSystemCollection",
    "Name": "Computer System Collection",
    "Members@odata.count": 5,
    "Members": [
        
            {
                "@odata.id": "/redfish/v1/Systems/b5091ded-5dcd-4218-bf69-0e2263bb0a7c"
            },
        
            {
                "@odata.id": "/redfish/v1/Systems/3a5d0cd3-69da-455c-b0ce-9bbc8fa1467b"
            },
        
            {
                "@odata.id": "/redfish/v1/Systems/dd47aacc-4fcc-4cbd-8ab2-97198007b08e"
            },
        
            {
                "@odata.id": "/redfish/v1/Systems/429ac473-b840-4f35-aa2c-bc33e9065a2c"
            },
        
            {
                "@odata.id": "/redfish/v1/Systems/7d3e4cb0-042c-44c4-b9c0-a60223c25394"
            }
        
    ],
    "@odata.context": "/redfish/v1/$metadata#ComputerSystemCollection.ComputerSystemCollection",
    "@odata.id": "/redfish/v1/Systems",
    "@Redfish.Copyright": "Copyright 2014-2016 Distributed Management Task Force, Inc. (DMTF). For the full DMTF copyright policy, see http://www.dmtf.org/about/policies/copyright."
* Closing connection 0
```

## References

* [Carve up RedFish with Sushy-Tools](http://schmaustech.blogspot.com/2020/02/carve-up-redfish-with-sushy-tools.html)
* [Sushy-Emulator: Redfish for the Virtualization Nation](https://cloudcult.dev/sushy-emulator-redfish-for-the-virtualization-nation/)
