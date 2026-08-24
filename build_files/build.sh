#!/bin/bash

set -ouex pipefail

### Install packages

# The base image enables fedora, updates, updates-archive, fedora-cisco-openh264 and the
# ublue akmods copr. negativo17's fedora-multimedia is present but disabled; the mesa and
# libva already installed from it stay installed, which is what keeps hardware decode working.

# Kodi is packaged in neither Fedora nor Negativo17, so RPM Fusion Free has to be here.
dnf5 install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"

# plasma-bigscreen pulls in plasma-nano, the Bigscreen KCMs and
# plasma-bigscreen-inputhandler along with the wayland session file.
#
# kodi ships one /usr/lib64/kodi/kodi.bin with x11, wayland and gbm compiled in; the backend
# is picked at runtime with --windowing. The package's own kodi-gbm.desktop session does that.
#
# igt-gpu-tools and libva-utils are for checking hardware decode on the target machine.
# libva-utils is already in the base image and is named here so the intent survives a base
# image that stops shipping it.
dnf5 install -y \
    igt-gpu-tools \
    kodi \
    kodi-inputstream-adaptive \
    libva-utils \
    plasma-bigscreen

### Remove packages

# Task 019's rule is that a package which is only wrong on the homescreen gets a blacklist
# entry instead of being uninstalled. plasma-welcome is the exception: the tour starts itself
# on first login rather than being launched from a tile, so hiding the entry does not stop it.
# plasma-setup is a different thing and stays.
dnf5 remove -y plasma-welcome

### Install shipped files

# sys_files mirrors the target filesystem, so everything under it lands at the same path.
cp -r /ctx/sys_files/* /

### Enable services

# Enablement goes through systemctl rather than a .wants symlink under /usr/lib. Both start
# the unit, but only this one makes `systemctl is-enabled` say so, and someone reading
# `disabled` on a unit that does run has no way to tell it apart from one that does not. The
# symlinks land in /etc, which is where kinoite-main puts its own.
#
# This has to come after the sys_files copy, because systemctl refuses to enable a unit whose
# file is not there yet.

# The graphical session restarts itself on exit, so a session that dies during startup makes
# the console unusable. sshd is the way back in from another machine. The base image ships it
# installed but disabled by 81-desktop.preset.
systemctl enable sshd.service

systemctl enable atomc-autologin-setup.service

# --global enables for every user rather than for root, whose session never starts here.
systemctl --global enable atomc-seed-permissions.service

### Compile the hardware database

# udev reads the compiled /etc/udev/hwdb.bin, not the .hwdb sources, and it takes the first
# binary it finds, so the one in /etc shadows anything under /usr/lib. The file is an rpm
# %ghost, generated rather than shipped, so regenerating it here is what the base image did
# too.
#
# systemd-hwdb-update.service would also rebuild it on boot, but only when
# ConditionNeedsUpdate=/etc fires. Building it now means the mapping is in the image and can
# be checked with `systemd-hwdb query` without booting anything.
systemd-hwdb update

### Clean up dnf state

# dnf5 leaves a lock file under /var/lib/dnf and an empty /run/dnf. Both trip
# `bootc container lint`, and both are wrong to ship: /var is machine state that a bootc
# update never touches again, and /run is recreated on every boot. The base image has
# neither directory, so nothing here removes something kinoite-main owns.
#
# /var/cache and /var/log are cache mounts in the Containerfile and are not in the layer,
# so `dnf5 clean all` has nothing left to do afterwards.
dnf5 clean all
rm -rf /var/lib/dnf /run/dnf

# Removing the dnf directory leaves /var/lib empty. The base image has no /var/lib at all,
# and systemd-tmpfiles recreates it at boot, so the image should not own it either.
rmdir --ignore-fail-on-non-empty /var/lib
