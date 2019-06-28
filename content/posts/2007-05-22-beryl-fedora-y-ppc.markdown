---
author: minwi
date: 2007-05-22 16:43:02+00:00
draft: false
title: beryl, fedora y ppc
type: post
url: /2007/05/22/beryl-fedora-y-ppc/
categories:
- Fedora
- Howtos
- Linux
---

Para los que se frustren al ver que al activar beryl (o compiz) en Fedora con un ppc, ahi va un minihowto:
Descargar http://wilsonet.com/packages/xorg-ppc-compiz-fix/xorg-x11-server-Xorg-1.1.1-47.1.ppc.rpm, e instalarlo via rpm (rpm -i ...).
Ya está :)
Explicación: Los micros ppc (powerpc), utilizados por los macs (y algunos más), organizan de manera distinta los bits... si sabes de programación te sonará bigendian y littleendian, y si no, busca en google :D, y el paquete de ppc de xorg, estaba compilado sin tenerlo en cuenta, asique hacia cosas raras con los colores... El paquete antes descargado e instalado, ya no tiene ese bug, aunque claro,... no es un paquete "oficial" de Fedora, y a saber que lleva :S
De todas maneras, sigue habiendo un bug, cuando suspendes el equipo y lo despiertas, los efectos se ven mal, pero se soluciona recargando beryl.
Siempre nos quedaran los fuentes... :D

PD.- Se me olvidaba... la info la he sacado del [bug 210760](https://bugzilla.redhat.com/bugzilla/show_bug.cgi?id=210760) del bugzilla de redhat :)
