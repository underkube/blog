---
title: "OCP4 tips & tricks"
date: 2019-06-18T16:42:20+02:00
draft: false
tags: ["ocp4", "tips"]
---

This post will be updated to reflect some OCP4 tips & tricks:


# Scale routers

```
oc patch \
   --namespace=openshift-ingress-operator \
   --patch='{"spec": {"replicas": 1}}' \
   --type=merge \
   ingresscontroller/default
```

# Switch clusterversion channel

```
oc patch \
   --patch='{"spec": {"channel": "prerelease-4.1"}}' \
   --type=merge \
   clusterversion/version
```

# Upgrade cluster to latest

```
oc adm upgrade --to-latest
```

# Force the update to a specific version/hash

* Get the hash of the image version

```
CHANNEL='prerelease-4.1'
curl -sH 'Accept: application/json' "https://api.openshift.com/api/upgrades_info/v1/graph?channel=${CHANNEL}" | jq .
```

* Apply the update

```
oc adm upgrade --force=true --to-image=quay.io/openshift-release-dev/ocp-release@sha256:7e1e73c66702daa39223b3e6dd2cf5e15c057ef30c988256f55fae27448c3b01.
```

# Download and extract oc, kubectl and openshift-install one liner

```
curl -sL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux-${OCPVERSION}.tar.gz | sudo tar -C /usr/local/bin -xzf - oc kubectl
curl -sL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-install-linux-${OCPVERSION}.tar.gz | sudo tar -C /usr/local/bin -xzf - openshift-install
```

# Configure insecure registry

```
oc patch image.config.openshift.io/cluster -p \
'{"spec":{"allowedRegistriesForImport":[{"domainName":"my.own.registry.example.com:8888","insecure":true}],"registrySources":{"insecureRegistries":["my.own.registry.example.com:8888"]}}}'
```

# Get CRI-O settings

```
oc get containerruntimeconfig
```

# API resources

```
oc api-resources
```

## API resources per API group

```
oc api-resources --api-group config.openshift.io -o name
oc api-resources --api-group machineconfiguration.openshift.io -o name
```

# Explain resources

```
oc explain pods.spec.containers
```

## Explain resources per api group

```
oc explain --api-version=config.openshift.io/v1 scheduler
oc explain --api-version=config.openshift.io/v1 scheduler.spec
oc explain --api-version=config.openshift.io/v1 scheduler.spec.policy
oc explain --api-version=machineconfiguration.openshift.io/v1 containerruntimeconfigs
```

# Show console URL

```
oc whoami --show-console
```

# Show API url

```
oc whoami --show-server
```

# Cluster info

```
oc cluster-info
```

## Cluster info DUMP

```
oc cluster-info dump
```

# NTP configuration

RHCOS uses chronyd to synchronize the system time. The default configuration
uses the `*.rhel.pool.ntp.org` servers:

```
$ grep -v -E '^#|^$' /etc/chrony.conf
server 0.rhel.pool.ntp.org iburst
server 1.rhel.pool.ntp.org iburst
server 2.rhel.pool.ntp.org iburst
server 3.rhel.pool.ntp.org iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
```

As the hosts configuration shouldn't be managed manually, in order to configure
chronyd to use custom servers or a custom setting, it is required to use the
`machine-config-operator` to modify the files used by the masters and workers
by the following procedure:

* Create the proper file with your custom tweaks and encode it as base64:

```
cat << EOF | base64
server clock.redhat.com iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF
```

* Create the MachineConfig file with the base64 string from the previous command
as:

```
cat << EOF > ./masters-chrony-configuration.yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: master
  name: masters-chrony-configuration
spec:
  config:
    ignition:
    config: {}
      security:
        tls: {}
      timeouts: {}
      version: 2.2.0
    networkd: {}
    passwd: {}
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,c2VydmVyIGNsb2NrLnJlZGhhdC5jb20gaWJ1cnN0CmRyaWZ0ZmlsZSAvdmFyL2xpYi9jaHJvbnkvZHJpZnQKbWFrZXN0ZXAgMS4wIDMKcnRjc3luYwpsb2dkaXIgL3Zhci9sb2cvY2hyb255Cg==
          verification: {}
        filesystem: root
        mode: 420
        path: /etc/chrony.conf
  osImageURL: ""
EOF
```

Substitute the base64 string with your own.

* Apply it

```
oc apply -f ./masters-chrony-configuration.yaml
```

# OCP Master configuration
The master configuration is now stored in a `configMap`. During the installation
process, a few `configMaps` are created, so in order to get the latest:

```
oc get cm -n openshift-kube-apiserver | grep config
```

Observe the latest id and then:

```
oc get cm -n openshift-kube-apiserver config-ID
```

To get the output in a human-readable form, use:

```
oc get cm -n openshift-kube-apiserver config-ID \
  -o jsonpath='{.data.config\.yaml}' | jq
```

For the OpenShift api configuration:

```
oc get cm -n openshift-apiserver config -o jsonpath='{.data.config\.yaml}' | jq
```

# Delete 'Completed' pods

During the installation process, a few temporary pods are created. Keeping those
pods as 'Completed' doesn't harm nor waste resources but if you want to delete
them to have only 'running' pods in your environment you can use the following
command:

```
oc get pods --all-namespaces | \
  awk '{if ($4 == "Completed") system ("oc delete pod " $2 " -n " $1 )}'
```

# Get pods not running nor completed

A handy one liner to see the pods having issues (such as CrashLoopBackOff):

```
oc get pods --all-namespaces | grep -v -E 'Completed|Running'
```

# Debug node issues

OCP 4.1 is based on RHCOS and it is encouraged to not ssh into the hosts.
Instead:

```
oc debug node/<node>
...
chroot /host
cat /etc/redhat-release 
```
