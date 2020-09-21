---
title: "Lock & unlock GNOME session using CLI"
date: 2019-06-19T10:37:22+02:00
draft: false
tags: ["gnome","tips"]
---
I personally use those commands with the [gsconnect](https://extensions.gnome.org/extension/1319/gsconnect/) GNOME extension and
[KDE Connect](https://play.google.com/store/apps/details?id=org.kde.kdeconnect_tp) on my Android phone:

# Lock
```
gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.Lock
```
# Unlock
```
loginctl unlock-session && xset dpms force on
```
