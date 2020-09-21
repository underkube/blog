---
title: "Manage external displays with Gnome and Argos extension"
date: 2020-09-21T10:18:42+02:00
draft: false
tags: ["gnome", "argos", "displays"]
---

I wanted to easily switch between my regular desktop configuration:
![standard](/images/gnome-display-argos/00-standard.jpg)

All the external displays:
![externals](/images/gnome-display-argos/01-externals.jpg)

To a single external display:
![single-external](/images/gnome-display-argos/02-external-horizontal.jpg)

Or just the laptop screen:
![laptop](/images/gnome-display-argos/03-laptop.jpg)

This usually required to open `gnome-control-center`, then click displays, etc.
![gnome-control-center](/images/gnome-display-argos/gnome-control-center.png)

So I thought it would be nice to look for a extension in the
[Gnome Extensions](https://extensions.gnome.org) site... but I couldn't find
any that worked as I wanted... so let's try to do our own method! :)

## Argos

Just in case you don't know [https://github.com/p-e-w/argos](Argos), it is a
Gnome 'metaextension' where you can create your own extensions based on scripts,
commands, etc. It is inspired by, and fully compatible with, the 
[https://github.com/matryer/bitbar](BitBar) app for OSX.

In order to install it, you just need to go to its
[the Gnome Extensions](https://extensions.gnome.org/extension/1176/argos/) page
and click on the "ON|OFF" button. Profit!

There are plenty of examples and useful argos/bitbar scripts out there so my
recomendation is to look for 'prior art' to inspire yourself on creating your
own extensions.

## Xorg or Wayland?

I use Xorg instead of Wayland because I couldn't find an alternative to
`xbindkeys` for Wayland to customize my
[MX Master 2S](https://www.logitech.com/es-es/product/mx-master-2s-flow) mouse
keys. See
[here](https://wiki.archlinux.org/index.php/Logitech_MX_Master#Xbindkeys) for
more information on how to do that, but basically, this is my `~/.xbindkeysrc`:

```bash
# thumb wheel up => increase volume
"xte 'key XF86AudioRaiseVolume'"
   b:8

# thumb wheel down => lower volume
"xte 'key XF86AudioLowerVolume'"
   b:9
```

## Enter xrandr and arandr

tl;dr.- [`xrandr`](https://wiki.archlinux.org/index.php/Xrandr) is a cli tool to
manage displays using xorg while
[arandr](https://christian.amsuess.com/tools/arandr/) is a nice GUI tool to
create `xrandr` "scripts" easily:

![arandr screenshot](/images/gnome-display-argos/arandr.png)

Basically it generates `sh` scripts such as `~/.screenlayout/00-standard.sh`:

```bash
#!/bin/sh
xrandr --output eDP-1 --mode 1920x1080 --pos 3000x420 --rotate normal --output DP-1 --off --output HDMI-1 --off --output DP-2 --off --output HDMI-2 --off --output DP-1-1 --primary --mode 1920x1080 --pos 0x420 --rotate normal --output DP-1-2 --mode 1920x1080 --pos 1920x0 --rotate left --output DP-1-3 --off
```

So I have a script for each of my setups:

```bash
$ ls -1 ~/.screenlayout/
00-standard.sh
01-single-external.sh
02-only-external.sh
03-laptop.sh
04-vertical.sh
```

## Argos extension

With everything in place, the argos extension is just this
`~/.config/argos/external_monitor.1r..sh` script:

```bash
#!/usr/bin/env bash

echo "|iconName=video-display"
echo "---"

for i in $(find ~/.screenlayout/*.sh)
do
  # https://stackoverflow.com/questions/2664740/extract-file-basename-without-path-and-extension-in-bash
  file="${i##*/}"
  echo "${file%.*} | bash='${i}' terminal=false"
done
```

Which looks like:

![argos screenshot](/images/gnome-display-argos/argos-screenshot.png)

Nice!!!