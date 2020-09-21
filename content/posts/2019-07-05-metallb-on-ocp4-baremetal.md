---
title: "metallb on OCP4 baremetal"
date: 2019-07-05T17:19:14+02:00
draft: false
tags: ["openshift", "kubernetes", "metallb"]
---

UPDATE: I submitted a [PR](https://github.com/danderson/metallb/pull/447) to the MetalLB docs on how to deploy MetalLB on OpenShift 4 and it has been merged \o/ so hopefully it will be live soon.

ORIGINAL BLOG POST:
--8<--

This blog post illustrates my steps to deploy [metallb](https://metallb.universe.tf/) on [OCP4](https://www.redhat.com/en/openshift-4) running
on baremetal.

# Environment

I have an OCP4 environment running in a Red Hat lab using 3 baremetal hosts
as masters + workers deployed using [openshift-metal3/dev-scripts](https://github.com/openshift-metal3/dev-scripts)

Some details:

```shell
oc get nodes
NAME                                         STATUS   ROLES    AGE   VERSION
myocp-master-0.example.com   Ready    master   18m   v1.14.0+04ae0f405
myocp-master-1.example.com   Ready    master   17m   v1.14.0+04ae0f405
myocp-master-2.example.com   Ready    master   17m   v1.14.0+04ae0f405

oc version
Client Version: version.Info{Major:"4", Minor:"2+", GitVersion:"v4.2.0", GitCommit:"8c1091692", GitTreeState:"clean", BuildDate:"2019-07-04T14:28:25Z", GoVersion:"go1.12.6", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"14+", GitVersion:"v1.14.0+79e4284", GitCommit:"79e4284", GitTreeState:"clean", BuildDate:"2019-06-19T09:08:08Z", GoVersion:"go1.12.5", Compiler:"gc", Platform:"linux/amd64"}
```

# MetalLB installation

This is pretty straightforward, just follow the [installation guide](https://metallb.universe.tf/installation/):

```shell
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml
```

BUT... there are some changes that are required to fit OpenShift 4 security
requirements.

## Hardcoded user ID

The `controller` deployment has a [hardcoded](https://github.com/danderson/metallb/blob/master/manifests/metallb.yaml#L240) user ID to run As (65534).

```
15s         Warning   FailedCreate        replicaset/controller-cd8657667   Error creating: pods "controller-cd8657667-" is forbidden: unable to validate against any security context constraint: [spec.containers[0].securityContext.securityContext.runAsUser: Invalid value: 65534: must be in the ranges: [1000500000, 1000509999]]
```

In OCP every project/namespace has its own user IDs assigned:

```shell
oc get project metallb-system -o yaml | grep uid-range
    openshift.io/sa.scc.uid-range: 1000500000/10000
```

Let's fix it:

```shell
oc patch \
--namespace=metallb-system \
--patch='{"spec":{"template":{"spec":{"securityContext":{"runAsUser":null}}}}}'\
--type=merge \
deploy/controller
```

## `speaker` requires privileged

The `speaker` daemonset requires [`net_raw`](https://github.com/danderson/metallb/blob/master/manifests/metallb.yaml#L207) and [`hostNetwork: true`](https://github.com/danderson/metallb/blob/master/manifests/metallb.yaml#L178)

```
26s         Warning   FailedCreate        daemonset/speaker                  Error creating: pods "speaker-" is forbidden: unable to validate against any security context constraint: [provider restricted: .spec.securityContext.hostNetwork: Invalid value: true: Host network is not allowed to be used capabilities.add: Invalid value: "net_raw": capability may not be added spec.containers[0].securityContext.hostNetwork: Invalid value: true: Host network is not allowed to be used spec.containers[0].securityContext.containers[0].hostPort: Invalid value: 7472: Host ports are not allowed to be used]
```

Add the privileged scc to the speaker SA:

```shell
oc adm policy add-scc-to-user privileged -n metallb-system -z speaker
```

# Configuration

After a few seconds, the pods are deployed:

```shell
oc get pods
NAME                          READY   STATUS    RESTARTS   AGE
controller-5579c87d75-487xt   1/1     Running   0          3m4s
speaker-4vhh4                 1/1     Running   0          107s
speaker-9tfhr                 1/1     Running   0          107s
speaker-lhfxb                 1/1     Running   0          107s
```

MetalLB can be configured in two different ways:

* BGP configuration. It requires messing with BGP routers, etc. You can read more of this mode in the [official documentation site](https://metallb.universe.tf/concepts/bgp/)
* Layer2 configuration. Much more simple to configure and use. More information [here](https://metallb.universe.tf/concepts/layer2/)

I will focus on the layer2 configuration as it doesn't require router
modifications. If you are curious (you should) there are plenty of details on
how it works under the hood in the previous links (including ARP, BGP,
limitations of each mode, etc.)

## Layer2 mode

As a good k8s citizen, metallb is configured using a `configmap`. The basic
configuration is just the address pool that metallb is allowed to use and mine
looks like:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: my-ip-space
      protocol: layer2
      addresses:
      - 10.19.140.10-10.19.140.29
```

**NOTE:** Those IPs shall be available for metallb to use it!

So, it is only required to create the `configmap` as:

```shell
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: my-ip-space
      protocol: layer2
      addresses:
      - 10.19.140.10-10.19.140.29
EOF
```

# Usage

Let's create a simple application and see how it works:

```shell
oc new-project my-test-app
oc new-app openshift/hello-openshift
```

After a few seconds, a basic 'hello world' is deployed.

```shell
oc get all

NAME                           READY   STATUS      RESTARTS   AGE
pod/hello-openshift-1-deploy   0/1     Completed   0          30s
pod/hello-openshift-1-vjbnp    1/1     Running     0          18s

NAME                                      DESIRED   CURRENT   READY   AGE
replicationcontroller/hello-openshift-1   1         1         1       30s

NAME                      TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)             AGE
service/hello-openshift   ClusterIP   172.30.224.138   <none>        8080/TCP,8888/TCP   31s

NAME                                                 REVISION   DESIRED   CURRENT   TRIGGERED BY
deploymentconfig.apps.openshift.io/hello-openshift   1          1         1         config,image(hello-openshift:latest)

NAME                                             IMAGE REPOSITORY                                                               TAGS     UPDATED
imagestream.image.openshift.io/hello-openshift   image-registry.openshift-image-registry.svc:5000/my-test-app/hello-openshift   latest   30 seconds ago
```

Let's create a `LoadBalancer` service to expose it to the outside world using
metallb:

```shell
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
    deploymentconfig: hello-openshift
  sessionAffinity: None
  type: LoadBalancer
EOF
```

Let's see if it worked:

* `speaker` logs:

```
{"caller":"announcer.go:89","event":"createARPResponder","interface":"veth296608cb","msg":"created ARP responder for interface","ts":"2019-07-05T15:36:55.435037499Z"}
{"caller":"announcer.go:94","error":"creating NDP responder for \"veth296608cb\": listen ip6:ipv6-icmp fe80::b8ba:dbff:fe2a:5%veth296608cb: bind: invalid argument","interface":"veth296608cb","msg":"failed to create NDP responder","op":"createNDPResponder","ts":"2019-07-05T15:36:55.435317953Z"}
{"caller":"announcer.go:94","error":"creating NDP responder for \"veth296608cb\": listen ip6:ipv6-icmp fe80::b8ba:dbff:fe2a:5%veth296608cb: bind: invalid argument","interface":"veth296608cb","msg":"failed to create NDP responder","op":"createNDPResponder","ts":"2019-07-05T15:37:05.535397065Z"}
{"caller":"announcer.go:98","event":"createNDPResponder","interface":"veth296608cb","msg":"created NDP responder for interface","ts":"2019-07-05T15:37:16.341219543Z"}
{"caller":"announcer.go:106","event":"deleteARPResponder","interface":"veth97916e2f","msg":"deleted ARP responder for interface","ts":"2019-07-05T15:37:16.341323886Z"}
{"caller":"main.go:159","event":"startUpdate","msg":"start of service update","service":"my-test-app/hello-openshift-lb","ts":"2019-07-05T15:37:26.235245349Z"}
{"caller":"main.go:229","event":"serviceAnnounced","ip":"10.19.140.10","msg":"service has IP, announcing","pool":"my-ip-space","protocol":"layer2","service":"my-test-app/hello-openshift-lb","ts":"2019-07-05T15:37:26.235402196Z"}
{"caller":"main.go:231","event":"endUpdate","msg":"end of service update","service":"my-test-app/hello-openshift-lb","ts":"2019-07-05T15:37:26.235446088Z"}
```

The errors are because it is trying to use IPV6, but I'm ok with not using it.

* Service details:

```shell
oc describe svc hello-openshift-lb
Name:                     hello-openshift-lb
Namespace:                my-test-app
Labels:                   <none>
Annotations:              kubectl.kubernetes.io/last-applied-configuration:
                            {"apiVersion":"v1","kind":"Service","metadata":{"annotations":{},"name":"hello-openshift-lb","namespace":"my-test-app"},"spec":{"externalT...
Selector:                 deploymentconfig=hello-openshift
Type:                     LoadBalancer
IP:                       172.30.250.196
LoadBalancer Ingress:     10.19.140.10
Port:                     http  80/TCP
TargetPort:               8080/TCP
NodePort:                 http  32109/TCP
Endpoints:                10.129.0.51:8080
Session Affinity:         None
External Traffic Policy:  Cluster
Events:
  Type    Reason       Age   From                Message
  ----    ------       ----  ----                -------
  Normal  IPAllocated  113s  metallb-controller  Assigned IP "10.19.140.10"
```

* Curl it!

```shell
curl 10.19.140.10
Hello OpenShift!
```

**SUCCESS!**
