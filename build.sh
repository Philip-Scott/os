#!/bin/bash
set -ouex pipefail

RELEASE="$(rpm -E %fedora)"

# Which hardware variant is being built: "default" (AMD/Intel) or "nvidia".
IMAGE_VARIANT="${IMAGE_VARIANT:-default}"

# Install Microsoft repos for VSCode
sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'

PACKAGES=(screen conky pass htop code azure-cli gh obs-studio autofs okteta mkvtoolnix docker docker-compose nethogs restic)

# ROCm is only useful on AMD GPUs, so it is left out of the Nvidia image.
if [ "${IMAGE_VARIANT}" != "nvidia" ]; then
    PACKAGES+=(rocm-smi rocm-hip rocm-opencl rocminfo)
fi

dnf5 install -y "${PACKAGES[@]}"

ls -lar

# Install kwin-scripts for desktop tweaks
# kpackagetool6 --type=KWin/Script -i ./kwin-scripts/dynamic-workspaces/ --global
# kpackagetool6 --type=KWin/Script -i ./kwin-scripts/virtual-desktops-only-on-primary/ --global
systemctl enable podman.socket

dnf5 clean all
rm -rf /tmp/kwin-scripts
rm -f /tmp/build.sh
