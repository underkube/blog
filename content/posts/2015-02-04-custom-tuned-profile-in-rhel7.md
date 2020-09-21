---
date: 2015-02-04T09:09:15Z
draft: false
tags: ["rhel7", "tuned", "custom"]
title: "Custom tuned profile in RHEL7"
---

Tuned has been improved from RHEL6 and the process to create a custom tuned profile has changed.
The syntax is now "ini"fied and the process to create a custom profile (i.e.- my-virtual-host) is slightly different.
In this example, I'll modify the *virtual-host* profile and add some script to customize it:

* Install tuned (if it's not installed yet)

```
yum install -y tuned
```

* Create a directory inside `/etc/tuned` named "my-virtual-host"

```
mkdir -p /etc/tuned/my-virtual-host/
```

* Create a custom profile and include the *virtual-host* one:

```
cat > /etc/tuned/my-virtual-host/tuned.conf << EOF
#
# tuned configuration
#
[main]
include=virtual-host

[script]
script=script.sh
EOF
```

* Create a custom script:

```
cat > /etc/tuned/my-virtual-host/script.sh << EOF
#!/bin/sh
. /usr/lib/tuned/functions
SSD=sda
start() {
  echo "noop" > /sys/block/${SSD}/queue/scheduler
  return 0
}

stop() {
  echo "deadline" > /sys/block/${SSD}/queue/scheduler
  return 0
}

process $@
```

* Make it executable:

```
chmod a+x /etc/tuned/my-virtual-host/script.sh
```

* Active it:

```
tuned-adm profile my-virtual-host
```

* Check it:

```
tuned-adm active
Current active profile: my-virtual-host

cat /sys/block/sda/queue/scheduler
[noop] deadline cfq
```

As you've noticed, I've created a custom script to modify the scheduler of my
`/dev/sda` device. I've tried to make it work without creating a custom script
(as the Red Hat instruction says in
https://access.redhat.com/solutions/1305833), adding the following to the
custom tuned.conf file:

```
[disk]
devices=sda
elevator=noop
```

But it didn't work for me.

HTH
