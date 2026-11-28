# OS

Two images are built from this repository:

| Image | Base | Intended hardware |
| --- | --- | --- |
| `ghcr.io/philip-scott/os` | [`bazzite`](https://github.com/ublue-os/bazzite/pkgs/container/bazzite) | AMD/Intel GPUs |
| `ghcr.io/philip-scott/os-nvidia` | [`bazzite-nvidia-open`](https://github.com/ublue-os/bazzite/pkgs/container/bazzite-nvidia-open) | Nvidia GPUs (open kernel modules) |

Both images share the same `Containerfile` and `build.sh`; the workflow builds
them in a matrix, passing `SOURCE_IMAGE` and `IMAGE_VARIANT` as build args. The
Nvidia image skips the ROCm packages (`rocm-smi`, `rocm-hip`, `rocm-opencl`,
`rocminfo`), which are only useful on AMD GPUs.

```bash
# AMD/Intel
rpm-ostree rebase ostree-unverified-registry:ghcr.io/philip-scott/os

# Nvidia
rpm-ostree rebase ostree-unverified-registry:ghcr.io/philip-scott/os-nvidia
```

# Image layers

Everything `build.sh` installs lands in a single Containerfile `RUN` layer,
which would change on every build and force a full re-download. The workflow
therefore rechunks the final image with `rpm-ostree compose build-chunked-oci`
(as in [ublue-os/image-template](https://github.com/ublue-os/image-template)),
splitting it into up to 127 per-package layers. `--previous-build` points at the
published `:latest` image to keep the layer plan stable, so an update only
downloads layers whose packages changed. The first update after rechunking was
introduced downloads the whole image once.

# ZFS

This image bundles OpenZFS so ZFS pools (for example a drive holding a
[Restic](https://restic.net/) repository) can be imported and mounted.

> [!IMPORTANT]
> ZFS is currently **disabled** (`ARG ENABLE_ZFS="false"` in the `Containerfile`)
> because Bazzite `stable` ships Linux 7.3 and no OpenZFS release supports it
> yet. While disabled, the ZFS build and CI cache steps are skipped and both
> images are built from `stable`. Set `ENABLE_ZFS` to `"true"` to re-enable it.

Universal Blue only publishes prebuilt ZFS kmods for the `coreos-stable`,
`coreos-testing`, `longterm` and `centos` kernel flavors, and Bazzite ships the
OGC kernel. The `zfs-builder` stage in the `Containerfile` therefore compiles
the module from the signed OpenZFS release tarball against the exact kernel in
the base image, and only the resulting RPMs are copied into the final image.

Compiling the module is slow, so CI caches the RPMs with `actions/cache`. The
cache key includes the base image kernel (`ostree.linux` label), `ZFS_VERSION`
and `build-zfs.sh`. It is restored into `zfs-rpms/`, and `build-zfs.sh` reuses
the RPMs only when they match the image kernel; otherwise it rebuilds them.

`ZFS_VERSION` in the `Containerfile` has to stay compatible with the base image
kernel. The build fails with an explicit message when the kernel moves past the
`Linux-Maximum` declared by that OpenZFS release; bump `ZFS_VERSION` to a
release that supports the new kernel.

The module is autoloaded at boot and `zfs-import-cache`, `zfs-mount` and
`zfs-zed` are enabled, so previously imported pools come back automatically:

```bash
sudo zpool import <pool>
restic -r /<pool>/<dataset>/<repo> snapshots
```

> [!NOTE]
> The module is built locally and is **not** signed with an enrolled MOK, so it
> will not load while Secure Boot is enabled.

# Keychron keyboards

Files in `root/` are copied onto the image filesystem as-is (`root/etc/...`
becomes `/etc/...`). `root/etc/udev/rules.d/50-keychron.rules` grants the
logged-in user access to `hidraw` devices from vendor `3434` (Keychron) so
tools like VIA / Keychron Launcher can configure the keyboard. Reboot after
updating to the new image for it to take effect. Check a keyboard's vendor ID
with `lsusb | grep -i keychron` (the `ID 3434:xxxx` part).

## Mouse battery

The image includes the `keychron_battery` kernel module, which reports the
battery level of Keychron M5 / M6 8K mice (wired, through the Ultra-Link 8K
receiver, or through the Link-KM receiver `3434:d026`) to UPower and the
desktop battery widget. Its source is vendored in
`patches/keykron-battery-module` from
[keychron-battery-dkms](https://github.com/csutcliff/keychron-battery-dkms)
v0.1.3 (commit `43c324e`, GPL-2.0-only), so the build never fetches code from
that repository. Two local changes sit on top of v0.1.3: [upstream PR 6](https://github.com/csutcliff/keychron-battery-dkms/pull/6)
(responses are read through `raw_event` instead of a private URB), and
Link-KM support, whose vendor channel is on interface 1 instead of 4,
which takes queries only on its interrupt OUT endpoint, and
which reports as "Keychron M6" since it does not answer the paired-mouse
query. Because the Link-KM carries a joystick on the same interface, UPower
would show its battery as a game controller named after the receiver; the
module instead parents that battery to a virtual `keychron_battery` device with
an idle placeholder mouse, which `50-keychron.rules` hides from libinput. DKMS cannot rebuild modules on an image based system, so the
`keychron-battery-builder` stage in the `Containerfile` compiles it against the
base image kernel, and `build.sh` installs it under
`/usr/lib/modules/<kernel>/extra/`. The module autoloads when a supported device
is connected:

```bash
cat /sys/class/power_supply/keychron_mouse/capacity
```

To update, review the upstream changes and copy `keychron_battery.c` and
`Makefile` from the new release into `patches/keykron-battery-module`, then
reapply the Link-KM changes (and upstream PR 6 if it has not been released yet). Like ZFS, the module is unsigned and will not
load while Secure Boot is enabled.

# AppImages

Every user has an `~/Applications` folder: AppImages dropped into it are added
to the application menu and removed from it when deleted. This is
[appimage-integrator](https://github.com/apapamarkou/appimage-integrator),
vendored in `appimage-integrator/` so the build never fetches it, and run as a
globally enabled systemd user service. See
[`appimage-integrator/README.md`](appimage-integrator/README.md) for the
installed paths and how to update it.

# Purpose

This repository is meant to be a template for building your own custom Universal Blue image. This template is the recommended way to make customizations to any image published by the Universal Blue Project:
- [Aurora](https://getaurora.dev/)
- [Bazzite](https://bazzite.gg/)
- [Bluefin](https://projectbluefin.io/)
- [uCore](https://projectucore.io/)
- [main](https://github.com/ublue-os/main/)
- [hwe](https://github.com/ublue-os/hwe/) 

This template includes a Containerfile and a Github workflow for building the container image. As soon as the workflow is enabled in your repository, it will build the container image and push it to the Github Container Registry.

# Prerequisites

Working knowledge in the following topics:

- Containers
  - https://www.youtube.com/watch?v=SnSH8Ht3MIc
  - https://www.mankier.com/5/Containerfile
- rpm-ostree
  - https://coreos.github.io/rpm-ostree/container/
- Fedora Silverblue (and other Fedora Atomic variants)
  - https://docs.fedoraproject.org/en-US/fedora-silverblue/
- Github Workflows
  - https://docs.github.com/en/actions/using-workflows

# How to Use

## Template

Select `Use this Template` and create a new repository from it. To enable the workflows, you may need to go the `Actions` tab of the new repository and click to enable workflows.

## Containerfile

This file defines the operations used to customize the selected image. It contains examples of possible modifications, including how to:
- change the upstream from which the custom image is derived
- add additional RPM packages
- add binaries as a layer from other images

## Workflows

### build.yml

This workflow creates your custom OCI image and publishes it to the Github Container Registry (GHCR). By default, the image name will match the Github repository name.

#### Container Signing

Container signing is important for end-user security and is enabled on all Universal Blue images. It is recommended you set this up, and by default the image builds *will fail* if you don't.

This provides users a method of verifying the image.

1. Install the [cosign CLI tool](https://edu.chainguard.dev/open-source/sigstore/cosign/how-to-install-cosign/#installing-cosign-with-the-cosign-binary)

2. Run inside your repo folder:

    ```bash
    cosign generate-key-pair
    ```

    
    - Do NOT put in a password when it asks you to, just press enter. The signing key will be used in GitHub Actions and will not work if it is encrypted.

> [!WARNING]
> Be careful to *never* accidentally commit `cosign.key` into your git repo.

3. Add the private key to GitHub

    - This can also be done manually. Go to your repository settings, under Secrets and Variables -> Actions
    ![image](https://user-images.githubusercontent.com/1264109/216735595-0ecf1b66-b9ee-439e-87d7-c8cc43c2110a.png)
    Add a new secret and name it `SIGNING_SECRET`, then paste the contents of `cosign.key` into the secret and save it. Make sure it's the .key file and not the .pub file. Once done, it should look like this:
    ![image](https://user-images.githubusercontent.com/1264109/216735690-2d19271f-cee2-45ac-a039-23e6a4c16b34.png)

    - (CLI instructions) If you have the `github-cli` installed, run:

    ```bash
    gh secret set SIGNING_SECRET < cosign.key
    ```

4. Commit the `cosign.pub` file into your git repository

# Home Assistant lights

`home-assistant-lights.service` calls a Home Assistant webhook to turn the
lights on at boot and off at shutdown. `home-assistant-lights-sleep.service`
turns them off before suspend/hibernate and back on after resume. Each call is
a `POST` to a [webhook trigger](https://www.home-assistant.io/docs/automation/trigger/#webhook-trigger)
of a Home Assistant automation.

The webhook URLs contain secrets, so they are **not** part of the image. Create
the config on each machine (the units do nothing until it exists):

```bash
sudo install -m600 /usr/share/home-assistant-lights/home-assistant-lights.env.example /etc/home-assistant-lights.env
sudoedit /etc/home-assistant-lights.env   # set HA_LIGHTS_ON_URL / HA_LIGHTS_OFF_URL
sudo systemctl start home-assistant-lights.service
journalctl -u home-assistant-lights -u home-assistant-lights-sleep -t home-assistant-lights
```

Leave a URL empty to skip that action. The URLs are never logged.

On a laptop, set `HA_LIGHTS_WIFI_SSIDS` (comma separated) so the webhooks are
only called while connected to one of those Wi-Fi networks, for example
`HA_LIGHTS_WIFI_SSIDS=Home WiFi,Home WiFi 5G`. The active SSID comes from
NetworkManager. After boot/resume the script waits up to `HA_LIGHTS_WIFI_WAIT`
seconds (default 30) for Wi-Fi to connect. When turning the lights off it
doesn't wait, so shutdown and suspend aren't delayed.

The "off" call has to go out while the network is still up:

- **Shutdown:** `home-assistant-lights.service` is ordered after
  `network-online.target` and `NetworkManager.service`, so it is stopped (and
  sends "off") before NetworkManager and the Wi-Fi supplicant are stopped.
- **Suspend:** NetworkManager disconnects all devices as soon as logind
  announces the suspend, before `sleep.target` is reached. The NetworkManager
  pre-down hook
  `/usr/lib/NetworkManager/dispatcher.d/pre-down.d/90-home-assistant-lights`
  therefore sends "off" while the connection is still up, but only when logind
  is preparing for sleep or shutdown (not on ordinary disconnects). logind waits
  at most `InhibitDelayMaxSec` (5s) for this, so the call isn't retried. The
  sleep unit's own "off" is skipped once the hook has sent it.
