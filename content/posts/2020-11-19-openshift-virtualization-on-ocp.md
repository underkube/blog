---
title: "Deploy OpenShift Virtualization 2.5 on OCP 4.6.1 on baremetal IPI"
date: 2020-11-19T09:30:42+02:00
draft: false
tags: ["openshift", "virtualization", "baremetal", "ipi"]
---

### Preparation

Ensure your workers have the virtualization flag enabled:

```bash
for node in $(oc get nodes -o name | grep kni1-worker); do
  oc debug ${node} -- grep -c -E 'vmx|svm' /host/proc/cpuinfo
done
```

That snippet should return the number of cpu cores with virtualization enabled
(it should be all of them).

### Subscription

```bash
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-cnv
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: kubevirt-hyperconverged-group
  namespace: openshift-cnv
spec:
  targetNamespaces:
    - openshift-cnv
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: hco-operatorhub
  namespace: openshift-cnv
spec:
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  name: kubevirt-hyperconverged
  startingCSV: kubevirt-hyperconverged-operator.v2.5.0
  channel: "stable"
EOF
```

Hyperconverged object:

```bash
cat <<EOF | oc apply -f -
apiVersion: hco.kubevirt.io/v1beta1
kind: HyperConverged
metadata:
  name: kubevirt-hyperconverged
  namespace: openshift-cnv
spec:
  BareMetalPlatform: true
EOF
```

Download the `virtctl` cli from https://access.redhat.com/downloads/content/473
then:

```bash
tar -xOzf kubevirt-*.tar.gz kubevirt*/usr/share/kubevirt/linux/virtctl > virtctl
chmod a+x ./virtctl
sudo mv ./virtctl /usr/local/bin/virtctl
sudo restorecon /usr/local/bin/virtctl
rm -f kubevirt-*.tar.gz
```

### My first VM

Let's create a namespace to host the first VM:

```bash
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: my-first-vm
spec: {}
---
apiVersion: kubevirt.io/v1alpha3
kind: VirtualMachine
metadata:
  name: my-first-vm
  namespace: my-first-vm
spec:
  running: true
  template:
    metadata:
      labels: 
        kubevirt.io/size: small
        kubevirt.io/domain: myfirstvm
    spec:
      domain:
        devices:
          disks:
          - disk:
              bus: virtio
            name: rootfs
          - disk:
              bus: virtio
            name: cloudinit
          interfaces:
          - name: default
            masquerade: {}
        resources:
          requests:
            memory: 64M
      networks:
      - name: default
        pod: {}
      volumes:
        - name: rootfs
          containerDisk:
            image: kubevirt/cirros-registry-disk-demo
        - name: cloudinit
          cloudInitNoCloud:
            userDataBase64: SGkuXG4=
EOF
```

Connect to the new VM:

```bash
virtctl console -n my-first-vm my-first-vm

Successfully connected to my-test-vm console. The escape sequence is ^]

login as 'cirros' user. default password: 'gocubsgo'. use 'sudo' for root.
my-test-vm login: cirros
Password: gocubsgo
$ cat /etc/cirros/version
0.4.0
```

Note: To exit the console press CTRL + ALT + ]

### References

* https://docs.openshift.com/container-platform/4.6/virt/install/installing-virt-cli.html
* https://github.com/kubevirt/demo
