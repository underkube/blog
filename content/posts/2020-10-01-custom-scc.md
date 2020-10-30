---
title: "SCC assignments and permissions in OpenShift"
date: 2020-10-01T10:18:42+02:00
draft: false
tags: ["openshift", "scc", "permissions", "rbac"]
---

# SCCs

There are tons of information out there about SCCs, but in this post we will be
focused on how to create and use a custom SCC only.

See the OpenShift official documentation on [Managing Security Context Constraints](https://docs.openshift.com/container-platform/4.5/authentication/managing-security-context-constraints.html) for more details.

## Custom SCC

In the event of requiring a custom SCC, there are a few steps that need to be
done to be able to use the SCC properly.

### Minimal capabilities

The best way to create a custom SCC would be to build it based on the most
restricted one (hint: its name is `restricted`) and then start adding
capabilities and permissions depending on the application requisites.

In this example we are going to create a custom SCC based on the restricted one
but adding permissions to use hostpath:

```bash
cat << EOF | oc apply -f -
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
allowHostDirVolumePlugin: true
allowHostIPC: false
allowHostNetwork: false
allowHostPID: false
allowHostPorts: false
allowPrivilegeEscalation: true
allowPrivilegedContainer: false
allowedCapabilities: null
fsGroup:
  type: MustRunAs
metadata:
  name: mycustomscc
readOnlyRootFilesystem: false
requiredDropCapabilities:
- KILL
- MKNOD
- SETUID
- SETGID
runAsUser:
  type: MustRunAsRange
seLinuxContext:
  type: MustRunAs
supplementalGroups:
  type: RunAsAny
volumes:
- configMap
- downwardAPI
- emptyDir
- persistentVolumeClaim
- projected
- secret
- hostpath
EOF
```

NOTE: The SCC management procedures are restricted to the cluster-admin user
for security reasons.

## SCC assignation and permissions

In order to be able to use a custom SCC, it is required the user or
serviceaccount running the pod has access to the custom SCC.

This can be achieved in two different ways:

* Modifying the SCC to set users/groups.
* Using RBAC (roles, rolebindings, etc.)

But first, let's do a regular deployment:

```bash
oc login -u nonadmin -p whatever api.example.com
oc new-project myproject
oc create deployment hello-openshift --image=openshift/hello-openshift
```

Note: As an exercise, you can try to create those objects using just yaml files.

The pod will have the restricted SCC by default:

```bash
oc get po -l app=hello-openshift -o jsonpath='{.items[*].metadata.annotations.openshift\.io/scc}'
restricted
```

Let's create a serviceaccount:

```bash
oc create sa myserviceaccount
```

Note: As an exercise, you can try to create the service using just a yaml file.

And then, let's modify the deployment to use that serviceaccount instead:

```bash
oc set serviceaccount deployment/hello-openshift myserviceaccount
```

This will modify the deployment object to set the `serviceAccountName` parameter
(`serviceAccount` is currently deprecated, see `oc explain pod.spec` for more
information.)

Hint: You can use `oc patch` or `oc edit` as well.

```bash
oc get deployment hello-openshift -o jsonpath='{.spec.template.spec.serviceAccountName}'
myserviceaccount
```

Let's modify the deployment to use a hostPath volume:

```bash
oc patch deployment/hello-openshift -p '{"spec":{"template":{"spec":{"$setElementOrder/containers":[{"name":"hello-openshift"}],"containers":[{"name":"hello-openshift","volumeMounts":[{"mountPath":"/empty","name":"myvolume"}]}],"volumes":[{"hostPath":{"path":"/var/empty","type":"Directory"},"name":"myvolume"}]}}}}' deployment/hello-openshift
```

Hum... nothing happens... let's see the events:

```bash
oc get events
...
42s         Warning   FailedCreate        replicaset/hello-openshift-855649976d   Error creating: pods "hello-openshift-855649976d-" is forbidden: unable to validate against any security context constraint: [spec.volumes[0]: Invalid value: "hostPath": hostPath volumes are not allowed to be used]
```

It seems the pod is not allowed to use `hostPath`... as expected. This means we
need to give that serviceaccount permission to use the custom SCC.

## Method A: Modify the SCC definition

This method involves modifying the SCC to add the serviceaccount to the list of
users (or groups), as:

```bash
users:
- <user>
- system:serviceaccount:<namespace>:<serviceaccountname>
```

Assigning users, groups or service accounts directly to an SCC retains
cluster-wide scope and require cluster-admin permissions:

```bash
oc whoami
system:admin

oc patch scc mycustomscc --type=merge -p '{"users":["system:serviceaccount:myproject:myserviceaccount"]}'
```

Let's see now:

```bash
oc whoami
nonadmin

oc get po -l app=hello-openshift -o jsonpath='{.items[*].metadata.annotations.openshift\.io/scc}'
mycustomscc
```

Nice!

Before continuing, let's clean the SCC:

```bash
oc whoami
system:admin

oc patch scc mycustomscc --type=merge -p '{"users":[]}'
```

And remove the pod:

```bash
oc whoami
nonadmin

oc delete $(oc get po -o name -l app=hello-openshift)
```

## Method B: SCC RBAC

Since OpenShift 3.11, you can specify SCCs as a resource that is handled by
RBAC. This allows you to scope access to the SCCs to a certain project or to the
entire cluster.

This means that in order for the serviceaccount to use the SCC, you need to
create a role (or clusterrole) with the proper permissions and a rolebinding
(or clusterrolebinding) for the serviceaccount to that role. It sounds
complicated but it is not. Let's do it with just a single command:

```bash
oc whoami
system:admin

oc create role mycustomsccrole --verb=use --resource=scc --resource-name=mycustomscc -n myproject
```

This will create a role such as:

```bash
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: mycustomsccrole
  namespace: myproject
rules:
- apiGroups:
  - security.openshift.io
  resourceNames:
  - mycustomscc
  resources:
  - securitycontextconstraints
  verbs:
  - use
```

Note: You can create the role using the yaml file instead the `oc create role` command.

And we need to give access to that role to the serviceaccount (meaning, creating a rolebinding):

```bash
oc adm policy add-role-to-user mycustomsccrole -z myserviceaccount --role-namespace=myproject
```

This will create a rolebinding to link the service account to the role:

```bash
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: mycustomsccrole
  namespace: myproject
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: mycustomsccrole
subjects:
- kind: ServiceAccount
  name: myserviceaccount
  namespace: testscc
```

Note: You can create the rolebinding using the yaml file instead the `oc adm policy add-role-to-user` command.

To verify:

```bash
oc whoami
nonadmin

oc adm policy who-can use scc mycustomscc | grep myserviceaccount
        system:serviceaccount:myproject:myserviceaccount

oc get po -l app=hello-openshift -o jsonpath='{.items[*].metadata.annotations.openshift\.io/scc}'
mycustomscc
```

Nice!

NOTE: In recent versions of OCP (since https://github.com/openshift/oc/pull/412
was merged), the `oc adm policy add-scc-to-user` command creates a cluster role:

```bash
oc adm policy add-scc-to-user mycustomscc system:serviceaccount:myproject:myserviceaccount
clusterrole.rbac.authorization.k8s.io/system:openshift:scc:mycustomscc added: "myserviceaccount"

oc get clusterrole system:openshift:scc:mycustomscc -o yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system:openshift:scc:mycustomscc
rules:
- apiGroups:
  - security.openshift.io
  resourceNames:
  - mycustomscc
  resources:
  - securitycontextconstraints
  verbs:
  - use
```

And a `clusterrolebinding` to link that clusterrole with the service account:

```bash
oc get clusterrolebinding system:openshift:scc:mycustomscc -o yaml

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:openshift:scc:mycustomscc
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:openshift:scc:mycustomscc
subjects:
- kind: ServiceAccount
  name: myserviceaccount
  namespace: myproject
```

## Priorities

When a pod request is created, the admission controller evaluates the request
and assign an SCC depending on the permissions the pod requests as well as the
permissions the user/sa running this pod is allowed.

The SCCs have a `priority` field to affect the ordering. This means:

* Highest priority first, no priority is considered 0
* If priorities are equal, the SCCs will be sorted from most restrictive to least restrictive
* If both priorities and restrictions are equal the SCCs will be sorted by name

See [the admission controller code]
(https://github.com/openshift/apiserver-library-go/blob/master/pkg/securitycontextconstraints/sccadmission/admission.go)
if you are brave enough to understand it :)

The out-of-the-box SCCs included in OpenShift 4 and their priorities are:

```bash
oc get scc -o custom-columns=NAME:.metadata.name,PRIORITY:.priority
NAME                          PRIORITY
anyuid                        10
hostaccess                    <nil>
hostmount-anyuid              <nil>
hostnetwork                   <nil>
node-exporter                 <nil>
nonroot                       <nil>
privileged                    <nil>
restricted                    <nil>
```

## Warning about priorities

Some service accounts included by default in OpenShift are granted
cluster-admin permissions, meaning they can perform any action on any resource,
including using any SCC, despite of not having being granted it explicitly.

In our case, we only give access to the `myserviceaccount` service account to
use the `mycustomscc` SCC... but in fact, there are quite a few service accounts
allowed to use it:

```bash
oc adm policy who-can use scc mycustomscc
...
Users:  admin
        system:admin
        system:serviceaccount:myproject:myserviceaccount
        system:serviceaccount:openshift-apiserver-operator:openshift-apiserver-operator
        system:serviceaccount:openshift-apiserver:openshift-apiserver-sa
        system:serviceaccount:openshift-authentication-operator:authentication-operator
        system:serviceaccount:openshift-authentication:oauth-openshift
        system:serviceaccount:openshift-cluster-node-tuning-operator:cluster-node-tuning-operator
        system:serviceaccount:openshift-cluster-storage-operator:csi-snapshot-controller-operator
        system:serviceaccount:openshift-cluster-version:default
        system:serviceaccount:openshift-config-operator:openshift-config-operator
        system:serviceaccount:openshift-controller-manager-operator:openshift-controller-manager-operator
        system:serviceaccount:openshift-etcd-operator:etcd-operator
        system:serviceaccount:openshift-etcd:installer-sa
        system:serviceaccount:openshift-kube-apiserver-operator:kube-apiserver-operator
        system:serviceaccount:openshift-kube-apiserver:installer-sa
        system:serviceaccount:openshift-kube-apiserver:localhost-recovery-client
        system:serviceaccount:openshift-kube-controller-manager-operator:kube-controller-manager-operator
        system:serviceaccount:openshift-kube-controller-manager:installer-sa
        system:serviceaccount:openshift-kube-controller-manager:localhost-recovery-client
        system:serviceaccount:openshift-kube-scheduler-operator:openshift-kube-scheduler-operator
        system:serviceaccount:openshift-kube-scheduler:installer-sa
        system:serviceaccount:openshift-kube-scheduler:localhost-recovery-client
        system:serviceaccount:openshift-kube-storage-version-migrator-operator:kube-storage-version-migrator-operator
        system:serviceaccount:openshift-kube-storage-version-migrator:kube-storage-version-migrator-sa
        system:serviceaccount:openshift-machine-config-operator:default
        system:serviceaccount:openshift-network-operator:default
        system:serviceaccount:openshift-operator-lifecycle-manager:olm-operator-serviceaccount
        system:serviceaccount:openshift-service-ca-operator:service-ca-operator
        system:serviceaccount:openshift-service-catalog-removed:openshift-service-catalog-apiserver-remover
        system:serviceaccount:openshift-service-catalog-removed:openshift-service-catalog-controller-manager-remover
Groups: system:cluster-admins
        system:masters
```

This means any of those serviceaccounts can effectively use the custom SCC and
if the priority is higher than the one intended to be used, things can go wrong.
For more information see [this KCS article](https://access.redhat.com/solutions/4727461)

Let's see it in action. Modify the `mycustomscc` to have higher priority than
the default ones (any number higher than 10 would be enough... let's choose 99):

```bash
oc patch scc mycustomscc --type merge -p '{"priority":99}'

oc get scc mycustomscc -o jsonpath='{.priority}'
99
```

Now, let's force the admission controller to 'recalculate' the SCCs for one of
the serviceaccounts that can use any SCC. In this example, we will choose one of
the oauth pods:

```bash
oc get po -n openshift-authentication
NAME                               READY   STATUS             RESTARTS   AGE
oauth-openshift-5c4466d8f6-djg89   1/1     Running            0          3d4h
oauth-openshift-5c4466d8f6-hrrkf   1/1     Running            0          3d4h

oc get po -n openshift-authentication -o jsonpath='{range .items[*]}{.metadata.annotations.openshift\.io/scc}{"\t"}{.metadata.name}{"\t"}{.metadata.namespace}{"\n"}{end}'
anyuid	oauth-openshift-5c4466d8f6-djg89	openshift-authentication
anyuid	oauth-openshift-5c4466d8f6-hrrkf	openshift-authentication

oc get deploy -n openshift-authentication oauth-openshift -o jsonpath='{.spec.template.spec.serviceAccountName}'
oauth-openshift

oc adm policy who-can use scc mycustomscc | grep oauth-openshift
        system:serviceaccount:openshift-authentication:oauth-openshift
```

They are using the `anyuid` SCC, but they can use any... and based on the order,
`mycustomscc` will win:

```bash
oc get scc -o custom-columns=NAME:.metadata.name,PRIORITY:.priority
NAME                          PRIORITY
anyuid                        10
hostaccess                    <nil>
hostmount-anyuid              <nil>
hostnetwork                   <nil>
mycustomscc                   99
node-exporter                 <nil>
nonroot                       <nil>
privileged                    <nil>
restricted                    <nil>
```

Let's see:

```bash
oc delete po oauth-openshift-5c4466d8f6-hrrkf

oc get po
NAME                               READY   STATUS             RESTARTS   AGE
oauth-openshift-5c4466d8f6-djg89   1/1     Running            0          3d4h
oauth-openshift-5c4466d8f6-wq7cv   0/1     CrashLoopBackOff   6          7m45s

oc get po -n openshift-authentication -o jsonpath='{range .items[*]}{.metadata.annotations.openshift\.io/scc}{"\t"}{.metadata.name}{"\t"}{.metadata.namespace}{"\n"}{end}'
anyuid	oauth-openshift-5c4466d8f6-djg89	openshift-authentication
mycustomscc	oauth-openshift-5c4466d8f6-wq7cv	openshift-authentication
```

Ooops, we just broke our cluster... the admission controller choose the
`mycustomscc` SCC instead the `anyuid` one and now the pod is not able to run.
Let's fix it by lowering the priority of our custom SCC:

```bash
oc patch scc mycustomscc --type merge -p '{"priority":9}'
oc delete po oauth-openshift-5c4466d8f6-wq7cv
oc get po
NAME                               READY   STATUS    RESTARTS   AGE
oauth-openshift-5c4466d8f6-djg89   1/1     Running   0          3d4h
oauth-openshift-5c4466d8f6-tbphl   1/1     Running   0          46s

oc get po -n openshift-authentication -o jsonpath='{range .items[*]}{.metadata.annotations.openshift\.io/scc}{"\t"}{.metadata.name}{"\t"}{.metadata.namespace}{"\n"}{end}'
anyuid	oauth-openshift-5c4466d8f6-djg89	openshift-authentication
anyuid	oauth-openshift-5c4466d8f6-tbphl	openshift-authentication
```

PHEW!
