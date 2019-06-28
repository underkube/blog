---
date: 2015-05-14T10:20:50Z
draft: false
title: "OpenLDAP basic installation for OpenStack"
---

* Install openldap

```
yum install -y openldap-servers openldap-clients
```

* Start the service

```
systemctl start slapd
```

* Add the cosine and inetorgperson schemas:

```
ldapadd -H ldapi:/// -Y EXTERNAL -f /etc/openldap/schema/cosine.ldif
ldapadd -H ldapi:/// -Y EXTERNAL -f /etc/openldap/schema/inetorgperson.ldif
```

* Create a temporary config directory where the files will be placed:

```
mkdir -p /root/ldapconf && cd /root/ldapconf
```

* Create the memberof overlay file:

```
cat >./memberof.ldif<<EOF
dn: cn={0}module,cn=config
objectClass: olcModuleList
cn: {0}module
olcModulePath: /usr/lib64/openldap
olcModuleLoad: {0}memberof.la

dn: olcOverlay={0}memberof,olcDatabase={2}hdb,cn=config
objectClass: olcConfig
objectClass: olcMemberOf
objectClass: olcOverlayConfig
objectClass: top
olcOverlay: {0}memberof
EOF
```

* Add it:

```
ldapadd -H ldapi:/// -Y EXTERNAL -f ./memberof.ldif
```

* Set a DN password (redhat in this case)

```
MANAGERPASSWORD=$(slappasswd -h {SSHA} -s redhat)
```

* Create a manager.ldif file to create a Manager user:

```
cat >./manager.ldif<<EOF
dn:  olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcSuffix
olcSuffix: dc=openstack,dc=org
-
replace: olcRootDN
olcRootDN: cn=Manager,dc=openstack,dc=org
-
add: olcRootPW
olcRootPW: ${MANAGERPASSWORD}
EOF
```

* Add the manager ldif

```
ldapmodify -Y EXTERNAL -H ldapi:/// -f ./manager.ldif
```

* Create an openstack schema:

```
cat >./openstack_schema.ldif<<EOF
dn: dc=openstack,dc=org
dc: openstack
objectClass: dcObject
objectClass: organization
o: openstack

dn: ou=Groups,dc=openstack,dc=org
objectClass: top
objectClass: organizationalUnit
ou: groups

dn: ou=Users,dc=openstack,dc=org
objectClass: top
objectClass: organizationalUnit
ou: users

dn: ou=Roles,dc=openstack,dc=org
objectClass: top
objectClass: organizationalUnit
ou: roles
EOF
```

* Add it:

```
ldapadd -x -D"cn=Manager,dc=openstack,dc=org" \
 -H ldap://localhost -f ./openstack_schema.ldif -W
```

* Check it just in case:

```
ldapsearch -x -W -D"cn=Manager,dc=openstack,dc=org" \
  -b "dc=openstack,dc=org" "(objectclass=*)"
```

* Create an admin user:

```
ADMINPASSWORD=$(slappasswd -h {SSHA} -s redhat)
cat >./admin.ldif<<EOF
dn: uid=admin,ou=Users,dc=openstack,dc=org
objectclass: inetOrgPerson
objectclass: uidObject
uid: admin
cn: admin
givenName: admin
title: admin
mail: admin@openstack.org
sn: admin
userPassword: ${ADMINPASSWORD}
EOF
```

* Add it:

```
ldapadd -x -D"cn=Manager,dc=openstack,dc=org" \
  -H ldap://localhost -f ./admin.ldif -W
```

* Check it:

```
ldapsearch -x -W -D"uid=admin,ou=Users,dc=openstack,dc=org" \
  -b "ou=Users,dc=openstack,dc=org" "(objectclass=*)"
```

* Create the "enabled_users" group and add the admin user:

```
cat >./enabled_users.ldif<<EOF
dn: cn=enabled_users,ou=Groups,dc=openstack,dc=org
objectclass: groupOfNames
cn: EnabledUsers
member: uid=admin,ou=Users,dc=openstack,dc=org
EOF
```

* Add it:

```
ldapadd -x -D"cn=Manager,dc=openstack,dc=org" \
  -H ldap://localhost -W -f ./enabled_users.ldif
```
