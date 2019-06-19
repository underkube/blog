---
date: 2014-08-28T08:23:13Z
draft: false
tags: ["docker", "proxy"]
title: "Docker & proxy"
---

To configure docker (in RHEL) to get images through proxy, edit `/etc/sysconfig/docker` and add the following parameters according to your environment:

```
HTTP_PROXY="http://<proxy_host>:<proxy_port>"
HTTPS_PROXY="https://<proxy_host>:<proxy_port>"
http_proxy="${HTTP_PROXY}"
https_proxy="${HTTPS_PROXY}"
```

**And** restart docker service:

```
systemctl restart docker
```
