---
date: 2014-11-18T09:41:56Z
draft: false
title: "RPM Architecture-specific Dependencies"
---

If you need to specify some packages in the "Require" section of a SPEC file, you should use the [ISA (Instruction Set Architecture) dependencies](http://www.rpm.org/wiki/PackagerDocs/ArchDependencies)

The following is not longer valid:

```
Requires: gtk.i686
```

This is valid:

```
Requires: gtk(x86-32)
```
