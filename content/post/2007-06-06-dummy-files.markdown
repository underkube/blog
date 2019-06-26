---
author: minwi
date: 2007-06-06 13:51:06+00:00
draft: false
title: Dummy files
type: post
url: /2007/06/06/dummy-files/
categories:
- Howtos
- Linux
---

Un pequeño tip:
Si te hace falta crear un fichero de X tamaño en linux, tan facil como:
dd if=/dev/zero of=fichero bs=tamañoenbytes count=1
P.ej:
dd if=/dev/zero of=dummyfile bs=1000000000 count=1
dummyfile de 1 Giga :)
