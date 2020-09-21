---
title: "Bash tips & tricks"
date: 2019-06-18T17:19:14+02:00
draft: false
tags: ["bash", "tips"]
---

# Bash variable with the content of a file

```
NTPFILECONTENT=$(cat /etc/chrony.conf)
```

This will store the '\n' characters as well.

# Display bash variable with the content of a file

```
echo "${NTPFILECONTENT}"
```

Beware the quotes

# Append content to a bash variable with a new line

```
NTPFILECONTENT="${NTPFILECONTENT}"$'\n'"pool ${ntp} iburst"
```

# Create files with heredocs

```
cat << EOF > /your/file
mycontent
  even with spaces
EOF
```

Some details:

* You can use EOF or whatever you want.
* The `EOF` needs to be as it is, no whitespace before it.
* If you don't want to interpret variables in the text, use single quotes such as:

```
cat << 'EOF' > /your/file
...
EOF
```

* In a shell script with tabs such as:

```
#!/usr/bin/env bash

if true ; then
    cat << EOF > /tmp/yourfilehere
my content
EOF
fi
```

you better use `<<- EOF` to disable leading tabs to make the code more readable:

```
#!/usr/bin/env bash

if true ; then
    cat <<- EOF > /tmp/yourfilehere
    mycontent
    EOF
fi
```

NOTE: You need to use tabs.

References:
* https://stackoverflow.com/a/2954835
* http://tldp.org/LDP/abs/html/here-docs.html 
