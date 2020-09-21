---
date: 2015-08-21T09:54:23Z
draft: false
tags: ["fedora", "docker", "transmission", "flexget", "plex"]
title: "Dockerize your tv shows download and streaming to your TV"

---

I'm going to explain my setup of how do I watch my favourites tv shows using
containers.

# Requisites

* TV
* WiFi
* [ChromeCast](https://www.google.es/chrome/devices/chromecast/)
* [Plex for Android](https://play.google.com/store/apps/details?id=com.plexapp.android&hl=es)
* [ShowRSS](http://showrss.info/) [feed](http://showrss.info/?cs=feeds). You need to create an account and setup it with your favourites tv shows, so you'll end up with some rss feed like `http://showrss.info/rss.php?user_id=XXXXX&hd=1&proper=1`
* CentOS 7 (or any distro docker capable) with docker daemon installed and running
* Non root user to run all the commands (this is a personal preference, feel free to do it with root user if you want...)
* Shared folders to store your multimedia, flexget config & plex config. Something like:

```
/storage/media/
├── plex
├── flexget
├── music
├── pictures
├── transmission
│   ├── downloads
│   ├── incomplete
│   └── watch
└── videos
    ├── movies
    └── tvshows
```

*I store the media folder in a btrfs subvolume, but that's another topic :)*

# Setup
## TV

* ChromeCast is properly setup to your TV and wireless network
* Android mobile with Plex for Android installed in the same wireless network

## NAT
You need to open 12345/udp port in your router to your docker host
(transmission container connectivity with the outside world)

## Docker host

*  [eminguez/transmission-fedora](https://hub.docker.com/r/eminguez/transmission-fedora/) It will only download files (running 24x7)
* [eminguez/plex-media-server-fedora](https://hub.docker.com/r/eminguez/plex-media-server-fedora/) It will stream the tv show to my TV (running 24x7)
* [eminguez/flexget-fedora](https://hub.docker.com/r/eminguez/flexget-fedora/)
It will handle the tv shows downloads, move them when finished and clean them up in transmission when ratio or timeout is reached (running every hour)

*Why Fedora? Because I like it and I work at Red Hat :D*

# How does it work

Transmission container is listening in 9091 for API calls and webgui. Every hour (using cron), the flexget container is executed, and attached to the same network namespace than the transmission container (so it can send API calls to `localhost`).

Flexget will:

* query the RSS feed and enqueue the proper magnet links to the transmission daemon to download the tv shows that you've configured
* if finished, it will move the tv shows to the proper folders in your media folder
* if finished, and ratio or timeout reached, it will clean the transmission queue

Then, when you want, fire the Plex app in your Android phone, browse your favourite tv show, and play it in your big screen TV :)

# Installation

Easy peasy!

* Pull the docker images:

```
docker pull eminguez/transmission-fedora
docker pull eminguez/flexget-fedora
docker pull eminguez/plex-media-server-fedora
```

* Create a simple script to run the flexget container (in my case /home/edu/bin/flexget.sh`) and give it the proper execution permissions


```
#!/bin/sh
docker run --rm --net=container:transmission -v /storage/media/flexget/:/home/flexget/.config/flexget/ -v /storage/media/transmission/downloads/:/home/flexget/flexget/from -v /storage/media/videos/tvshows/:/home/flexget/flexget/to eminguez/flexget-fedora > /dev/null
```

* Setup an hourly cron task to trigger the flexget container:

```
0 * * * * /home/edu/bin/flexget.sh >/dev/null 2>&1
```

* Configure flexget to get your tv shows. I use the [following template](https://github.com/e-minguez/flexget-fedora/blob/master/config.yml.sample), replace the VARIABLES with your settings, and store it in `/storage/media/flexget/config.yml`:

```
templates:
  global:
    clean_transmission:
      host: localhost
      port: 9091
      username: transmission
      password: PASSWORD
      finished_for: 2 hours
      min_ratio: 1
    disable: [details]
    # configuration of email parameters
    # each feed will send an email with the accepted entries
    # can be disabled per feed with email: active: False
    email:
      active: True
      from: FROM
      to: TO
      smtp_host: smtp.gmail.com
      smtp_port: 587
      smtp_login: true
      smtp_username: USERNAME
      smtp_password: PASSWORD
      smtp_tls: true
tasks:
  # downloading task
  download-rss:
    rss: http://showrss.info/rss.php?user_id=SHOWRSS_ID&hd=1&proper=1&namespaces=true&magnets=true
    # fetch all the feed series
    all_series: yes
    limit_new: 10  
    # use transmission to download the torrents
    transmission:
      host: localhost
      port: 9091
      username: transmission
      password: PASSWORD
    only_new: yes
  # sorting task
  sort-files:
    find:
      # directory with the files to be sorted
      path: /home/flexget/flexget/from/
      # fetch all avi, mkv and mp4 files, skips the .part files (unfinished torrents)
      regexp: '.*\.(avi|mkv|mp4)$'
      recursive: yes
    accept_all: yes
    seen: local
    regexp:
      reject:
        - sample
    # this is needed for the episode names
    thetvdb_lookup: yes
    all_series:
      parse_only: yes
    move:
      # this is where the series will be put
      to: /home/flexget/flexget/to/{{ tvdb_series_name }}
      # save the file as "Series Name - SxxEyy - Episode Name.ext"
      filename: '{{ tvdb_series_name }} - {{ series_id }} - {{ tvdb_ep_name }}{{ location | pathext }}'
```

* Run the transmission container with the previously used password as environmental variable:

```
docker run -d --name transmission --restart=always -p 12345:12345 -p 12345:12345/udp -p 9091:9091 -e ADMIN_PASS=PASSWORD -v /storage/media/transmission/downloads:/var/lib/transmission/downloads -v /storage/media/transmission/incomplete:/var/lib/transmission/incomplete -v /storage/media/transmission/watch:/var/lib/transmission/watch eminguez/transmission-fedora
```

*Note the restart=always flag to keep it running 24x7 and survive host reboots!*

* Run the plex container:

```
docker run --name plex-media-server -d --restart=always -v /storage/media/plex/:/config -v /storage/media/:/media -p 32400:32400 eminguez/plex-fedora
```

*Note the restart=always flag to keep it running 24x7 and survive host reboots!*

* Browse to `http://your_host:32400/web` and configure plex for your environment.

*If this doesn't work, kill the plex container, edit `/storage/media/plex/Plex Media Server/Preferences.xml` and add the `allowedNetworks="192.168.1.0/255.255.255.0"` attribute to the <Preferences ...> node to allow networking connections, and start the plex container again*

# Tips

* If you want Avahi broadcast to work, add `--net=host` to the plex container run command, but this will be more insecure. I've setup manually my server in the Plex Android app to point directly to the host in *Settings > Advanced > Manual Connections*
* Set a friendly Plex server name under *Plex Settings > Server > General* in the Plex web Gui
* You can download any torrent/magnet file browsing `http://your_host:9091` using "transmission/PASSWORD" and it will be downloaded to `/storage/media/transmission/downloads/` folder
* As a bonus, you can drop any torrent file in `/storage/media/transmission/watch/` folder and transmission will gently download it for you :)

# Volume mapping explanation

## Flexget
* `/storage/media/flexget/:/home/flexget/.config/flexget/ to store the flexget configuration, sqlite database and log file
* `/storage/media/transmission/downloads/:/home/flexget/flexget/from` where transmission will move the files once downloaded
* `/storage/media/videos/tvshows/:/home/flexget/flexget/to where plex will look for tv shows

## Transmission
* `/storage/media/transmission/incomplete:/var/lib/transmission/incomplete` incomplete downloaded files
* `/storage/media/transmission/downloads:/var/lib/transmission/downloads` where transmission will move the files once downloaded
* `/storage/media/transmission/watch:/var/lib/transmission/watch` where transmission will look for torrent files

## Plex
* `/storage/media/plex/:/config` to store the plex configuration, database and so on
* `/storage/media/:/media` where plex will look for media files (tv shows, movies, music, pictures,...)

# References and thanks
I've used the following repos as base and just adapt it to Fedora:

* https://github.com/wernight/docker-plex-media-server
* https://github.com/elventear/docker-transmission

So, thank you @wernight and @elventear :)
