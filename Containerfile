ARG SOURCE_IMAGE="bazzite"
ARG SOURCE_TAG="stable"

# OpenZFS release used to build the kernel module. It must support the kernel
# shipped by the base image (see Linux-Maximum in the OpenZFS META file).
ARG ZFS_VERSION="2.4.4"

# Throwaway stage that compiles the ZFS kmod against the base image kernel, so
# that the build tooling never reaches the final image.
FROM ghcr.io/ublue-os/${SOURCE_IMAGE}:${SOURCE_TAG} AS zfs-builder

ARG ZFS_VERSION

COPY build-zfs.sh /tmp/build-zfs.sh

RUN /tmp/build-zfs.sh

FROM ghcr.io/ublue-os/${SOURCE_IMAGE}:${SOURCE_TAG}

COPY build.sh /tmp/build.sh
COPY kwin-scripts /tmp/kwin-scripts
COPY --from=zfs-builder /var/cache/zfs-rpms /tmp/zfs-rpms

RUN mkdir -p /var/lib/alternatives && \
    cd /tmp/ && \
    /tmp/build.sh && \
    ostree container commit

## NOTES:
# - /var/lib/alternatives is required to prevent failure with some RPM installs
# - All RUN commands must end with ostree container commit
#   see: https://coreos.github.io/rpm-ostree/container/#using-ostree-container-commit
