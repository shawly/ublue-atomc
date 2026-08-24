#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# plasma-bigscreen pulls in plasma-nano, the Bigscreen KCMs and
# plasma-bigscreen-inputhandler along with the wayland session file.
dnf5 install -y \
    plasma-bigscreen

### Remove packages

# The Kinoite application set. None of these are usable with a remote and all of them show
# up in the Bigscreen launcher. plasma-welcome and plasma-setup are first-login wizards that
# would take over the screen on a TV.
#
# Three names are here only as reverse dependencies of something else in the list:
# plasma-drkonqi requires konsole, kde-connect-libs requires kde-connect, and konsole-part is
# the terminal component Kate and Dolphin embed.
#
# plasma-browser-integration deliberately stays. Removing it drags out
# fedora-chromium-config-kde and it costs nothing at runtime.
#
# One call on purpose: if a name is retired upstream the build should fail here rather than
# silently leave the application installed.
dnf5 remove -y \
    ark \
    ark-libs \
    dolphin \
    dolphin-libs \
    dolphin-plugins \
    filelight \
    firefox \
    firefox-langpacks \
    htop \
    kate \
    kate-krunner-plugin \
    kate-libs \
    kate-plugins \
    kcharselect \
    kde-connect \
    kde-connect-libs \
    kdeconnectd \
    kfind \
    khelpcenter \
    kinfocenter \
    konsole \
    konsole-part \
    krfb \
    krfb-libs \
    kwalletmanager5 \
    kwrite \
    nvtop \
    plasma-discover \
    plasma-discover-flatpak \
    plasma-discover-kns \
    plasma-discover-libs \
    plasma-discover-notifier \
    plasma-disks \
    plasma-drkonqi \
    plasma-print-manager \
    plasma-print-manager-libs \
    plasma-setup \
    plasma-systemmonitor \
    plasma-thunderbolt \
    plasma-vault \
    plasma-welcome

### Install shipped files

# sys_files mirrors the target filesystem, so everything under it lands at the same path.
cp -r /ctx/sys_files/* /
