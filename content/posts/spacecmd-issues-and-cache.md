---
date: 2014-12-03T12:13:22Z
draft: false
title: "spacecmd issues and cache"
---

When using spacecmd, it caches stuff like systems and packages.
If you are doing operations like register and delete systems, maybe it's useful to delete the cache if there are messages like:

```
ERROR: redstone.xmlrpc.XmlRpcFault: No such system - sid = 1000010740
```

To clear cache, use:

```
spacecmd clear_caches
```
