---
date: 2015-02-10T07:34:09Z
draft: false
tags: ["tip", "rpm", "yum", "databases", "sync", "trick"]
title: "Sync rpm & yum databases"
---

If you install some rpm without yum (`rpm -Uvh`), you should see the following error:

```
...
Transaction Test Succeeded
Running Transaction
Warning: RPMDB altered outside of yum.
Installing : whatever.x86_64
...
```

This is because the yum database (`/var/lib/yum/*`) is out of sync with the rpm database (`/var/lib/rpm/*`), and to fix it you can execute:

```
yum history new
```

*You can also wait to install another package, then yum will resync the databases*

Source: https://access.redhat.com/solutions/62321
