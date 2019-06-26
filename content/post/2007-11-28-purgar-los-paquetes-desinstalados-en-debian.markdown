---
author: minwi
date: 2007-11-28 10:39:01+00:00
draft: false
title: Purgar los paquetes desinstalados en Debian
type: post
url: /2007/11/28/purgar-los-paquetes-desinstalados-en-debian/
categories:
- Debian
- Linux
- sysadmin
---

dpkg --purge $(dpkg --get-selections | grep deinstall|cut -d" " -f1)

Easy! :D
