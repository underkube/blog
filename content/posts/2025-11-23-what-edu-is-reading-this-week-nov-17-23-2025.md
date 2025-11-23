---
title: "What Edu is Reading This Week (Nov 17-23 2025)"
date: 2025-11-23T8:30:00+00:00
draft: false
tags: ["links", "weekly", "kubernetes", "linux", "security", "devops", "hardware"]
description: "The links I've collected this week: from Kubernetes swap tuning and Podman Quadlets to RavynOS and DIY audio hardware."
---

## What Edu is Reading This Week

Plenty of content this week!

---

## Cloud Native & Kubernetes

* [**Tuning Linux Swap for Kubernetes**](https://kubernetes.io/blog/2025/08/19/tuning-linux-swap-for-kubernetes-a-deep-dive/): A deep-dive article on why and how to correctly configure and tune Linux swap settings when running Kubernetes workloads.

* [**Production-Grade Container Deployment with Podman Quadlets**](https://blog.hofstede.it/production-grade-container-deployment-with-podman-quadlets/?t=_JB484HHW08qoOcRH-pshQ&s=09): How to deploy and manage containers using Podman and Quadlets, which leverage native `systemd` unit files for production-ready setups.

* [**Security Contexts in Kubernetes**](https://learnkube.com/security-contexts): A breakdown of Kubernetes Security Contexts, covering settings like `runAsUser`, capabilities, and SELinux options to tighten pod security.

* [**A Small Vanilla Kubernetes Install on NixOS**](https://stephank.nl/p/2025-11-17-a-small-vanilla-kubernetes-install-on-nixos.html): A guide to setting up a _minimalist_, declarative Kubernetes cluster using the NixOS operating system (too complex if you ask me).

* [**etcd Hardware Requirements**](https://etcd.io/docs/v3.5/op-guide/hardware/): The official etcd documentation on hardware considerations (especially disk speed and network latency) for optimal performance and cluster stability.

## Linux, Booting & Systems

* [**RavynOS: The macOS-like OS on a FreeBSD Kernel**](https://ravynos.com/): The project page for RavynOS, an operating system that aims to achieve macOS-like design and application compatibility using the FreeBSD kernel.

* [**We're (now) moving from OpenBSD to FreeBSD for firewalls**](https://utcc.utoronto.ca/~cks/space/blog/sysadmin/OpenBSDToFreeBSDMove): The author is moving their firewalls and VPN servers from OpenBSD to FreeBSD because FreeBSD offers clearly superior network performance, particularly on a 10G network, despite OpenBSD having served them well for years.

* [**Why the BSDs?**](https://blog.thechases.com/posts/why-bsds/): A philosophical and technical discussion on the key differentiators and advantages of using the various BSD operating systems.

* [**Static Web Hosting Performance Comparison**](https://it-notes.dragas.net/2025/11/19/static-web-hosting-intel-n150-freebsd-smartos-netbsd-openbsd-linux/): A performance comparison of serving static web files across FreeBSD, SmartOS, NetBSD, OpenBSD, and Linux on low-power Intel hardware.

* [**systemd.preset Man Page**](https://www.freedesktop.org/software/systemd/man/latest/systemd.preset.html): Official documentation for `systemd.preset`, which defines default enablement/disablement policies for services at installation time.

* [**Setting up Software TPM (swtpm) for Libvirt VMs**](https://wiki.wuji.cz/services:libvirt:swtpm): A small post on how to install swtpm to provide TPM emulation capabilities to libvirt VMs (I wasn't aware swtpm even existed!).

## DevOps & Tools

* [**Spec-Driven Development for Infrastructure Automation**](https://thenewstack.io/is-spec-driven-development-key-for-infrastructure-automation/): An article exploring the methodology of using clear, formal specifications (like APIs or schema) to drive the automated creation and management of infrastructure. I'm both amazed and scared about SDD.

* [**Terraform Provider for OpenWrt**](https://linderud.dev/blog/easter-hack-terraform-provider-openwrt/): A fun hack/project that creates a custom Terraform provider to manage OpenWrt router configurations declaratively.

* [**Self-Hosting DNS for No Fun But a Little Profit**](https://linderud.dev/blog/self-hosting-dns-for-no-fun-but-a-little-profit/): A candid look at the challenges and minor financial/control benefits of running your own recursive DNS server.

* [**Declarative RPM**](https://nordisch.org/posts/declarative-rpm/): A blog post discussing how to achieve declarative package management for RPM-based systems, taking inspiration from the Nix/Guix philosophy.

* [**qemu-img Conversion Command**](https://dannyda.com/2022/10/05/how-to-use-qemu-img-command-to-convert-virtual-disks-between-qcow2-and-zfs-volume-zvol/): How to use the `qemu-img` command to convert virtual disk images (`qcow2`) into ZFS volumes (`zvol`).

## Programming & Learning

* [**The Zig Book**](https://www.zigbook.net/): A comprehensive, free online book for learning the modern, low-level programming language Zig.

* [**Pong in a 512-Byte Boot Sector**](https://akshatjoshi.com/i-wrote-a-pong-game-in-a-512-byte-boot-sector/): A fascinating demonstration of low-level programming where a complete Pong game is squeezed into the 512-byte limit of a boot sector.

* [**Why Castrol Honda Superbike crashes on (most) modern systems**](https://seri.tools/blog/castrol-honda-superbike/): A technical deep dive into reverse engineering the graphics and data files of the classic PC racing game.

## Hardware & Hobby Tech

* [**PicoIDE**](https://picoide.com/): A project page for PicoIDE, a new open-source IDE/ATAPI drive emulator.

* [**DIY Synthesizer for a Daughter**](https://bitsnpieces.dev/posts/a-synth-for-my-daughter/): A touching and technical project documenting the process of building a custom hardware synthesizer. I'm amazed about people being able to do this kind of stuff.

* [**ESP32 Cheap Yellow Display Project**](https://github.com/witnessmenow/ESP32-Cheap-Yellow-Display): A GitHub project providing code and documentation for utilizing the ubiquitous, inexpensive "Cheap Yellow Display" with ESP32 microcontrollers.

* [**LibrePods**](https://github.com/kavishdevar/librepods): AirPods liberated from Apple's ecosystem.

* [**Struggling to heat your home? How about 500 Raspberry Pi units?**](https://www.theregister.com/2025/10/03/thermify_heathub_raspberry_pi/): Heating your house the nerd way!

## News & Community

* [**Cloudflare's November 18, 2025 Outage**](https://blog.cloudflare.com/18-november-2025-outage/): The official post-mortem from Cloudflare detailing the root cause and resolution of their recent network outage.

* [**Open Source Developers are Exhausted**](https://itsfoss.com/news/open-source-developers-are-exhausted/): A discussion on the pervasive issue of burnout and fatigue within the open-source community due to lack of resources and high demands.

* [**Keynote: Rust in the Linux Kernel, Why? - Greg Kroah-Hartman (Video)**](https://www.youtube.com/watch?v=HX0GH-YJbGw): Self explanatory.

* [**Living My Best Sun Microsystems Ecosystem Life in 2025**](https://www.osnews.com/story/143570/living-my-best-sun-microsystems-ecosystem-life-in-2025/): A fun, nostalgic look at running old-school Sun Microsystems hardware and software (like Solaris) in the modern era.

* [**Add a VLAN to OPNsense in Just 26 Clicks Across 6 Screens**](https://mtlynch.io/notes/opnsense-clicks/): Notes and observations on using the OPNsense firewall, focused on specific UI interactions and hardware setup steps.

* [**Google Antigravity Project**](https://antigravity.google/): New Google's AI focused IDE.

* [**Shortwave Live**](https://shortwave.live/): A web application that provides access to the schedule of shortwave radio transmissions around the world.

* [**Espectre**](https://github.com/francescopace/espectre): Motion detection system based on Wi-Fi spectre analysis (CSI), with Home Assistant integration.

* [**Law of Triviality (Wikipedia)**](https://en.wikipedia.org/wiki/Law_of_triviality): Wikipedia entry explaining Parkinson's Law of Triviality, where groups spend a disproportionate amount of time on trivial issues (the "bike-shedding" effect).

* [**Tongue-in-cheek (Wikipedia)**](https://en.wikipedia.org/wiki/Tongue-in-cheek): Wikipedia entry for the phrase "Tongue-in-cheek," describing humor that is ironic or insincere.
