---
title: "Using systemd-path to keep specific folder permissions"
date: 2022-02-21T8:30:00+00:00
draft: false
tags: ["systemd", "permissions"]
description: "Using systemd-path to keep specific folder permissions"
---

I wanted to have specific permissions on the `/var/lib/libvirt/images` folder
to be able to write as my user. To do it, you can just use `setfacl` as:

```
$ sudo setfacl -m u:edu:rwx /var/lib/libvirt/images
```

The issue is sometimes those permissions were reset to the default ones... but why?
and most important... who?


## auditd

To find the culprit I used `auditd` to monitor changes in that particular folder as:


```
$ sudo auditctl -w /var/lib/libvirt/images -p a -k libvirt-images
```

Then, performed a system update just in case... and after a while...


```
$ sudo ausearch -ts today -k libvirt-images -i

...
type=PROCTITLE msg=audit(21/02/22 12:33:01.550:222924) : proctitle=/usr/libexec/platform-python /bin/dnf update 
type=PATH msg=audit(21/02/22 12:33:01.550:222924) : item=0 name=/var/lib/libvirt/images inode=67517384 dev=fd:00 mode=dir,711 ouid=root ogid=root rdev=00:00 obj=system_u:object_r:virt_image_t:s0 nametype=NORMAL cap_fp=none cap_fi=none cap_fe=0 cap_fver=0 cap_frootid=0 
type=CWD msg=audit(21/02/22 12:33:01.550:222924) : cwd=/var/lib/libvirt 
type=SYSCALL msg=audit(21/02/22 12:33:01.550:222924) : arch=x86_64 syscall=lsetxattr success=yes exit=0 a0=0x55f5541d21b0 a1=0x7f73066fce5e a2=0x55f54f7a6970 a3=0x22 items=1 ppid=457888 pid=457974 auid=edu uid=root gid=root euid=root suid=root fsuid=root egid=root sgid=root fsgid=root tty=pts0 ses=50 comm=dnf exe=/usr/libexec/platform-python3.6 subj=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023 key=libvirt-images 
```

There you go... when updating the `libvirt-daemon` package as part of the regular
maintenance of the system (because you do update your packages often, right?),
those permissions were reseted...

```
$ rpm -V libvirt-daemon
...
.M.......    /var/lib/libvirt/images

$ rpm -q -l -v libvirt-daemon | grep "/var/lib/libvirt/images"
drwx--x--x    2 root    root                        0 feb  8 23:22 /var/lib/libvirt/images
```

## systemd-path to the rescue

[`systemd-path`](https://www.freedesktop.org/software/systemd/man/systemd.path.html)
monitors for files/folders and can trigger actions based on some rules.

We will leverage it to keep our permissions as we wanted.

### Fix folder permissions script

The first step is to create a script that will 'reset' the permissions
as we want every change. As root:

```
export NAME="fix-libvirt-images-permissions"
cat << 'EOF' > /usr/local/bin/${NAME}.sh
#!/bin/bash
USER='core'
FOLDER='/var/lib/libvirt/images'

chmod 711 ${FOLDER}
setfacl -m u:${USER}:rwx "${FOLDER}"
EOF

chmod 755 /usr/local/bin/${NAME}.sh
```

### systemd service to run the script

A simple systemd service to run the script. As root:

```
cat << EOF > /etc/systemd/system/${NAME}.service 
[Unit] 
Description="Run script to restore permissions"

[Service]
ExecStart=/usr/local/bin/${NAME}.sh
EOF
```

### systemd path file to monitor the folder and act upon changes

This is the key of this article. When the path changes, run
the script. As root:

```
cat << EOF > /etc/systemd/system/${NAME}.path
[Unit]
Description="Monitor /var/lib/libvirt/images permissions"

[Path]
PathChanged=/var/lib/libvirt/images
Unit=${NAME}.service

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now ${NAME}.path
```

## Results

```
$ date
lun feb 21 14:28:49 CET 2022

$ getfacl /var/lib/libvirt/images/
getfacl: Removing leading '/' from absolute path names
# file: var/lib/libvirt/images/
# owner: root
# group: root
user::rwx
user:edu:rwx
group::--x
mask::rwx
other::--x

$ rpm -V libvirt-daemon
...
.M.......    /var/lib/libvirt/images

$ ls -ld /var/lib/libvirt/images
drwxrwx--x+ 2 root root 188 feb  8 23:22 /var/lib/libvirt/images

$ rpm --restore libvirt-daemon

$ ls -ld /var/lib/libvirt/images
drwxrwx--x+ 2 root root 188 feb  8 23:22 /var/lib/libvirt/images

$ getfacl /var/lib/libvirt/images/
getfacl: Removing leading '/' from absolute path names
# file: var/lib/libvirt/images/
# owner: root
# group: root
user::rwx
user:edu:rwx
group::--x
mask::rwx
other::--x

$ journalctl -u fix-libvirt-images-permissions | tail -n2
feb 21 14:29:16 endurance.minwi.lan systemd[1]: Started "Run script to restore permissions".
feb 21 14:29:16 endurance.minwi.lan systemd[1]: fix-libvirt-images-permissions.service: Succeeded.
```

\o/