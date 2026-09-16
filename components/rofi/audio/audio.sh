#!/usr/bin/env bash
# ==============================================================================
# rofi-audio: Minimal PipeWire / WirePlumber Audio Switcher for Rofi
# Displays ONLY input and output devices in a side-by-side grid (Input | Output).
# ==============================================================================
set -euo pipefail

CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rofi"
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

if [[ -f "$SCRIPT_DIR/audio.rasi" ]]; then
    RASI="$SCRIPT_DIR/audio.rasi"
elif [[ -f "$CONF_DIR/audio/audio.rasi" ]]; then
    RASI="$CONF_DIR/audio/audio.rasi"
elif [[ -f "$CONF_DIR/audio.rasi" ]]; then
    RASI="$CONF_DIR/audio.rasi"
else
    RASI=""
fi

notify() {
    notify-send -h string:x-canonical-private-synchronous:wm-audio "Audio" "$1"
}

if ! command -v wpctl >/dev/null 2>&1; then
    notify "Error: wpctl (WirePlumber) is not installed."
    exit 1
fi

if ! wpctl status >/dev/null 2>&1; then
    notify "Audio daemon is not responding."
    exit 1
fi

audio_sec=$(wpctl status 2>/dev/null | sed -n '/^Audio/,/^Video/p')

# 1. Parse Sinks (Outputs)
sinks_raw=$(echo "$audio_sec" | sed -n '/├─ Sinks:/,/├─ Sources:/p' | grep -E '^[ │]*(\*?[ ]*[0-9]+)\.' || true)
sinks=()
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    id=$(echo "$line" | sed -E 's/^[ │*]*([0-9]+)\..*/\1/')
    desc=$(echo "$line" | sed -E 's/^[ │*]*[0-9]+\.[ ]*//' | sed -E 's/\[.*\]//' | xargs)
    active=""
    if echo "$line" | grep -q '\*'; then
        active=" [Active]"
    fi
    sinks+=("󰓃 [Output] ${desc}${active} (#${id})")
done <<< "$sinks_raw"

# 2. Parse Sources (Inputs)
sources_raw=$(echo "$audio_sec" | sed -n '/├─ Sources:/,/├─ Filters:/p' | grep -E '^[ │]*(\*?[ ]*[0-9]+)\.' || true)
sources=()
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    id=$(echo "$line" | sed -E 's/^[ │*]*([0-9]+)\..*/\1/')
    desc=$(echo "$line" | sed -E 's/^[ │*]*[0-9]+\.[ ]*//' | sed -E 's/\[.*\]//' | xargs)
    active=""
    if echo "$line" | grep -q '\*'; then
        active=" [Active]"
    fi
    sources+=("󰍬 [Input]  ${desc}${active} (#${id})")
done <<< "$sources_raw"

# If either list is empty, add placeholder
if [[ ${#sinks[@]} -eq 0 ]]; then
    sinks+=("󰓃 [Output] No audio outputs")
fi
if [[ ${#sources[@]} -eq 0 ]]; then
    sources+=("󰍬 [Input]  No audio inputs")
fi

# Interleave into Input | Output grid
max_len=${#sources[@]}
if [[ ${#sinks[@]} -gt $max_len ]]; then
    max_len=${#sinks[@]}
fi

grid_items=()
for ((i=0; i<max_len; i++)); do
    # Column 1: Input
    if [[ $i -lt ${#sources[@]} ]]; then
        grid_items+=("${sources[$i]}")
    else
        grid_items+=("󰍬 [Input]  ---")
    fi
    # Column 2: Output
    if [[ $i -lt ${#sinks[@]} ]]; then
        grid_items+=("${sinks[$i]}")
    else
        grid_items+=("󰓃 [Output] ---")
    fi
done

menu_input=$(printf "%s\n" "${grid_items[@]}")
chosen=$(printf "%s\n" "$menu_input" | rofi -dmenu -p "Audio Switcher" ${RASI:+-theme "$RASI"})

[[ -z "$chosen" ]] && exit 0

# Extract Target ID
target_id=$(echo "$chosen" | grep -oE '#[0-9]+' | tr -d '#' || true)

if [[ -n "$target_id" ]]; then
    clean_name=$(echo "$chosen" | sed -E 's/^[󰓃󰍬] \[(Input|Output)\][ ]*//' | sed -E 's/ \[Active\]//' | sed -E 's/ \(#[0-9]+\)//' | xargs)
    if wpctl set-default "$target_id" 2>/dev/null; then
        notify "Switched active device to: ${clean_name}"
    else
        notify "Failed to switch device to ID: ${target_id}"
    fi
fi
