#!/bin/bash

set -ouex pipefail

### Install packages

# negativo17's fedora-multimedia is present but disabled in the base image. Leave it that
# way: the mesa and libva already installed from it are what keep hardware decode working.

# Kodi is packaged in neither Fedora nor Negativo17.
dnf5 install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"

# kodi.bin has x11, wayland and gbm compiled in; the backend is picked at runtime with
# --windowing.
#
# igt-gpu-tools and libva-utils are for checking hardware decode on the target machine.
# libva-utils is already in the base image and is named so it survives one that drops it.
dnf5 install -y \
    igt-gpu-tools \
    kodi \
    kodi-inputstream-adaptive \
    libva-utils \
    plasma-bigscreen

### Remove packages

# A package that is only wrong on the homescreen belongs in
# /usr/share/atomc/applications-blacklistrc instead. plasma-welcome is the exception: the tour
# starts itself on first login, so hiding its desktop entry does not stop it. plasma-setup is
# a different thing and stays.
dnf5 remove -y plasma-welcome

### Install shipped files

# sys_files mirrors the target filesystem, so everything under it lands at the same path.
cp -r /ctx/sys_files/* /

### Enable services

# systemctl rather than a .wants symlink under /usr/lib: both start the unit, but only this
# makes `systemctl is-enabled` say so. Has to come after the sys_files copy, because systemctl
# refuses to enable a unit whose file is not there yet.

# The way back in when the graphical session is failing. The base image ships sshd installed
# but disabled by 81-desktop.preset.
systemctl enable sshd.service

systemctl enable atomc-autologin-setup.service

# --global enables for every user rather than for root, whose session never starts here.
systemctl --global enable \
    atomc-seed-permissions.service \
    atomc-app-blacklist.service \
    atomc-hello.service

### Compile the hardware database

# udev reads the compiled /etc/udev/hwdb.bin, never the .hwdb sources.
# systemd-hwdb-update.service would rebuild it on boot, but only when
# ConditionNeedsUpdate=/etc fires; building it here puts the mapping in the image where
# `systemd-hwdb query` can check it without booting.
systemd-hwdb update

### Clean up dnf state

# dnf5 leaves a lock file under /var/lib/dnf and an empty /run/dnf. Both trip
# `bootc container lint`, and neither belongs in an image: /var is machine state a bootc
# update never touches again, /run is recreated every boot.
dnf5 clean all
rm -rf /var/lib/dnf /run/dnf

# The base image has no /var/lib at all, and systemd-tmpfiles recreates it at boot.
rmdir --ignore-fail-on-non-empty /var/lib
