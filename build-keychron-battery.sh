#!/bin/bash
set -ouex pipefail

# Builds the keychron_battery kernel module (battery reporting for Keychron
# mice) against the kernel that ships in the base image. The source is vendored
# in patches/keykron-battery-module from
# https://github.com/csutcliff/keychron-battery-dkms.
#
# Upstream distributes it as a DKMS package, but DKMS cannot rebuild modules on
# an image based system, so the module is compiled here in a throwaway builder
# stage and only the resulting .ko is copied into the final image.

SRC=/tmp/keychron-battery-src

KERNEL="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
KDIR="/usr/src/kernels/${KERNEL}"

if [ ! -d "${KDIR}" ]; then
    echo "kernel-devel for ${KERNEL} is missing, cannot build keychron_battery" >&2
    exit 1
fi

dnf install -y gcc make

cd "${SRC}"
make KDIR="${KDIR}" -j "$(nproc)"

mkdir -p /var/cache/keychron-battery
cp keychron_battery.ko /var/cache/keychron-battery/
modinfo /var/cache/keychron-battery/keychron_battery.ko
