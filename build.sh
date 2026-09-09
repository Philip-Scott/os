#!/bin/bash
set -ouex pipefail

RELEASE="$(rpm -E %fedora)"

# Which hardware variant is being built: "default" (AMD/Intel) or "nvidia".
IMAGE_VARIANT="${IMAGE_VARIANT:-default}"

# Install Microsoft repos for VSCode
sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'

PACKAGES=(screen conky pass htop code azure-cli obs-studio autofs okteta mkvtoolnix docker docker-compose nethogs restic)

# ROCm is only useful on AMD GPUs, so it is left out of the Nvidia image.
if [ "${IMAGE_VARIANT}" != "nvidia" ]; then
    PACKAGES+=(rocm-smi rocm-hip rocm-opencl rocminfo)
fi

rpm-ostree install "${PACKAGES[@]}"

DESKFLOW_VERSION="1.26.0"
case "$(uname -m)" in
    x86_64|aarch64)
        DESKFLOW_ARCH="$(uname -m)"
        ;;
    *)
        echo "Unsupported Deskflow architecture: $(uname -m)" >&2
        exit 1
        ;;
esac
case "${RELEASE}" in
    42)
        DESKFLOW_FEDORA_RELEASE="42"
        ;;
    *)
        DESKFLOW_FEDORA_RELEASE="43"
        ;;
esac
DESKFLOW_RPM="deskflow-${DESKFLOW_VERSION}-fedora-${DESKFLOW_FEDORA_RELEASE}-${DESKFLOW_ARCH}.rpm"
DESKFLOW_RELEASE_URL="https://github.com/deskflow/deskflow/releases/download/v${DESKFLOW_VERSION}"
curl -sSfL -o "/tmp/${DESKFLOW_RPM}" "${DESKFLOW_RELEASE_URL}/${DESKFLOW_RPM}"
curl -sSfL -o /tmp/deskflow-sums.txt "${DESKFLOW_RELEASE_URL}/sums.txt"
cd /tmp
grep -F "  ${DESKFLOW_RPM}" deskflow-sums.txt | sha256sum -c -
rpm-ostree install "/tmp/${DESKFLOW_RPM}"

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
