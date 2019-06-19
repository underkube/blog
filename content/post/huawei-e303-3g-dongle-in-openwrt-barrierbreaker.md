---
date: 2015-03-15T11:54:04Z
draft: false
title: "Huawei E303 3G dongle in OpenWRT BarrierBreaker"
---

This is a not detailed howto about to make Huawei E303 dongle work with OpenWRT BarrierBreaker.
The first step is to follow the [official guide](http://wiki.openwrt.org/doc/recipes/3gdongle) to install all the packages needed, etc.
Then, create the following files to add support for the 3G dongle:

* `/etc/config/usb-mode-3g-e303.json`

```
{
"messages" : [
  "55534243000000000000000000000611060000000000000000000000000000",
],
"devices" : {
  "12d1:14fe": {
  "*": {
  "t_vendor": 4817,
  "t_product": [ 5374 ],
  "msg": [ 0 ]
  }
  },
}
}
```

* `/etc/hotplug.d/usb/22-dongie_hspaplus`

```
DONGIEHSPAPLUS_PRODID="12d114f0"                                          if [ "${PRODUCT}" "${DONGIEHSPAPLUS_PRODID}" ]
then
  if [ "${ACTION}" = "add" ]; then                           
    echo '12d1 14fe ff' > /sys/bus/usb-serial/drivers/optionnew_id
  /sbin/usbmode -s -v -c /etc/config/usb-mode-3g-e303.json
  fi
fi
```

* Fix the `/etc/hotplug.d/usb/20-usb_mode` by adding a `sleep 5` in the first line to get the usb working at boot. Otherwise, you need to re-plug your 3G dongle in order to make it work:

```
sleep 5
/etc/init.d/usbmode start
```

* Modify the `/etc/chatscripts/3g.chat` with the number you need to call. In this particular case, for Movistar Spain, `*99#`:

```
ABORT   BUSY
ABORT   'NO CARRIER'
ABORT   ERROR
REPORT  CONNECT
TIMEOUT 10
""      "AT&F"
OK      "ATE1"
OK      'AT+CGDCONT=1,"IP","$USE_APN"'
SAY     "Calling UMTS/GPRS"
TIMEOUT 30
OK      "ATD*99#"
CONNECT ' '
```

Then, try it. You should see the correct lines in the `dmesg` or
`logread` output, and the correct ones in /sys/kernel/debug/usb/devices (check the [official guide](http://wiki.openwrt.org/doc/recipes/3gdongle))

Now configure your network connection, those are the files I've modified, but your mileage may vary:

* `/etc/config/network.3g`

```
config interface 'loopback'
  option ifname 'lo'
  option proto 'static'
  option ipaddr '127.0.0.1'
  option netmask '255.0.0.0'

config globals 'globals'
  option ula_prefix 'ZZZZZZZ::/48'

config interface wan
  option ifname 'ppp0'
  option proto '3g'
  option service 'umts'
  option device '/dev/ttyUSB0'
  option apn 'movistar.es'
  option pincode 'YOURPIN'
  option username 'movistar'
  option password 'movistar'

config switch
  option name 'rt305x'
  option reset '1'
  option enable_vlan '1'

config switch_vlan
  option device 'rt305x'
  option vlan '1'
  option ports '0 1 2 3  6t'

config switch_vlan
  option device 'rt305x'
  option vlan '2'
  option ports '4  6t'

config 'interface' 'wifi'
  option 'proto'      'static'
  option 'ipaddr'     '192.168.23.1'
  option 'netmask'    '255.255.255.0'
```

* `/etc/config/wireless.3g`

```
config wifi-device  radio0
  option type     mac80211
  option channel  11
  option hwmode	11g
  option path	'10180000.wmac'
  option htmode	HT20

config wifi-iface
  option device   radio0
  option network  wifi
  option mode     ap
  option ssid     yourapname
  option encryption none
```

Obviously, you need to set some encryption.
I'll let you figure this out :)

* `/etc/config/dhcp.3g`

```
config dnsmasq
  option domainneeded '1'
  option boguspriv '1'
  option filterwin2k '0'
  option localise_queries '1'
  option rebind_protection '1'
  option rebind_localhost '1'
  option local '/lan/'
  option domain 'lan'
  option expandhosts '1'
  option nonegcache '0'
  option authoritative '1'
  option readethers '1'
  option leasefile '/tmp/dhcp.leases'
  option resolvfile '/tmp/resolv.conf.auto'
  list server '208.67.220.220'
  list server '208.67.222.222'

config dhcp 'lan'
  option interface 'lan'
  option start '100'
  option limit '150'
  option leasetime '12h'
  option dhcpv6 'server'
  option ra 'server'

config dhcp 'wan'
  option interface 'wan'
  option ignore '1'

config odhcpd 'odhcpd'
  option maindhcp '0'
  option leasefile '/tmp/hosts/odhcpd'
  option leasetrigger '/usr/sbin/odhcpd-update'

config 'dhcp' 'wifi'
  option 'interface'  'wifi'
  option 'start'      '100'
  option 'limit'      '150'
  option 'leasetime'  '12h'
```

* `/etc/config/firewall.3g`

```
config defaults
  option syn_flood  1
  option input		ACCEPT
  option output		ACCEPT
  option forward		REJECT
  option disable_ipv6  1

config zone
  option name		wan
  list   network		'wan'
  list   network		'wan6'
  option input		REJECT
  option output		ACCEPT
  option forward		REJECT
  option masq		1
  option mtu_fix		1

config forwarding
  option src		lan
  option dest		wan

config rule
  option name		Allow-DHCP-Renew
  option src		wan
  option proto		udp
  option dest_port	68
  option target		ACCEPT
  option family		ipv4

config rule
  option name		Allow-Ping
  option src		wan
  option proto		icmp
  option icmp_type	echo-request
  option family		ipv4
  option target		ACCEPT

config rule
  option name		Allow-DHCPv6
  option src		wan
  option proto		udp
  option src_ip		fe80::/10
  option src_port		547
  option dest_ip		fe80::/10
  option dest_port	546
  option family		ipv6
  option target		ACCEPT

config rule
  option name		Allow-ICMPv6-Input
  option src		wan
  option proto	icmp
  list icmp_type		echo-request
  list icmp_type		echo-reply
  list icmp_type		destination-unreachable
  list icmp_type		packet-too-big
  list icmp_type		time-exceeded
  list icmp_type		bad-header
  list icmp_type		unknown-header-type
  list icmp_type		router-solicitation
  list icmp_type		neighbour-solicitation
  list icmp_type		router-advertisement
  list icmp_type		neighbour-advertisement
  option limit		1000/sec
  option family		ipv6
  option target		ACCEPT

config rule
  option name		Allow-ICMPv6-Forward
  option src		wan
  option dest		*
  option proto		icmp
  list icmp_type		echo-request
  list icmp_type		echo-reply
  list icmp_type		destination-unreachable
  list icmp_type		packet-too-big
  list icmp_type		time-exceeded
  list icmp_type		bad-header
  list icmp_type		unknown-header-type
  option limit		1000/sec
  option family		ipv6
  option target		ACCEPT

config include
  option path /etc/firewall.user

config zone
  option name       wifi
  list   network    'wifi'
  option input      ACCEPT
  option output     ACCEPT
  option forward    REJECT

config 'forwarding'
  option 'src'        'wifi'
  option 'dest'       'wan'

config 'forwarding'
  option 'src'        'lan'
  option 'dest'       'wifi'

config 'forwarding'
  option 'src'        'wifi'
  option 'dest'       'lan'

config zone
  option name 'lan'
  option network 'lan'
  option input 'ACCEPT'
  option output 'ACCEPT'
  option forward 'REJECT'
  option masq '1'
```

I have the following script to set all the files correctly, in `/sbin/sw_3g_mode`:

```
#!/bin/sh
/bin/cp -f /etc/config/dhcp.3g /etc/config/dhcp
/bin/cp -f /etc/config/firewall.3g /etc/config/firewall
/bin/cp -f /etc/config/network.3g /etc/config/network
/bin/cp -f /etc/config/wireless.3g /etc/config/wireless
/bin/sync
/sbin/ifup wifi
/sbin/wifi
/etc/init.d/firewall restart
/etc/init.d/dnsmasq restart
```

Enjoy it! :)

Reference links:

* http://wiki.openwrt.org/doc/recipes/3gdongle
* http://www.draisberghof.de/usb_modeswitch/bb/viewtopic.php?f=3&t=1517
* https://forum.openwrt.org/viewtopic.php?id=42931
* https://forum.openwrt.org/viewtopic.php?id=46725
* http://www.clarenceho.net/blog/2012/08/27/tp-link-tl-mr3020-as-ap-and-router-with-openwrt/
* https://dev.openwrt.org/ticket/9211
