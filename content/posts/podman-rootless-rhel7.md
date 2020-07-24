---
title: "Podman rootless containers in RHEL7"
date: 2020-07-24T12:26:20+01:00
draft: false
tags: ["containers", "podman", "rhel7"]
---

Quick howto to make podman rootless containers work in RHEL7:

```bash
sudo yum clean all
sudo yum update -y
sudo yum install slirp4netns podman -y
echo "user.max_user_namespaces=28633" | sudo tee -a /etc/sysctl.d/userns.conf
sudo sysctl -p /etc/sysctl.d/userns.conf
sudo usermod --add-subuids 200000-300000 --add-subgids 200000-300000 $(whoami)
podman system migrate
```

Then, logout and log-in again. Easy peasy!
