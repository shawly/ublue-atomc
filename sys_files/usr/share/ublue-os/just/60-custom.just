# vim: set ft=make :

# Point autologin at a different account and restart the display manager
set-autologin-user NAME="":
    #!/usr/bin/bash
    set -euo pipefail
    name="{{ NAME }}"
    if [[ -z ${name} ]]; then
        echo "Usage: ujust set-autologin-user <name>"
        exit 1
    fi
    if ! id -u "${name}" >/dev/null 2>&1; then
        echo "No such account: ${name}"
        exit 1
    fi
    conf=/etc/plasmalogin.conf.d/10-atomc-autologin.conf
    sudo mkdir -p "$(dirname "${conf}")"
    printf '[Autologin]\nUser=%s\n' "${name}" | sudo tee "${conf}" >/dev/null
    echo "Autologin user set to ${name} in ${conf}."
    echo "Restarting the display manager. Any running graphical session ends now."
    sudo systemctl restart plasmalogin.service

# Add the current user to the input group, for installs where the evdev ACL is missing
fix-input-perms:
    #!/usr/bin/bash
    set -euo pipefail
    user="${SUDO_USER:-$(id -un)}"

    echo "Access to the evdev nodes for ${user}:"
    found=0
    for dev in /dev/input/event*; do
        [[ -e ${dev} ]] || continue
        found=1
        if [[ -r ${dev} ]]; then
            echo "  ${dev}: readable"
        else
            echo "  ${dev}: NOT readable"
        fi
    done
    if [[ ${found} -eq 0 ]]; then
        echo "  no /dev/input/event* nodes on this machine"
    fi
    echo

    if id -nG "${user}" | tr ' ' '\n' | grep -qx input; then
        echo "${user} is already in the input group. Nothing to do."
        exit 0
    fi

    # The input group lives in /usr/lib/group and reaches nsswitch through altfiles, so
    # /etc/group has no line for it. usermod only edits /etc/group, and given a group it
    # cannot find there it changes nothing and still exits 0.
    if ! grep -qE '^input:' /etc/group; then
        if ! getent group input >/dev/null; then
            echo "No input group on this system. Nothing to add ${user} to."
            exit 1
        fi
        getent group input | sudo tee -a /etc/group >/dev/null
    fi

    sudo usermod -aG input "${user}"

    if ! id -nG "${user}" | tr ' ' '\n' | grep -qx input; then
        echo "usermod reported success but ${user} is still not in the input group."
        exit 1
    fi

    echo "Added ${user} to the input group."
    echo "Group membership is read at login, so log out and back in before it applies."
