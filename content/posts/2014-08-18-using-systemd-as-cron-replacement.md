---
date: 2014-08-18T14:37:35Z
draft: false
tags: ["systemd", "cron", "replacement"]
title: "Using systemd as cron replacement"
---

One of the features of systemd are timers.
This recipie shows how to run two tasks (*first* and *second*) every minute with dependencies between both.

* Create a `/etc/systemd/system/mytimer.timer` file with the following content

```
[Unit]
Description=run my timer tasks every minute and after reboot

[Timer]
OnBootSec=5min
OnCalendar=*:0/1
Unit=mytimer.target

[Install]
WantedBy=basic.target
```

* Create a `/etc/systemd/system/mytimer.target` file with the following content:

```
[Unit]
Description=Mytimer
StopWhenUnneeded=yes
```

* Create a *first*.service (it will be called before *second*.service) in `/etc/systemd/system/first.service`

```
[Unit]
Description=First Service

[Service]
ExecStart=/root/first.sh
Type=oneshot

[Install]
WantedBy=mytimer.target
```

* Create a *second*.service (it will be called after *first*.service) in `/etc/systemd/system/second.service`

```
[Unit]
Description=Second Service
Requires=first.service
After=first.service

[Service]
ExecStart=/root/second.sh
Type=oneshot

[Install]
WantedBy=mytimer.target
```

* First.sh

```
#!/bin/sh
sleep 5
echo "pretest" >> /root/systemdcron.log
echo "First" >> /root/systemdcron.log
date >> /root/systemdcron.log
echo "posttest" >> /root/systemdcron.log
```

* Second.sh

```
#!/bin/sh
echo "Second" >> /root/systemdcron.log
```

* Enable all the stuff

```
systemctl enable mytimer.timer
systemctl enable first.service
systemctl enable second.service
```

* Check the logs:

```
cat /root/systemdcron.log
pretest
First
Mon Aug 18 17:01:05 CEST 2014
posttest
Second
```

# Bonus tip
If the first script fails, the second isn't called.
