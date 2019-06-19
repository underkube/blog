---
date: 2016-04-17T17:06:02Z
draft: false
tags: ["ps3", "ps4", "dfgt", "gimx", "diy"]
title: "Using a PS3 wheel in PS4 with Gimx"
---

I had a [Driving Force GT wheel](http://support.logitech.com/en_us/product/driving-force-gt) which is not supported and it doesn't work in PS4, so it was basically covering in dust... but the community is awesome and there exists a project called [gimx](https://github.com/matlo/GIMX) that enables support for old wheels in new systems like PS4, so I decided to give it a try, and after a few hours understanding what I needed and getting my hands dirty, it is working perfect with the [DIY adapter](http://gimx.fr/wiki/index.php?title=DIY_USB_adapter) (using a Chinese atmega32u4 + CP2102 converter) and a Raspberry PI 2.

The [official wiki](http://gimx.fr/wiki/index.php?title=Main_Page) is pretty well documented, so I'm going to explain the addons I've made to fit what I wanted :)

# Autostart at boot in without X

Instead using a [.desktop file](http://gimx.fr/forum/viewtopic.php?f=11&t=1435) that will start X and then gimx, I've created a simple systemd init file that starts gimx.

Simply create a file `/etc/systemd/system/gimx.service` with the following content:

```
[Unit]
Description=GIMX
After=syslog.target network.target

[Service]
User=pi
Type=simple
ExecStart=/usr/bin/gimx -p /dev/ttyUSB0 -c LogitechDrivingForceGT_G29.xml --nograb
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Run `systemctl daemon-reload` to notify systemd about the new file and `systemctl enable gimx --now` to enable the gimx service start at boot and start it in the same line.

> Please note *LogitechDrivingForceGT_G29.xml* file should be available in the pi home directory as /home/pi/LogitechDrivingForceGT_G29.xml

# Notify when gimx is running

In order to have a proper confirmation about if the gimx service is up and running, I've created a simple python script that turns a led on if the gimx service is running.

The file is located at `/home/pi/blink.py`:

```
#!/usr/bin/python
import os
import time
import RPi.GPIO as GPIO

led = 23
button = 18
GPIO.setmode(GPIO.BCM)
GPIO.setup(led, GPIO.OUT)
GPIO.setup(button, GPIO.IN, pull_up_down = GPIO.PUD_UP)

def Shutdown(channel):  
  GPIO.output(led, True)
  time.sleep(0.2)
  GPIO.output(led, False)
  time.sleep(0.2)
  GPIO.output(led, True)
  time.sleep(0.2)
  GPIO.output(led, False)
  os.system("sudo shutdown -h now")

GPIO.add_event_detect(18, GPIO.FALLING, callback = Shutdown, bouncetime = 2000)

while True:
  found = False
  time.sleep(5)
  pids = [pid for pid in os.listdir('/proc') if pid.isdigit()]
  for pid in pids:
    try:
      cmd = open(os.path.join('/proc', pid, 'cmdline'), 'rb').read()
      if "gimx" in cmd:
        found = True
    except IOError: # proc has already terminated
      continue
  if found == True:
    GPIO.output(led, True)
  else:
    GPIO.output(led, False)
```

> As a bonus, I've also added a button so when it is pressed, there is a little blink effect, and the pi is shutted down. Pretty cool uh? :D

The schema is the following:

![](/content/images/2016/04/pi-1.png)

To start at boot, simply add it to the *pi* user crontab (`crontab -e`) as `@reboot /home/pi/blink.py`

# Order
All the wires, pi, etc. is hidden inside a Samsung Galaxy S6 box, which makes it pretty convenient.

![](/content/images/2016/04/IMG_20160417_174452-1.jpg)
![](/content/images/2016/04/IMG_20160417_174505-1.jpg)

Enjoy!
