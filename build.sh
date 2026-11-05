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

# ZFS: kmod plus userland tools built against this image's kernel by the
# zfs-builder stage. Pools are imported and mounted manually, not at boot.
dnf5 install -y /tmp/zfs-rpms/*.rpm

KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
depmod -a "${KERNEL_VERSION}"

# Load the module at boot so pools can be imported without manual modprobe.
echo "zfs" > /etc/modules-load.d/zfs.conf

ls -lar

# rocm-hip hard-requires hipcc -> rocm-device-libs -> rocm-llvm-static, which
# ships ~2.3GB of static LLVM archives (/usr/lib64/rocm/llvm/lib/*.a). They are
# only used to statically link against LLVM, never at runtime, so drop them.
# Done after the last dnf5 transaction so dnf5 doesn't trip over the broken dep.
if rpm -q rocm-llvm-static > /dev/null; then
    rpm -e --nodeps rocm-llvm-static
fi

# Install kwin-scripts for desktop tweaks
# kpackagetool6 --type=KWin/Script -i ./kwin-scripts/dynamic-workspaces/ --global
# kpackagetool6 --type=KWin/Script -i ./kwin-scripts/virtual-desktops-only-on-primary/ --global
systemctl enable podman.socket

dnf5 clean all
rm -rf /tmp/zfs-rpms /tmp/kwin-scripts
rm -f /tmp/build.sh
