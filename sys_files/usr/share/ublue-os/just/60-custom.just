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
