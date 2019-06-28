---
author: minwi
date: 2007-08-22 08:37:38+00:00
draft: false
title: WPA en iBook con Gnome
type: post
url: /2007/08/22/wpa-en-ibook-con-gnome/
categories:
- Linux
- vpn
---

Para conectar con una red WPA, desde Gnome, tenemos la utilidad "network-manager-applet", que te permite conectarte a redes cableadas o wifi.
El funcionamiento es simple, pinchas en el icono, eliges la red, pones la password (en caso de que haya), y a volar :D
Lo único, que para ppc hay un bug, y es que no deja conectar a redes WPA... peeeeeero, hay un "workaround", y es poner la clave cifrada, en lugar de ascii.
Para ello, desde consola, ponemos: wpa_passphrase ssid passphrase, y saldra algo del estilo:
[code]network={
      ssid="BLABLABLA"
      psk=34e23...
}[/code]
Pues ese psk es el que hay que poner, no la clave en ascii :)

Ah!!!, un "plugin" para el applet muy interesante, network-manager-openvpn, que permite conectarte a una vpn tipo tunnelblick (ah!, tambien tiene un bug en ppc, y se cae al intentar conectar)
