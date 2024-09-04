# Virtual Desktops Only On Primary

This is a script that brings a feature similar to GNOME Mutter's workspaces-only-on-primary option, that is switchable virtual desktops on the primary monitor, and non-switchable virtual desktops on other monitors.

When the script is enabled, all windows placed on monitors other than the primary, are automatically set to be shown on all virtual desktops. This can be considered a hack, but from the user's perspective, this effectively results in having multiple switchable virtual desktops on the primary monitor, and fixed non-switchable virtual desktops on other monitors. That's how GNOME Shell handles workspaces by default, and the script mimics that.

Besides enabling the script in the System Settings, no additional steps are required.

Based from <https://github.com/hnjae/kwin-scripts/blob/main/virtual-desktops-only-on-primary/contents/code/main.js>, but updated for Plasma 6.1

## Manual Install

```bash
kpackagetool6 --type=KWin/Script -i ./
```
