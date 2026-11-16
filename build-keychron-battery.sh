#!/bin/bash
set -ouex pipefail

# Builds the keychron_battery kernel module (battery reporting for Keychron
# mice, https://github.com/csutcliff/keychron-battery-dkms) against the kernel
# that ships in the base image.
#
# Upstream distributes it as a DKMS package, but DKMS cannot rebuild modules on
# an image based system, so the module is compiled here in a throwaway builder
# stage and only the resulting .ko is copied into the final image.

KEYCHRON_BATTERY_VERSION="${KEYCHRON_BATTERY_VERSION:?KEYCHRON_BATTERY_VERSION must be set}"
KEYCHRON_BATTERY_SHA256="${KEYCHRON_BATTERY_SHA256:?KEYCHRON_BATTERY_SHA256 must be set}"

KERNEL="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
KDIR="/usr/src/kernels/${KERNEL}"

if [ ! -d "${KDIR}" ]; then
    echo "kernel-devel for ${KERNEL} is missing, cannot build keychron_battery" >&2
    exit 1
fi

dnf install -y gcc make

SRC="$(mktemp -d)"
cd "${SRC}"

curl -sSfL -o keychron-battery.tar.gz \
    "https://github.com/csutcliff/keychron-battery-dkms/archive/refs/tags/v${KEYCHRON_BATTERY_VERSION}.tar.gz"

if ! echo "${KEYCHRON_BATTERY_SHA256}  keychron-battery.tar.gz" | sha256sum -c -; then
    echo "keychron-battery-dkms tarball checksum verification FAILED" >&2
    exit 1
fi

tar -z -x --no-same-owner --no-same-permissions --strip-components=1 -f keychron-battery.tar.gz

make KDIR="${KDIR}" -j "$(nproc)"

mkdir -p /var/cache/keychron-battery
cp keychron_battery.ko /var/cache/keychron-battery/
modinfo /var/cache/keychron-battery/keychron_battery.ko
