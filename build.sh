#!/bin/bash
set -ouex pipefail

RELEASE="$(rpm -E %fedora)"

# Which hardware variant is being built: "default" (AMD/Intel) or "nvidia".
IMAGE_VARIANT="${IMAGE_VARIANT:-default}"

# Whether to install the ZFS RPMs built by the zfs-builder stage.
ENABLE_ZFS="${ENABLE_ZFS:-false}"

# Install Microsoft repos for VSCode
sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'

PACKAGES=(screen conky pass htop code azure-cli gh obs-studio autofs okteta mkvtoolnix docker docker-compose nethogs restic inotify-tools libnotify)

# ROCm is only useful on AMD GPUs, so it is left out of the Nvidia image.
if [ "${IMAGE_VARIANT}" != "nvidia" ]; then
    PACKAGES+=(rocm-smi rocm-hip rocm-opencl rocminfo)
fi

dnf5 install -y "${PACKAGES[@]}"

if [ "${ENABLE_ZFS}" = "true" ]; then
    # ZFS: kmod plus userland tools built against this image's kernel by the
    # zfs-builder stage. Pools are imported and mounted manually, not at boot.
    dnf5 install -y /tmp/zfs-rpms/*.rpm

    KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
    depmod -a "${KERNEL_VERSION}"

    # Load the module at boot so pools can be imported without manual modprobe.
    echo "zfs" > /etc/modules-load.d/zfs.conf
fi

# Keychron mouse battery reporting, built by the keychron-battery-builder
# stage. The module autoloads through its HID device table when a supported
# mouse or receiver is connected.
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
install -Dm644 /tmp/keychron-battery/keychron_battery.ko \
    "/usr/lib/modules/${KERNEL_VERSION}/extra/keychron-battery/keychron_battery.ko"
depmod -a "${KERNEL_VERSION}"

# Keep the HDA codec powered while idle (see /etc/modprobe.d/audio-no-powersave.conf).
# tuned's audio plugin rewrites snd_hda_intel power_save at runtime, overriding
# the modprobe option, so disable it in every tuned profile that enables it.
TUNED_AUDIO_PROFILES="$(grep -rlx --include=tuned.conf '\[audio\]' /usr/lib/tuned || true)"
for profile in ${TUNED_AUDIO_PROFILES}; do
    awk '/^\[/ { section = $0 }
         section == "[audio]" && /^[[:space:]]*timeout[[:space:]]*=/ { $0 = "timeout=0" }
         { print }' "${profile}" > "${profile}.tmp"
    mv "${profile}.tmp" "${profile}"
done
if grep -rA5 --include=tuned.conf '^\[audio\]' /usr/lib/tuned | grep -E 'timeout[[:space:]]*=' | grep -vE 'timeout=0$'; then
    echo "tuned audio power saving is still enabled" >&2
    exit 1
fi

# AppImage integrator (vendored in appimage-integrator/): every user gets an
# ~/Applications folder whose AppImages are added to the application menu.
# The config and user unit come from root/.
install -d /usr/libexec/appimage-integrator
install -m755 /tmp/appimage-integrator/src/appimage-integrator-* /usr/libexec/appimage-integrator/
install -m644 /tmp/appimage-integrator/src/*.sh /tmp/appimage-integrator/src/messages.*_* /usr/libexec/appimage-integrator/
install -Dm644 /tmp/appimage-integrator/LICENSE /usr/share/licenses/appimage-integrator/LICENSE
install -d -m755 /etc/skel/Applications
systemctl --global enable appimage-integrator.service

ls -lar

# Install kwin-scripts for desktop tweaks
# kpackagetool6 --type=KWin/Script -i ./kwin-scripts/dynamic-workspaces/ --global
# kpackagetool6 --type=KWin/Script -i ./kwin-scripts/virtual-desktops-only-on-primary/ --global
systemctl enable podman.socket

# Home Assistant lights (units and script come from root/). Both units are
# skipped until /etc/home-assistant-lights.env is created on the machine, so
# the webhook secrets never end up in the image.
systemctl enable home-assistant-lights.service home-assistant-lights-sleep.service

dnf5 clean all
rm -rf /tmp/zfs-rpms /tmp/keychron-battery /tmp/kwin-scripts /tmp/appimage-integrator
rm -f /tmp/build.sh
