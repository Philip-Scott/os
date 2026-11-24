# AppImage Integrator

Vendored copy of [apapamarkou/appimage-integrator](https://github.com/apapamarkou/appimage-integrator)
(GPL-3.0, see `LICENSE`), taken from commit
[`4a8e902`](https://github.com/apapamarkou/appimage-integrator/tree/4a8e9026fd7f9144cbb326c11693372a91da8b2a).
The files in `src/` are upstream's, with these local changes:

- `appimage-integrator-observer` only watches `~/Applications`. Upstream also
  watches `~/Downloads` and offers to move new AppImages from there; that code
  was removed, along with the `appimage-integrator-downloaded` script it ran.

Every user gets an `~/Applications` folder. Dropping an AppImage into it adds
the app (name, icon, category) to the application menu; removing it removes the
menu entry.

## How it is installed on the image

Instead of the upstream per-user `install` script, which clones the repository
at install time, the image installs everything system-wide during the build:

| Path | Source |
| --- | --- |
| `/usr/libexec/appimage-integrator/` | `src/` from this directory (`build.sh`) |
| `/usr/share/licenses/appimage-integrator/LICENSE` | `LICENSE` (`build.sh`) |
| `/etc/appimage-integrator/appimage-integrator.conf` | `root/etc/appimage-integrator/` |
| `/usr/lib/systemd/user/appimage-integrator.service` | `root/usr/lib/systemd/user/` |
| `/etc/skel/Applications` | created by `build.sh` |

`build.sh` enables the user service globally (`systemctl --global enable`), so
it starts in every user session. The observer creates `~/Applications` on
start, which covers users that existed before the image was installed.

Users can override settings by copying the config to
`~/.config/appimage-integrator/appimage-integrator.conf`; keep
`appimage_integrator_root` pointing at `/usr/libexec/appimage-integrator`.

Check the service with:

```bash
systemctl --user status appimage-integrator.service
journalctl --user -t appimage-integrator
```

## Updating

Copy `src/` (except `appimage-integrator.conf`, `notes.txt` and
`appimage-integrator-downloaded`) and `LICENSE` from the new upstream commit,
reapply the local changes listed above, and update the commit above. Also check
whether the upstream `install` script changed the service unit, config keys or
runtime dependencies.
