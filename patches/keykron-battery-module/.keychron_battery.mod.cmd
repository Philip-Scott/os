savedcmd_keychron_battery.mod := printf '%s\n'   keychron_battery.o | awk '!x[$$0]++ { print("./"$$0) }' > keychron_battery.mod
