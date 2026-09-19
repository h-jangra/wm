#!/usr/bin/env bash
# ==============================================================================
# rofi-wifi: Interactive NetworkManager Wi-Fi Manager for Rofi
# Provides scanning, connection, password prompts, and status indicators.
# ==============================================================================
set -euo pipefail

CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rofi"
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

if [[ -f "$SCRIPT_DIR/wifi.rasi" ]]; then
    RASI="$SCRIPT_DIR/wifi.rasi"
elif [[ -f "$CONF_DIR/network/wifi.rasi" ]]; then
    RASI="$CONF_DIR/network/wifi.rasi"
elif [[ -f "$CONF_DIR/wifi.rasi" ]]; then
    RASI="$CONF_DIR/wifi.rasi"
else
    RASI=""
fi

notify() {
    notify-send -h string:x-canonical-private-synchronous:wm-wifi "Wi-Fi" "$1"
}

if ! command -v nmcli >/dev/null 2>&1; then
    notify "Error: NetworkManager (nmcli) is not installed."
    exit 1
fi

if ! nmcli general status >/dev/null 2>&1; then
    notify "NetworkManager daemon is not active. Run: sudo ln -s /etc/sv/NetworkManager /var/service/"
    exit 1
fi

# Check Wi-Fi Radio Status
wifi_status=$(nmcli -fields WIFI g 2>/dev/null || echo "disabled")

if [[ "$wifi_status" =~ "disabled" ]]; then
    choice=$(printf "󰤨  Enable Wi-Fi\n" | rofi -dmenu -p "Wi-Fi (Disabled)" ${RASI:+-theme "$RASI"})
    if [[ "$choice" == "󰤨  Enable Wi-Fi" ]]; then
        nmcli radio wifi on
        notify "Wi-Fi enabled. Scanning for networks..."
    fi
    exit 0
fi

# Active connection
active_ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes:' | cut -d: -f2- || true)

# Build Menu Options
menu_header=""
if [[ -n "$active_ssid" ]]; then
    menu_header="󰤨  Disconnect from '${active_ssid}'\n"
fi
menu_header="${menu_header}󰤮  Disable Wi-Fi\n󰑐  Rescan Networks"

# Scan and list networks
raw_networks=$(nmcli -t -f in-use,signal,bars,security,ssid dev wifi list --rescan no 2>/dev/null || true)

formatted_list=""
declare -A seen_ssids
declare -A entry_to_ssid

while IFS=: read -r in_use signal bars security ssid; do
    [[ -z "$ssid" ]] && continue
    [[ -n "${seen_ssids["$ssid"]:-}" ]] && continue
    seen_ssids["$ssid"]=1

    icon="󰤨"
    if [[ "$signal" -lt 30 ]]; then
        icon="󰤟"
    elif [[ "$signal" -lt 60 ]]; then
        icon="󰤢"
    elif [[ "$signal" -lt 85 ]]; then
        icon="󰤥"
    fi

    sec_icon=""
    if [[ "$security" =~ "WPA" || "$security" =~ "WEP" || "$security" =~ "802.1X" ]]; then
        sec_icon=" 󰌾"
    fi

    entry="${icon}  ${ssid} (${signal}%)${sec_icon}"
    if [[ "$in_use" == "*" ]]; then
        entry="${entry} [Connected]"
    fi

    formatted_list="${formatted_list}\n${entry}"
    entry_to_ssid["$entry"]="$ssid"
done <<< "$raw_networks"

menu_content="$(printf "%b%b" "$menu_header" "$formatted_list")"
chosen=$(printf "%s" "$menu_content" | rofi -dmenu -p "Wi-Fi Networks" ${RASI:+-theme "$RASI"})

[[ -z "$chosen" ]] && exit 0

if [[ "$chosen" == *"Disable Wi-Fi"* ]]; then
    nmcli radio wifi off
    notify "Wi-Fi disabled"
    exit 0
elif [[ "$chosen" == *"Rescan Networks"* ]]; then
    notify "Scanning for Wi-Fi networks..."
    nmcli device wifi rescan
    exec "$0"
elif [[ "$chosen" == *"Disconnect from"* ]]; then
    active_uuid=$(nmcli -t -f uuid,state con show --active | grep ':activated' | head -n1 | cut -d: -f1 || true)
    if [[ -n "$active_uuid" ]]; then
        nmcli con down uuid "$active_uuid"
        notify "Disconnected from ${active_ssid}"
    fi
    exit 0
fi

# Retrieve exact SSID from map
selected_ssid="${entry_to_ssid["$chosen"]:-}"

if [[ -z "$selected_ssid" ]]; then
    exit 0
fi

# Check if connection is already known/saved
known_con=$(nmcli -t -f name con show | grep "^${selected_ssid}$" || true)

notify "Connecting to '${selected_ssid}'..."

if [[ -n "$known_con" ]]; then
    if nmcli con up id "$selected_ssid"; then
        notify "Connected to '${selected_ssid}'"
    else
        notify "Failed to connect to '${selected_ssid}'. Try re-entering password."
    fi
else
    # New connection - prompt for password if secured
    is_secured=$(nmcli -t -f ssid,security dev wifi list | grep "^${selected_ssid}:" | cut -d: -f2- | grep -E 'WPA|WEP|802.1X' || true)
    
    if [[ -n "$is_secured" ]]; then
        pass=$(rofi -dmenu -password -p "Password for ${selected_ssid}" ${RASI:+-theme "$RASI"})
        [[ -z "$pass" ]] && exit 0
        if nmcli dev wifi connect "$selected_ssid" password "$pass"; then
            notify "Successfully connected to '${selected_ssid}'"
        else
            notify "Failed to connect: Invalid password or timeout"
        fi
    else
        if nmcli dev wifi connect "$selected_ssid"; then
            notify "Successfully connected to '${selected_ssid}'"
        else
            notify "Failed to connect to open network '${selected_ssid}'"
        fi
    fi
fi
