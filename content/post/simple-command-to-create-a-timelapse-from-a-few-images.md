---
date: 2014-09-16T18:23:46Z
draft: false
tags: ["ffmpeg", "timelapse", "tip"]
title: "Simple command to create a timelapse from a few images"
---

```
cat *jpg* | ffmpeg -f image2pipe -r 30 -vcodec mjpeg -i - -vcodec libx264 out.mp4
```
