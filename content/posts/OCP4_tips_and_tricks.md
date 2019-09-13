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
cat /host/etc/redhat-release
# If you want to use the node binaries you can:
# chroot /host
```

# Run debugging tools in the RHCOS hosts

```
oc debug node/<node>
chroot /host
podman run -it --name rhel-tools --privileged                       \
      --ipc=host --net=host --pid=host -e HOST=/host                \
      -e NAME=rhel-tools -e IMAGE=rhel7/rhel-tools                  \
      -v /run:/run -v /var/log:/var/log                             \
      -v /etc/localtime:/etc/localtime -v /:/host rhel7/rhel-tools
```

or you can specify the image used for the debug pod as:

```
oc debug node/<node> --image=rhel7/rhel-tools
```

This will allow you to run `tcpdump` and other tools. Use it with caution!!!

# Patch image pull policy

```
oc patch dc mydeployment -p '{"spec":{"template":{"spec":{"containers":[{"imagePullPolicy":"IfNotPresent","name":"mydeployment"}]}}}}'
```

# Sign all the pending `csr`

```
oc get csr -o name | xargs oc adm certificate approve
```

# Observe the SDN configuration

```
oc get cm sdn-config -o yaml -n openshift-sdn
```

Or:

```
oc exec -n openshift-sdn $(oc get pods -n openshift-sdn -l app=sdn --no-headers=true -o custom-columns=:metadata.name|head -n1) cat /config/{kube-proxy-config,sdn-config}.yaml
```

# Create objects using bash `here documents`

This is just an example of a `LoadBalancer` service, but it can be anything
yaml based!:

```
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: hello-openshift-lb
spec:
  externalTrafficPolicy: Cluster
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 8080
  selector:
    app: hello-openshift
  sessionAffinity: None
  type: LoadBalancer
EOF
```

# Disable auto rebooting after a change with the machine-config-operator

Every change performed by the `machine-config-operator` triggers a reboot in the
hosts where the change needs to be performed.

In the event of having a few changes to apply (such as modify NTP, registries,
etc.) and specially for baremetal scenarios, the auto reboot feature can be
paused by setting the `spec.paused` field in the `machineconfigpool` to true:

```
oc patch --type=merge --patch='{"spec":{"paused":true}}' machineconfigpool/master
```

# Wait for a machine-config to be applied

The `machineconfigpool` condition will be `updated` so we can wait for it as:

```
oc wait mcp/master --for condition=updated
```

# Update pull secret without reinstalling

The pull secret required to be able to pull images from the Red Hat registries
is stored in the `pull-secret` secret hosted in the `openshift-config`
namespace.

It is just a matter of modifying that secret with the updated one (in base64):

```
oc edit secret -n openshift-config pull-secret
```

NOTE: That secret is translated by the machine-config operator into the
`/var/lib/kubelet/config.json` file so in order to update it is required for the
hosts to be rebooted (which is done automatically by the mc operator)

# Get tags from a particular image in a particular container image registry

In order to get images from Red Hat's registries, it is required to have a
pull secret that contains base64 encoded tokens to reach those registries, such
as:

```
'{
   "auths":{
      "quay.io":{
         "auth":"xxx",
         "email":"xxx"
      },
      "registry.redhat.io":{
         "auth":"xxx",
         "email":"xxx"
      },
      "registry.example.com":{
         "auth":"xxx",
         "email":"xxx"
      },
   }
}'
```

First step is to get the token. We do this with this handy one liner:

```
REGISTRY=registry.example.com
echo $PULL_SECRET | jq -r ".auths.\"${REGISTRY}\".auth" | base64 -d | cut -d: -f2
```

Or, store it in an environment variable:

```
TOKEN=$(echo $PULL_SECRET | jq -r ".auths.\"${REGISTRY}\".auth" | base64 -d | cut -d: -f2)
```

Then we can use regular container image registry API queries:

```
curl -s -H  "Authorization: Bearer ${TOKEN}" https://${REGISTRY}/v2/_catalog
```

So, one liner to get the list of available tags for a particular image:

```
curl -s -H  "Authorization: Bearer $(echo $PULL_SECRET | jq -r '.auths."registry.example.com".auth' | base64 -d | cut -d: -f2)" https://registry.example.com/v2/eminguez/myawesomecontainer/tags/list | jq -r '.tags | .[]' | sort
```

# Apply sysctl tweaks to nodes

In order to modify sysctl parameters is recommended to create `machine configs`
to add those parameters in the `/etc/sysctl.d/` directory.

In this example, the `vm.max_map_count` parameter will be increased to `262144`
in the masters hosts:

```
cat << EOF | oc create -f -
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: master
  name: 99-sysctl-elastic
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          # vm.max_map_count=262144
          source: data:text/plain;charset=utf-8;base64,dm0ubWF4X21hcF9jb3VudD0yNjIxNDQ=
        filesystem: root
        mode: 0644
        path: /etc/sysctl.d/99-elasticsearch.conf
EOF
```

# Extract the OpenShift payloads (aka files, assets, etc.)

You just need your pull secret file and:

```
oc adm release extract --registry-config=./pull_secret.txt --from=quay.io/openshift-release-dev/ocp-release:4.1.15 --to=/tmp/mystuff
```

You can extract individual files such as the `oc` or the installer with the `--command` flag

# Get default StorageClass name

```
oc get sc -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'
```
