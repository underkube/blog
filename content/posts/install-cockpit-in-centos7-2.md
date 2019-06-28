---
date: 2015-02-04T11:17:21Z
draft: false
tags: ["systemd", "fedora", "cockpit", "monitoring", "centos"]
title: "Install cockpit in CentOS7"
---

NOTE: *Slightly* stolen from https://jreypo.wordpress.com/2015/01/09/how-to-install-cockpit-on-centos-7/

* Download the virt7-testing repo from the cockpit github

```
wget -O /etc/yum.repos.d/virt7-testing.repo https://github.com/baude/sig-atomic-buildscripts/raw/master/virt7-testing.repo
```

* Install cockpit

```
yum install -y cockpit
```

* Enable cockpit (notice it's not a service but a socket)

```
systemct enable cockpit.socket
```

* Add cockpit service to firewalld allowed services

```
firewall-cmd --permanent --add-service=cockpit
```

* Reload the firewall to enable the previous step
```
firewall-cmd reload
```

* Create a custom systemd configuration file for cockpit service to workaround [this issue](https://github.com/cockpit-project/cockpit/issues/1581)

```
cat > /etc/systemd/system/cockpit.service.d/no-tls.conf << EOF  
[Service]  
ExecStart=  
ExecStart=/usr/libexec/cockpit-ws --no-tls
```

* Reload the systemd config

```
systemctl daemon-reload
```

* Restart cockpit
```
systemctl restart cockpit  
```

* Access cockpit webgui using http instead httpS at port 9090 and login with the root user

**Note:** ExecStart needs to be twice to "clear" the default ExecStart defined in the `/usr/lib/systemd/system/cockpit.service` file, or systemd will complain about it like:

```
systemd: cockpit.service has more than one ExecStart setting, which is only allowed for Type=oneshot services. Refusing.
```


You can even customize the host image!
