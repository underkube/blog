---
title: "Howto configure a CentOS 8 Stream host as a network router and provide dhcp and dns services"
date: 2022-02-08T8:30:00+00:00
draft: false
tags: ["centos8", "dnsmasq"]
description: "Howto configure a CentOS 8 Stream host as a network router and provide dhcp and dns services"
---

I wanted to configure a VM to act as a router between two networks, providing DHCP and DNS services as well.

```
         │                 │
         │                 │   ┌──────┐
         │                 │   │      │
         │ ┌────────────┐  ├───┤ vm01 │
         ├─┤ dhcprouter ├──┤   │      │
         │ └────────────┘  │   └──────┘
         │                 │
         │                 │   ┌──────┐
         │                 │   │      │
         │                 ├───┤ vm02 │
         │                 │   │      │
         │                 │   └──────┘
         │                 │
public network       private network
```

* `public network` is the regular libvirt network created by default (192.168.22.0/24)
* `private network` is a bridged network from the hypervisor connected to some other hosts with no internet connectivity (172.22.0.0/24)

The hypervisor also have a IP in that private network (172.22.0.2/24) for debugging purposes.

The steps performed in the `dhcprouter` VM are:

* Rename the connection names because of:

```
nmcli c modify "System eth0" connection.id "eth0"
nmcli c modify "System eth1" connection.id "eth1"
```

* Disable IPv6 as I'm not going to use it and add a static IP to the private network interface:

```
nmcli c modify eth0 ipv6.method "disabled"
nmcli c modify eth1 ipv6.method "disabled"
nmcli c modify eth1 ipv4.method "manual" ipv4.address "172.22.0.1/24"

nmcli c up eth0
nmcli c up eth1
```

* Install firewalld and dnsmasq:

```
dnf install -y firewalld dnsmasq

systemctl enable --now firewalld
```

* Masquerade + open DNS/DHCP ports:

```
export EXT_IF=eth0
export INT_IF=eth1
firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 \
  -o ${EXT_IF} -j MASQUERADE
firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 \
  -i ${INT_IF} -o ${EXT_IF} -j ACCEPT
firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 \
  -i ${EXT_IF} -o ${INT_IF} -m state --state RELATED,ESTABLISHED -j ACCEPT
firewall-cmd --permanent --add-service dhcp --add-service dns
firewall-cmd --permanent --add-masquerade
firewall-cmd --reload
```

* Enable kernel forwarding:

```
cat << EOF > /etc/sysctl.d/99-ipforward
# IP forwarding
net.ipv4.ip_forward = 1
EOF

sysctl -w net.ipv4.ip_forward=1
```

* Configure dnsmasq

```
envsubst <<"EOF" > /etc/dnsmasq.conf
domain-needed
bogus-priv
no-resolv
domain=minwi.com
server=8.8.8.8
server=8.8.4.4
dhcp-range=172.22.0.100,172.22.0.200
interface=${INT_IF}
local=/minwi.com/
expand-hosts
domain=minwi.com
dhcp-authoritative
dhcp-leasefile=/var/lib/dnsmasq/dnsmasq.leases
dhcp-option=option:ntp-server,192.168.0.4,10.10.0.5
EOF

echo "172.22.0.1 dhcprouter.minwi.com" >> /etc/hosts

systemctl enable --now dnsmasq
```

* (Optional) If you want to have `aws` hostname style (`ip-A-B-C-D.domain`), you can use the following dirty script:

```
IPBLOCK=172.22.0.
DOMAIN="minwi.com"
for i in {100..200}; do
  echo "${IPBLOCK}${i} ip-$(echo ${IPBLOCK} | sed 's/\./-/g')${i}.${DOMAIN}" >> /etc/hosts
done
systemctl restart dnsmasq
```

Profit!