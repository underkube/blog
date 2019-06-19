---
date: 2014-09-11T12:55:05Z
draft: false
tags: ["firewalld", "service", "xml", "rhel7", "fedora"]
title: "Define a new service in firewalld"
---

If you want to create a new service definition (i.e. to group a few ports in the same service), the procedure will be:

* Create a file called "myservice.xml" in /etc/firewalld/services/ folder with the following content:

```
<?xml version="1.0" encoding="utf-8"?>
  <service>  
    <short>myservice</short>  
    <description>Group httpd ports</description>  
    <port protocol="tcp" port="80"/>  
    <port protocol="tcp" port="443"/>  
    <port protocol="tcp" port="8080"/>  
    <port protocol="tcp" port="8000"/>  
  </service>
```

* Set permissions

```
restorecon /etc/firewalld/services/myservice.xml
chmod 640 /etc/firewalld/services/myservice.xml
```

* Reload firewalld to force it to read the XML

```
firewall-cmd --reload
```

* Add the RH-Satellite-6 service to the default zone

```
firewall-cmd --permanent --add-service=myservice
```

* Reload firewalld just in case

```
firewall-cmd --reload
```
