---
title: "Xiaomi Mijia Ble Sensor MQTT on containers"
date: 2019-11-08T12:35:12+01:00
draft: false
---

As a geek, I use [Home Assistant](https://www.home-assistant.io) to simplify my home automation tasks (running in a container, of course!).
Home Assistant is a really nice project and I recommend you to take a look at it if you want to get started in home automation.

One of the things I wanted to have was temperature and humidity sensors spread across the rooms in order to be able to see the current status and historical data... and it turns out it is supported out of the box using the [mitemp_bt module](https://www.home-assistant.io/integrations/mitemp_bt/). I did tested it but [it doesn't seem to work](https://github.com/home-assistant/home-assistant/issues/24605) in latest Home Assistant versions :(

I decided to look for a workaround... and I found this [xiaomi-ble-mqtt](https://github.com/algirdasc/xiaomi-ble-mqtt) project, which basically is a python script that using the `mitemp_bt` library, queries the device and send the data via mqtt. Pretty cool!

I had mqtt already configured for some other stuff in my Home Assistant so it was just a matter of running it manually to verify it worked... and it did!

But... that wasn't enough as I wanted to use containers instead of just 'run it'... so I created a [pull request](https://github.com/algirdasc/xiaomi-ble-mqtt/pull/4) to the main repo with a Dockerfile :)

Basically you just need to build your own container image, create a directory with the proper `mqtt.ini` and `devices.ini` files and run it as:

```shell
podman run --net=host --rm -v /home/edu/xiaomi-ble-mqtt-config/:/config:Z eminguez/xiaomi-ble-mqtt:latest
```

> NOTE: The `--net=host` is required for the container to use the bluetooth adapter... it is not cool from a security perspective, but it works for me `¯\_(ツ)_/¯`

So, I just needed to add a cronjob every X minutes to gather the sensor data and push it to mqtt as:

```shell
*/5 * * * * /home/edu/bin/xiaomi-ble-mqtt.sh
```

Where the script is just a wrapper:

```shell
#!/bin/sh
podman run --net=host --name="xiaomi-ble-mqtt" --rm -v /home/edu/xiaomi-ble-mqtt/:/config:Z eminguez/xiaomi-ble-mqtt:latest > /dev/null 2>&1
```

Then, in Home Assistant (`sensors.yaml`), add the sensors as:

```yaml
- name: "Temperatura habitacion"
  platform: mqtt
  state_topic: "sensors/habitacion"
  qos: 0
  unit_of_measurement: "ºC"
  value_template: "{{ value_json.temperature}}"
  #availability_topic: "sensors/habitacion/availability"
  json_attributes_topic: "sensors/habitacion"

- name: "Humedad habitacion"
  platform: mqtt
  state_topic: "sensors/habitacion"
  qos: 0
  unit_of_measurement: "%"
  value_template: "{{ value_json.humidity}}"
  #availability_topic: "sensors/habitacion/availability"
  json_attributes_topic: "sensors/habitacion"

- name: "Bateria sensor habitacion"
  platform: mqtt
  state_topic: "sensors/habitacion"
  qos: 0
  unit_of_measurement: "%"
  value_template: "{{ value_json.battery}}"
  #availability_topic: "sensors/habitacion/availability"
  json_attributes_topic: "sensors/habitacion"
```

![Habitacion](/images/habitacion_sensor.png)

Also I wanted to have the mean of all sensors:

```yaml
- name: "Temperatura casa"
  platform: min_max
  type: mean
  entity_ids:
    - sensor.temperatura_habitacion
    - sensor.temperatura_cocina
    - sensor.temperatura_salon
```

![Media](/images/media.png)

That's it! I've been using this method for months and it just 'works' :)