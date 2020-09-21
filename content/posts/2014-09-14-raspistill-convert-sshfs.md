---
date: 2014-09-14T09:37:09Z
draft: false
tags: ["raspberry", "raspisitll", "convert", "imagemagick", "sshfs"]
title: "Raspistill + convert + sshfs"
---

If you have a raspberry with a camera module, you can use them as a webcam. The simpliest idea is to capture a picture every x seconds and serve it with a simple web server.
But if you don't want to use the raspberry as a web server (low bandwitdh, other tasks, privacy,...), you can use `sshfs` to copy the image to a remote filesystem and serve it from there.
The main idea:

```
	+------+                            +-------------------+
	|  pi  | +----------------------->  |     web server    |
	+------+                            +-------------------+
	                                            ^ ^ ^        
	                                            | | |        

                                        	   internet
```

# Setup
## Raspberry pi

* Install Raspbian (upgrade it, configure it,...)
* Install ImageMagick (`aptitude install imagemagick`)
* Install sshfs (`aptitude install sshfs`)
* Enable camera with `raspi-config` wizard
* Add the user you want to use to the fuse group (`usermod -aG fuse <user>`)
* Logout and login (to apply group permissions)
* Create a directory where the remote directory will be mounted (`mkdir -p /home/user/pics`)

## Web server

* Create a dedicated user (`adduser pi`)
* Setup a directory where the image will be located (I've used OpenBSD, so the default directory is /var/www/htdocs)

```
mkdir -p /var/www/htdocs/webcam/images/
chown -R pi.pi /var/www/htdocs/webcam/
```

Note that this is the simple way, the best way will be to create a dedicated vhost, secure it,...

* Create `/var/www/htdocs/webcam/index.html` file with the following content:

```
<html>
<head>
<meta http-equiv="refresh" content="30" >
</head>
<body>
<img src=./images/webcam.jpg>
</body>
</html>
```

# Usage
## Raspberry pi

* Mount using sshfs the remote directory previosly created
```
sshfs -o auto_cache,reconnect,no_readahead,Ciphers=arcfour $REMOTEUSER@$REMOTEHOST:/var/www/htdocs/webcam/images/ /home/user/pics/
```

Note that I've used a few sshfs options. Check `man sshfs` for more information.

* Capture a test pic with raspistill

```
raspistill -h ${HEIGHT} -w ${WIDTH} -q ${QUALITY} -o /dev/shm/testpic.jpg -n
```

Note that I've used /dev/shm (ram filesystem) to store the temporary picture

* Watermark it!
```
convert /dev/shm/testpic.jpg -fill white -undercolor '#00000080' -gravity SouthEast -annotate +0+5 " My webcam " /home/user/pics/webcam.jpg
```

## Your browser

* Go to http://yourwebserver/webcam/
* Profit!

# Improvements

* Loop it! (a simple bash script with a while loop...)
* Watermark it with the date (replace "My webcam" with the `date` output)
* Disable autorefresh in the index.html
* ...
