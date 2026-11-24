#!/bin/bash

#     _               ___
#    / \   _ __  _ __|_ _|_ __ ___   __ _  __ _  ___
#   / _ \ | '_ \| '_ \| || '_ ` _ \ / _` |/ _` |/ _ \
#  / ___ \| |_) | |_) | || | | | | | (_| | (_| |  __/
# /_/   \_\ .__/| .__/___|_| |_| |_|\__,_|\__, |\___|
#         |_|   |_|                       |___/
#  ___       _                       _
# |_ _|_ __ | |_ ___  __ _ _ __ __ _| |_ ___  _ __
#  | || '_ \| __/ _ \/ _` | '__/ _` | __/ _ \| '__|
#  | || | | | ||  __/ (_| | | | (_| | || (_) | |
# |___|_| |_|\__\___|\__, |_|  \__,_|\__\___/|_|
#                    |___/
#
# Author Andrianos Papamarkou
# Email: apapamarkou@yahoo.com
#

# Notification helper function for appimage-integrator
# Respects silent setting from config file

notify() {
	local title="$1"
	local message="$2"

	# Load config to check silent setting
	local config_user="$HOME/.config/appimage-integrator/appimage-integrator.conf"
	local config_system="/etc/appimage-integrator/appimage-integrator.conf"
	local silent=false

	if [[ -f "$config_user" ]]; then
		# shellcheck source=src/appimage-integrator.conf
		source "$config_user"
	elif [[ -f "$config_system" ]]; then
		# shellcheck source=src/appimage-integrator.conf
		source "$config_system"
	fi

	# Only send notification if not silent
	if [[ "$silent" != "true" ]] && command -v notify-send &>/dev/null; then
		notify-send "$title" "$message" &
	fi
}
