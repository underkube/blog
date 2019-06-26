---
author: minwi
date: 2007-08-28 10:20:57+00:00
draft: false
title: Script para prevenir reboot y shutdown en maquinas de producción
type: post
url: /2007/08/28/script-para-prevenir-reboot-y-shutdown-en-maquinas-de-produccion/
categories:
- bash
- Linux
---

Realmente vale para cualquier comando, lo unico que hace es pedir el hostname antes de ejecutar el mismo comando que se ha invocado (para prevenir un shutdown -h now en un servidor critico)

Lo ideal es colocarlo en /usr/local/bin/shutdown con 100 de permisos, y
luego en el /etc/profile/, colocar un:

alias shutdown="/usr/local/bin/shutdown"
alias reboot="/usr/local/bin/reboot"


`#!/bin/bash

# Script para impedir el reboot de maquinas de producción
# Para ello, una vez invocado shutdown o el reboot, pide el nombre del host

HOSTNAME=`hostname`
BIN_DIR=/sbin/

if [ `id -u` != 0 ]
        then
        echo "No eres root"
        exit
fi

read -p "Introduce el nombre del host: " ENTRADA

if [ "$HOSTNAME" == "$ENTRADA" ];
        then
        COMANDO=`echo $0 | awk -F/ '{print $5}'`
        $BIN_DIR$COMANDO $*
else
        echo "El hostname introducido no coincide"
fi
`
