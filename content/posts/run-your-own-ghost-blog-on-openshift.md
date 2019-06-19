---
date: 2014-07-22T20:32:25Z
draft: false
tags: ["openshift", "ghost", "redhat"]
title: "Run your own Ghost blog on OpenShift"
---

Easy peasy:

* Create a [free OpenShift account](https://www.openshift.com/app/account/new)
* [Setup your environment](https://www.openshift.com/developers/rhc-client-tools-install)
* Run the following command:

```
rhc app create ghost nodejs-0.10 --env NODE_ENV=production --from-code https://github.com/openshift-quickstart/openshift-ghost-quickstart.git
```

* Profit

Check this [quickstart](https://www.openshift.com/quickstarts/ghost-on-openshift) for more information, and the awesome [OpenShift documentation](https://access.redhat.com/documentation/en-US/OpenShift_Online/)
