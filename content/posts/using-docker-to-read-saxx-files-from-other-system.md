---
date: 2014-08-28T10:08:11Z
draft: false
tags: ["rhel6", "docker", "sar"]
title: "Using docker to read saXX files from other system"
---

From my F20 laptop, I'm not able to read RHEL6 sar data. Attempting to doing result in the following error:

```
File created by sar/sadc from sysstat version 9.0.4
Current sysstat version can no longer read the format of this file (0x1170)
```

According to [this KCS](https://access.redhat.com/solutions/746753) *you should be able to read older files using the --legacy option.*

But it doesn't work for me either:

```
Usage: sar [ options ] [ <interval> [ <count> ] ]

Options are:
...
```


My first idea was to use some RHEL6 vm, copy the sar files and run the sar command inside the vm, but as docker is uberc00l, I've decided to spend a few minutes in investigate how to do it with docker (yay!)

# Requisites

* RHEL6 docker image
* Docker installed (in my case, `yum install docker-io -y`)
* Sar files located in ${YOURDIRECTORY}

# Steps

* Pull the RHEL6 image

```
docker pull ${REMOTEIMAGE}
```

* Check it

```
docker images
```

* Run a docker container and mount your directory with the sar files:

```
docker run -d -v ${YOURDIRECTORY}:/opt/sar:ro ${YOURIMAGEID} /bin/bash
```

Try to access your sar files and it will fail with a permission denied error.

* Exit your container

```
exit
```

* Check your container id

```
docker ps -a
```

* Start the container (again, because the bash command has been finished)

```
docker start ${YOURCONTAINERID}
```

* Check docker container pid

```
docker inspect --format='{{.State.Pid}}' ${YOURCONTAINERID}
```

It will return a pid

* Jump into the docker container
```
nsenter -m -u -n -i -p -t ${CONTAINERPID} /bin/bash
```

* Check your sar data

```
file /opt/sar/sa20
```

* Profit!

# Cleaning steps

* Exit your container

```
exit
```

* Stop the container

```
docker stop ${YOURCONTAINERID}
```

* Delete the container

```
docker rm ${YOURCONTAINERID}
```

# To Do

* Simplify the docker run & docker start process (it's a little "hacky")

# References
* [Get Started with Docker Containers in RHEL 7 - Red Hat Customer Portal](https://access.redhat.com/articles/881893)
* [Attempting to read previous sar output files results in "Invalid system activity file" error - Red Hat Customer Portal](https://access.redhat.com/solutions/746753)
