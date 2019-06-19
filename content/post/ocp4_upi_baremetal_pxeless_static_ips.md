---
title: "OCP4 UPI baremetal pxeless with static ips"
date: 2019-06-19T15:16:45+02:00
draft: false
tags: ["ocp4","openshift"]
---

Do you want to deploy an OCP4 cluster without using PXE and using static IPs?

I've got you covered. See [my unsupported step by step instructions](https://github.com/e-minguez/ocp4-upi-bm-pxeless-staticips) on how to doing it,
including:

* No PXE (pretty common scenario in big companies)
* Avoid installing stuff and use containers instead (instead yum/dnf install httpd, haproxy,... use containers)
* Use rootless containers if possible
* Use Fedora29/RHEL8 stuff (nmcli, firewalld, etc.)

Enjoy!
