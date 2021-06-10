---
title: "Running hpasmcli commands on a container using podman"
date: 2021-06-10T8:30:00+00:00
draft: false
tags: ["baremetal", "podman", "hardware"]
---

To be able to monitor hardware health, status and information on HP servers
running RHEL, it is required to install the 
[HP's Service Pack for Proliant](https://downloads.linux.hpe.com/SDR/project/spp/)
packages.

It seems the [Management Component Pack](http://downloads.linux.hpe.com/SDR/project/mcp/)
is the same(agent software but for community distros, for enterprise, use SPP.

There is more info about those HP tools on the
[HP site](https://support.hpe.com/hpesc/public/docDisplay?docId=emr_na-a00018639en_us)

Basically you just need to add a yum/dnf repository, install the packages and
start a service (actually the service is started as part of the RPM post-install,
which is not a good practice...)

Installing packages those days is not cool anymore, you better use containers
instead!

## Environment used

In my case I've used an HP ProLiant DL380 Gen9 running RHEL 7.9, so your mileage may vary.

## Building a container with the tools

Basically I've modified the Dockerfile from the
[Academic Computer Centre in Gdansk](https://projects.task.gda.pl/containers/hp-health)
to use ubi8-init instead.

As mentioned before, a systemd service is installed and required to be running
for the tools to work, so the easiest way is to use the ubi8-init image as it 
contains everything needed to run systemd as PID1 and more interesting stuff.

```dockerfile
FROM registry.access.redhat.com/ubi8/ubi-init

RUN echo $'[spp]\n\
name=Service Pack for ProLiant\n\
baseurl=http://downloads.linux.hpe.com/repo/spp-gen9/rhel/8/x86_64/current\n\
enabled=1\n\
gpgcheck=0\n\
gpgkey=file:///etc/pki/rpm-gpg/GPG-KEY-ServicePackforProLiant\n '\
>> /etc/yum.repos.d/spp.repo

RUN dnf install hp-health hp-ams -y
CMD [ "/sbin/init" ]
```

Then, build the container image:

```bash
podman build --format=docker -t hphealth .
```

## Running the container

It is required for the container to be privileged and use `net=host` as
it requires direct access to hardware stuff.

```bash
podman run --detach --privileged --net=host  --name hphealth localhost/hphealth:latest
```

This will run the container detached so in order to perform the hpasmcli commands
you need, you want to exec the hpasmcli in the container directly as:

```bash
podman exec -it hphealth /usr/sbin/hpasmcli -s "show temp"

Sensor   Location              Temp       Threshold
------   --------              ----       ---------
#1        AMBIENT              19C/66F    42C/107F 
#2        PROCESSOR_ZONE       40C/104F   70C/158F 
#3        PROCESSOR_ZONE        -          -       
#4        MEMORY_BD            36C/96F    89C/192F 
#5        MEMORY_BD            29C/84F    89C/192F 
#6        MEMORY_BD             -          -       
#7        MEMORY_BD             -          -       
#8        SYSTEM_BD            35C/95F    60C/140F 
#9        SYSTEM_BD             -          -       
#10       SYSTEM_BD            36C/96F    105C/221F
#11       POWER_SUPPLY_BAY     33C/91F     -       
#12       POWER_SUPPLY_BAY     32C/89F     -       
#13       SYSTEM_BD            37C/98F    115C/239F
#14       SYSTEM_BD             -          -       
#15       SYSTEM_BD            36C/96F    115C/239F
#16       SYSTEM_BD            32C/89F    115C/239F
#17       SYSTEM_BD             -          -       
#18       SYSTEM_BD             -          -       
#19       POWER_SUPPLY_BAY     40C/104F    -       
#20       POWER_SUPPLY_BAY     40C/104F    -       
#21       I/O_ZONE             67C/152F   100C/212F
#22       I/O_ZONE              -          -       
#23       I/O_ZONE             56C/132F   100C/212F
#24       I/O_ZONE              -          -       
#25       I/O_ZONE              -          -       
#26       I/O_ZONE              -          -       
#27       I/O_ZONE             67C/152F   100C/212F
#28       I/O_ZONE              -          -       
#29       SYSTEM_BD             -          -       
#30       AMBIENT              33C/91F    65C/149F 
#31       I/O_ZONE             28C/82F    70C/158F 
#32       I/O_ZONE             29C/84F    70C/158F 
#33       I/O_ZONE             30C/86F    70C/158F 
#34       I/O_ZONE              -          -       
#35       I/O_ZONE              -          -       
#36       I/O_ZONE              -          -       
#37       I/O_ZONE             46C/114F   75C/167F 
#38       SYSTEM_BD            31C/87F    75C/167F 
#39       SYSTEM_BD            35C/95F    70C/158F 
#40       SYSTEM_BD            34C/93F    75C/167F 
#41       SYSTEM_BD            37C/98F    90C/194F 
#42       SYSTEM_BD             -          -       
#43       SYSTEM_BD            31C/87F    60C/140F 
#44       POWER_SUPPLY_BAY     37C/98F    100C/212F

```

There are a lot of interesting commands to check with hpasmcli, like
[those](https://sleeplessbeastie.eu/2017/02/20/how-to-use-hp-management-command-line-interface/).

Profit!
