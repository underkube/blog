---
date: 2014-11-25T09:52:31Z
draft: false
title: "Set file as executable in svn"
---

`chmod` doesn't do the trick, so you need to set the proper flag in svn with:

```
svn propset svn:executable ON <filename>
```
