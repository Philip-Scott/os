ARG SOURCE_IMAGE="bazzite"
ARG SOURCE_TAG="stable"

# Selects the hardware specific customizations applied by build.sh.
# "default" targets the AMD/Intel image, "nvidia" targets bazzite-nvidia-open.
ARG IMAGE_VARIANT="default"

# Set to "true" to build and install ZFS. Disabled while no OpenZFS release
# supports the kernel shipped by Bazzite stable.
ARG ENABLE_ZFS="false"

# OpenZFS release used to build the kernel module. It must support the kernel
# shipped by the base image (see Linux-Maximum in the OpenZFS META file).
ARG ZFS_VERSION="2.4.4"

# Throwaway stage that compiles the ZFS kmod against the base image kernel, so
# that the build tooling never reaches the final image.
FROM ghcr.io/ublue-os/${SOURCE_IMAGE}:${SOURCE_TAG} AS zfs-builder

ARG ZFS_VERSION
ARG ENABLE_ZFS

COPY build-zfs.sh /tmp/build-zfs.sh
# Previously built RPMs (restored from the CI cache). Reused by build-zfs.sh
# when they match the kernel and ZFS_VERSION, otherwise ignored.
COPY zfs-rpms /tmp/zfs-prebuilt

# When ZFS is disabled, produce an empty RPM directory instead.
RUN if [ "${ENABLE_ZFS}" = "true" ]; then /tmp/build-zfs.sh; else mkdir -p /var/cache/zfs-rpms; fi

# Throwaway stage that compiles the keychron_battery kmod against the base
# image kernel. DKMS cannot rebuild modules on an image based system.
FROM ghcr.io/ublue-os/${SOURCE_IMAGE}:${SOURCE_TAG} AS keychron-battery-builder

COPY build-keychron-battery.sh /tmp/build-keychron-battery.sh
# Vendored module source, see patches/keykron-battery-module.
COPY patches/keykron-battery-module /tmp/keychron-battery-src

RUN /tmp/build-keychron-battery.sh

FROM ghcr.io/ublue-os/${SOURCE_IMAGE}:${SOURCE_TAG}

ARG IMAGE_VARIANT
ARG ENABLE_ZFS

# Files under root/ are copied as-is onto the image filesystem.
COPY root/ /

COPY build.sh /tmp/build.sh
COPY kwin-scripts /tmp/kwin-scripts
COPY --from=zfs-builder /var/cache/zfs-rpms /tmp/zfs-rpms
COPY --from=keychron-battery-builder /var/cache/keychron-battery /tmp/keychron-battery

RUN mkdir -p /var/lib/alternatives && \
    cd /tmp/ && \
    IMAGE_VARIANT="${IMAGE_VARIANT}" ENABLE_ZFS="${ENABLE_ZFS}" /tmp/build.sh && \
    bootc container lint

## NOTES:
# - /var/lib/alternatives is required to prevent failure with some RPM installs
# - Validate the final bootable image with bootc container lint
