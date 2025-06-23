#!/bin/bash
set -ouex pipefail

RELEASE="$(rpm -E %fedora)"

# Install Microsoft repos for VSCode
sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'

rpm-ostree install screen conky pass htop code azure-cli obs-studio autofs okteta mkvtoolnix

ls -lar

# Install kwin-scripts for desktop tweaks
# kpackagetool6 --type=KWin/Script -i ./kwin-scripts/dynamic-workspaces/ --global
# kpackagetool6 --type=KWin/Script -i ./kwin-scripts/virtual-desktops-only-on-primary/ --global

systemctl enable podman.socket
