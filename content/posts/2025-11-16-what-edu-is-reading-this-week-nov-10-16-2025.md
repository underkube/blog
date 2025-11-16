---
title: "What Edu is Reading This Week (Nov 10-16 2025)"
date: 2025-11-16T8:30:00+00:00
draft: false
tags: ["links", "weekly", "kubernetes", "linux", "security", "devops", "hardware"]
description: A list of links I found interesting this week (Nov 10 - 16, 2025)
---

## What Edu is Reading This Week

Fifth week in a row!

---

## Cloud Native & Kubernetes

* [**Ingress-Nginx Controller Retirement (K8s Blog)**](https://www.kubernetes.dev/blog/2025/11/12/ingress-nginx-retirement/): Official announcement regarding the planned retirement and deprecation of the classic `ingress-nginx` controller, signaling the industry shift toward the Gateway API.

* [**ingress2gateway**](https://github.com/kubernetes-sigs/ingress2gateway): A tool from the Kubernetes SIGs to automatically migrate existing Ingress resources to the newer, more powerful Kubernetes Gateway API.

* [**Helm Documentation Overview**](https://helm.sh/docs/overview/): The official overview page for Helm 4, the package manager for Kubernetes that announced its 4.0.0 version at Kubecon this week.

* [**Sprout: The Rust-Powered Bootloader**](https://edera.dev/stories/sprout-the-rust-powered-open-source-bootloader-for-the-cloud-native-era): An open-source, **Rust-based bootloader** designed specifically for modern, cloud-native environments and fast startup times.

## Linux, Booting & Containers

* [**openSUSE Tumbleweed GRUB 2 BLS Update**](https://news.opensuse.org/2025/11/13/tw-grub2-bls/): News about openSUSE Tumbleweed switching to the GRUB 2 Boot Loader Specification (BLS) for simpler, more modern boot configuration.

* [**UEFI Linux Booting Deep Dive**](https://github.com/apgarcia/sysadmin-topics/blob/main/uefi-linux-booting.md): Comprehensive guide explaining the UEFI boot process on Linux, from firmware initialization to the kernel.

* [**IncusOS Announced**](https://www.phoronix.com/news/Incus-IncusOS-Announced) / [**Announcing IncusOS (Discussion)**](https://discuss.linuxcontainers.org/t/announcing-incusos/25139): Phoronix coverage and the original discussion thread announcing IncusOS, an operating system built around the Incus (LXD fork) container/VM management platform.

* [**Linux Kernel discussion about providing guidelines for tool-generated content**](https://lore.kernel.org/all/20251105231514.3167738-1-dave.hansen@linux.intel.com/): A kernel mailing list post discussing the rules of the usage of AI tools used to contribute to the kernel.

* [**rtc: rk808: Compensate for Rockchip calendar deviation on November 31st**](https://lobste.rs/s/nyd4p0/rtc_rk808_compensate-for-rockchip): A Lobsters discussion on kernel patches related to compensating for Real-Time Clock (RTC) issues with the Rockchip RK808 chip.

* [**GRUB 2 BLS Debugging**](https://gist.github.com/omid/4bee9bfc838d3a3b0c6febc42c74ed8f): A Gist offering a script to identify unused linux-firmware-\* packages on Arch Linux (Use at your own risk).

## Security & Encryption

* [**Emergency Self-Destruction for LUKS in Kali**](https://www.kali.org/blog/emergency-self-destruction-luks-kali/): A detailed guide from Kali Linux on setting up a panic password to securely wipe the LUKS master key for encrypted volumes.

* [**cryptsetup-nuke-password**](https://salsa.debian.org/pkg-security-team/cryptsetup-nuke-password): The Debian package that enables the "emergency self-destruction" password feature for LUKS encrypted volumes.

## DevOps & Tools

* [**Homebrew 5.0.0 Release**](https://brew.sh/2025/11/12/homebrew-5.0.0/): Announcement of the major 5.0.0 release for Homebrew, the essential package manager for macOS and Linux.

* [**HTTP Time Machine (httm)**](https://github.com/kimono-koans/httm): An interactive, file-level **Time Machine-like tool** for ZFS primarily used to browse, restore, and prune files on snapshots and much more!

* [**MacPINE**](https://beringresearch.github.io/macpine/): A utility to run Alpine Linux virtual machines quickly and efficiently on **macOS**, perfect for testing and minimal development environments.

* [**GitHub Spec Kit**](https://github.com/github/spec-kit): An open source toolkit that allows you to focus on product scenarios and predictable outcomes instead of vibe coding every piece from scratch.

## Programming & Learning

* [**DeepWiki**](https://deepwiki.com/): An AI-powered tool that generates interactive documentation for code repositories on platforms like GitHub.

* [**Google Code Wiki**](https://codewiki.google/): Like DeepWiki, but by Google.

* [**Dive Into Python 3**](https://diveintopython3.net/): A classic, free, and comprehensive online book for learning Python 3.

* [**Think Python**](https://allendowney.github.io/ThinkPython/): A free book by Allen Downey focused on computational thinking and programming with Python.

* [**Raspberry Pi User Guide: Complete Tutorials & Projects**](https://ohyaan.github.io/): Quoting: "the ultimate Raspberry Pi resource!"

## Hardware & Hobby Tech

* [**Backblaze Drive Stats Q3 2025**](https://www.backblaze.com/blog/backblaze-drive-stats-for-q3-2025): The latest quarterly report from Backblaze on hard drive failure rates, reliability, and statistics—a must-read before your next hardware purchase.

* [**hjberndt ATS Mini v4 alternative firmware**](http://www.hjberndt.de/dvb/pocketSI4735DualCoreDecoder.html): ATS Mini v4 alternative firmware.

* [**ATS-Mini**](https://atsmini.github.io/) / [**ESP32 SI4732 ATS-Mini Build**](https://esp32-si4732.github.io/ats-mini/): The main project page and specific documentation for building the ATS-Mini, a portable, open-source radio receiver project using an ESP32.

## News & Community

* [**FFmpeg to Google: Fund Us or Stop Sending Bugs**](https://thenewstack.io/ffmpeg-to-google-fund-us-or-stop-sending-bugs/): An article covering the public request by the FFmpeg project for funding support from companies (like Google) that heavily utilize their code after Google reported vulernabilities that the FFmpeg team is not able to fix in time.

* [**Android Power Users to Bypass Sideloading Restrictions**](https://arstechnica.com/gadgets/2025/11/google-will-let-android-power-users-bypass-upcoming-sideloading-restrictions/): News about Google's plan to allow technical users to opt out of new security restrictions on app sideloading in Android.

* [**Drone and AI Combat Helmet**](https://www.reddit.com/r/interestingasfuck/comments/1owkdbp/drone_and_ai_combat_helmet_let_soldiers_see/): A Reddit thread discussing new technology that integrates drone feeds and AI analysis into a soldier's helmet for enhanced vision.

* [**Failed attempt to replicate the Range Rover "Stairway to Heaven" climb (Video)**](https://x.com/CollinRugg/status/1989018266904457260?s=20): Chinese automaker appears to try recreating the viral Range Rover "Stairway to Heaven" climb, crashes through guardrail.

* [**Tweeks – Browser extension to deshittify the web (HN discussion)**](https://news.ycombinator.com/item?id=45916525): I personally love the idea but I didn't installed it because it seems a huge privacy hole. The concept is cool though!
