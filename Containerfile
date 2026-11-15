ARG SOURCE_IMAGE="bazzite"
ARG SOURCE_TAG="stable"

# Selects the hardware specific customizations applied by build.sh.
# "default" targets the AMD/Intel image, "nvidia" targets bazzite-nvidia-open.
ARG IMAGE_VARIANT="default"

FROM ghcr.io/ublue-os/${SOURCE_IMAGE}:${SOURCE_TAG}

ARG IMAGE_VARIANT

# Files under root/ are copied as-is onto the image filesystem.
COPY root/ /

COPY build.sh /tmp/build.sh
COPY kwin-scripts /tmp/kwin-scripts

RUN mkdir -p /var/lib/alternatives && \
    cd /tmp/ && \
    IMAGE_VARIANT="${IMAGE_VARIANT}" /tmp/build.sh && \
    bootc container lint

## NOTES:
# - /var/lib/alternatives is required to prevent failure with some RPM installs
# - Validate the final bootable image with bootc container lint
