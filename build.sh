#!/bin/bash
set -ouex pipefail

RELEASE="$(rpm -E %fedora)"

# Install Microsoft repos for VSCode
sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'

rpm-ostree install screen conky pass htop code azure-cli obs-studio autofs okteta mkvtoolnix rocm-smi rocm-hip rocm-opencl rocminfo docker docker-compose nethogs restic 

# ZFS: kmod plus userland tools built against this image's kernel by the
# zfs-builder stage. Pools are imported and mounted manually, not at boot.
rpm-ostree install /tmp/zfs-rpms/*.rpm

KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
depmod -a "${KERNEL_VERSION}"

# Load the module at boot so pools can be imported without manual modprobe.
echo "zfs" > /etc/modules-load.d/zfs.conf

ls -lar

# Install kwin-scripts for desktop tweaks
# kpackagetool6 --type=KWin/Script -i ./kwin-scripts/dynamic-workspaces/ --global
# kpackagetool6 --type=KWin/Script -i ./kwin-scripts/virtual-desktops-only-on-primary/ --global

systemctl enable podman.socket

# Do not import or mount ZFS pools at boot. The ZFS RPM presets enable these
# units on install, so disable them explicitly. They are only disabled, not
# masked, so pools can still be imported/mounted manually afterwards
# (e.g. `zpool import <pool>` or `systemctl start zfs-mount.service`).
for unit in zfs-import-cache.service zfs-import-scan.service zfs-mount.service \
    zfs-share.service zfs-zed.service zfs-volume-wait.service \
    zfs-import.target zfs-volumes.target zfs.target; do
    if [ -e "/usr/lib/systemd/system/${unit}" ]; then
        systemctl disable "${unit}"
    fi
done
