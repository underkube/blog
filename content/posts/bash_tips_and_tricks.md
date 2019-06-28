---
title: "Bash tips & tricks"
date: 2019-06-18T17:19:14+02:00
draft: false
tags: ["bash", "tips"]
---

# Bash variable with the content of a file

```
NTPFILECONTENT=$(cat /etc/chrony.conf)
```

This will store the '\n' characters as well.

# Display bash variable with the content of a file

```
echo "${NTPFILECONTENT}"
```

Beware the quotes

# Append content to a bash variable with a new line

```
NTPFILECONTENT="${NTPFILECONTENT}"$'\n'"pool ${ntp} iburst"
```
