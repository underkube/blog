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
