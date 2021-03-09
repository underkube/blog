---
title: "Nextcloud with podman rootless containers and user systemd services. Part III - NFS gotchas"
date: 2021-01-28T8:30:00+00:00
draft: false
tags: ["nextcloud", "podman", "rootless", "systemd", "nfs", "zfs"]
---

## Nextcloud in container user IDs

The nextcloud process running in the container runs as the `www-data` user which
in fact is the user id 82:

```bash
$ podman exec -it nextcloud-app /bin/sh
/var/www/html # ps auxww | grep php-fpm
    1 root      0:10 php-fpm: master process (/usr/local/etc/php-fpm.conf)
   74 www-data  0:16 php-fpm: pool www
   75 www-data  0:15 php-fpm: pool www
   76 www-data  0:07 php-fpm: pool www
   84 root      0:00 grep php-fpm
/var/www/html # grep www-data /etc/passwd
www-data:x:82:82:Linux User,,,:/home/www-data:/sbin/nologin
```

## NFS and user IDs

NFS exports can be configured to have a forced uid/gid using the `anonuid`,
`anongid` and `all_squash` parameters. For Nextcloud then:

```bash
all_squash,anonuid=82,anongid=82
```

To configure those settings in ZFS I configured my export as:

```bash
zfs set sharenfs="rw=@192.168.1.98/32,all_squash,anonuid=82,anongid=82" tank/nextcloud
```

Then, I `chowned` all the files to match that user in the NFS server as well:

```bash
shopt -s dotglob
chown -R 82:82 /tank/nextcloud/html/
shopt +s dotglob
```

I did used `shopt -s dotglob` for chown to also change the user/group for the
_hidden_ folders (the ones where the name starts with a dot, such as `~/.ssh`)

## Tweaks

With everything in place it should work... but it didn't.

There are a few places where Nextcloud tries to change some files' modes or
check file permissions and it fails otherwise.

Fortunately, those can be bypased. But let's take a look at the details first.

### console.php

The console.php file has a [check to ensure the ownership](https://github.com/nextcloud/server/blob/master/console.php#L68-L76):

```php
if ($user !== $configUser) { 
  echo "Console has to be executed with the user that owns the file config/config.php" . PHP_EOL; 
  echo "Current user id: " . $user . PHP_EOL; 
  echo "Owner id of config.php: " . $configUser . PHP_EOL; 
  echo "Try adding 'sudo -u #" . $configUser . "' to the beginning of the command (without the single quotes)" .  PHP_EOL; 
  echo "If running with 'docker exec' try adding the option '-u " . $configUser . "' to the docker comman (without  the single quotes)" . PHP_EOL; 
  exit(1); 
} 
```

I opened a [github issue](https://github.com/nextcloud/server/issues/24914) but
meanwhile, the fix I did was basically [delete that check](https://github.com/e-minguez/nextcloud-container-nfs-fix/blob/master/console/console.php.patch)

### cron.php

[Same problem](https://github.com/nextcloud/server/blob/master/cron.php#L99-L105):

```php
$configUser = fileowner(OC::$configDir . 'config.php');
if ($user !== $configUser) {
  echo "Console has to be executed with the user that owns the file config/config.php" . PHP_EOL;
  echo "Current user id: " . $user . PHP_EOL;
  echo "Owner id of config.php: " . $configUser . PHP_EOL;
  exit(1);
}
```

Same [fix](https://github.com/e-minguez/nextcloud-container-nfs-fix/blob/master/cron/cron.php.patch)
and another [github issue](https://github.com/nextcloud/server/issues/24915)
opened.

### entrypoint.sh

The container entrypoint script runs an rsync process when Nextcloud is updated.
As part of that rsync process, [it uses `--chown`](https://github.com/nextcloud/docker/blob/master/21.0/fpm-alpine/entrypoint.sh#L95)
, which is then forbidden by the NFS server:

```bash
rsync: chown "/var/www/html/whatever" failed: Operation not permitted (1)
```

The [github issue](https://github.com/nextcloud/docker/issues/1344) and the
[fix](https://github.com/e-minguez/nextcloud-container-nfs-fix/blob/master/entrypoint/entrypoint.sh.patch)
is basically ignore the `chown`.

## quay.io/eminguez/nextcloud-container-fix-nfs

Meanwhile those issues are fixed (not sure if they will), I keep a container
image that includes those fixes and that I try to keep it updated for my own
sake in https://github.com/e-minguez/nextcloud-container-nfs-fix

The image is already available at https://quay.io/repository/eminguez/nextcloud-container-fix-nfs
so feel free to use it if you are having the same issues.

## Next post

In the next post I will explain how to expose your Nextcloud instance using
[bunkerized-nginx](https://github.com/bunkerity/bunkerized-nginx) and how to
create proper systemd unit files to be able to treat the pods and containers as
services.

You can read it
[here](https://www.underkube.com/posts/2021-01-28-nextcloud-podman-rootless-systemd-part-iv-exposing/)
