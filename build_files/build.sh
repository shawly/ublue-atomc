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
