#!/bin/bash
set -ouex pipefail

# Builds the OpenZFS kernel module and userland RPMs against the kernel that
# ships in the base image.
#
# Universal Blue publishes prebuilt ZFS kmods (ghcr.io/ublue-os/akmods-zfs) only
# for the coreos-stable/coreos-testing/longterm/centos kernel flavors. Bazzite
# uses the OGC kernel flavor, which has no prebuilt ZFS kmod, so we build it
# ourselves. This runs in a throwaway builder stage so none of the build
# tooling ends up in the final image; only the resulting RPMs are copied out.

ZFS_VERSION="${ZFS_VERSION:?ZFS_VERSION must be set}"

KERNEL="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"

# The base image already ships the matching kernel-devel; bail out early with a
# clear message rather than failing deep inside ./configure.
if [ ! -d "/usr/src/kernels/${KERNEL}" ]; then
    echo "kernel-devel for ${KERNEL} is missing, cannot build the ZFS kmod" >&2
    exit 1
fi

dnf install -y \
    autoconf automake libtool gcc make rpm-build \
    libtirpc-devel libblkid-devel libuuid-devel libudev-devel openssl-devel \
    libaio-devel libattr-devel elfutils-libelf-devel python3-devel libffi-devel \
    libcurl-devel ncompress python3-setuptools

cd /tmp

curl -sSfL -O "https://github.com/openzfs/zfs/releases/download/zfs-${ZFS_VERSION}/zfs-${ZFS_VERSION}.tar.gz"
curl -sSfL -O "https://github.com/openzfs/zfs/releases/download/zfs-${ZFS_VERSION}/zfs-${ZFS_VERSION}.tar.gz.asc"

# OpenZFS release signing keys, see
# https://openzfs.github.io/openzfs-docs/Project%20and%20Community/Signing%20Keys.html
# The base image has no /root, so keep the keyring in a temporary directory.
GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
# Fetched over HTTPS rather than with --recv-key so the import does not depend
# on dirmngr being able to reach the keyserver on the HKP port.
for key in D4598027 C77B9667 C6AF658B; do
    curl -sSfL "https://keyserver.ubuntu.com/pks/lookup?op=get&options=mr&search=0x${key}" | gpg --import
done

if ! gpg --verify "zfs-${ZFS_VERSION}.tar.gz.asc" "zfs-${ZFS_VERSION}.tar.gz"; then
    echo "ZFS tarball signature verification FAILED" >&2
    exit 1
fi

tar -z -x --no-same-owner --no-same-permissions -f "zfs-${ZFS_VERSION}.tar.gz"
cd "/tmp/zfs-${ZFS_VERSION}"

# OpenZFS refuses to build against kernels newer than Linux-Maximum in META.
# Surface that as an actionable message instead of a raw configure failure.
LINUX_MAXIMUM="$(awk -F: '/^Linux-Maximum:/ { gsub(/[[:space:]]/, "", $2); print $2 }' META)"
KERNEL_MM="$(echo "${KERNEL}" | grep -oE '^[0-9]+\.[0-9]+')"
if [ "$(printf '%s\n' "${LINUX_MAXIMUM}" "${KERNEL_MM}" | sort -V | tail -n1)" != "${LINUX_MAXIMUM}" ]; then
    echo "zfs-${ZFS_VERSION} supports Linux up to ${LINUX_MAXIMUM} but the image ships ${KERNEL}." >&2
    echo "Bump ZFS_VERSION in the Containerfile once OpenZFS supports this kernel." >&2
    exit 1
fi

./configure \
    --with-linux="/usr/src/kernels/${KERNEL}/" \
    --with-linux-obj="/usr/src/kernels/${KERNEL}/"
make -j "$(nproc)" rpm-utils rpm-kmod

# Keep only what the final image needs: the kmod plus the userland tools and
# libraries. Debug, devel, test and source RPMs are dropped.
mkdir -p /var/cache/zfs-rpms
rm -f ./*.src.rpm ./*debug*.rpm ./*devel*.rpm ./zfs-test-*.rpm ./zfs-dracut-*.rpm
mv ./*.rpm /var/cache/zfs-rpms/

ls -l /var/cache/zfs-rpms/
