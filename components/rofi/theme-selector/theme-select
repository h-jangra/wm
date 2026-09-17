#!/usr/bin/env bash
# ==============================================================================
# theme-selector: Interactive Theme Selector using Rofi for MangoWC
# Self-contained within components/rofi/theme-selector/
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
THEMES_DIR="${REPO_DIR}/components/themes"
PRESETS_DIR="${THEMES_DIR}/presets"
DEFS_DIR="${THEMES_DIR}/definitions"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/wm"
CURRENT_FILE="${STATE_DIR}/current"
CURRENT_MODE_FILE="${STATE_DIR}/current_mode"

current_theme=""
if [[ -f "$CURRENT_FILE" ]]; then
    current_theme=$(cat "$CURRENT_FILE" | tr -d '[:space:]')
fi
current_mode="static"
if [[ -f "$CURRENT_MODE_FILE" ]]; then
    current_mode=$(cat "$CURRENT_MODE_FILE" | tr -d '[:space:]')
fi

RASI="${SCRIPT_DIR}/theme-selector.rasi"
[[ -f "$RASI" ]] || RASI="${SCRIPT_DIR}/../theme.rasi"

THEME_SWITCH="$(command -v theme-switch || true)"
if [[ -z "$THEME_SWITCH" || ! -x "$THEME_SWITCH" ]]; then
    THEME_SWITCH="${THEMES_DIR}/theme-switch"
fi

declare -a theme_ids=()
menu_items=""

# 1. Preset Themes
if [[ -d "$PRESETS_DIR" ]]; then
    for d in "$PRESETS_DIR"/*/; do
        [[ -d "$d" ]] || continue
        id=$(basename "$d")
        if [[ -f "$d/theme.conf" || -f "$d/theme-config.bash" ]]; then
            theme_ids+=("$id")
            name="$(tr '[:lower:]' '[:upper:]' <<< ${id:0:1})${id:1}"
            icon="$d/preview.webp"
            
            prefix="  "
            if [[ "$current_mode" == "static" && "$current_theme" == "$id" ]]; then
                prefix="✔ "
            fi
            
            if [[ -f "$icon" ]]; then
                menu_items+="${prefix}${name}\0icon\x1f${icon}\n"
            else
                menu_items+="${prefix}${name}\0icon\x1fpreferences-desktop-theme\n"
            fi
        fi
    done
fi

# 2. Color Palettes (only if not already in presets)
if [[ -d "$DEFS_DIR" ]]; then
    for f in "$DEFS_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        id=$(basename "$f" .json)
        # Skip if already listed as a preset
        for existing in "${theme_ids[@]}"; do
            [[ "$existing" == "$id" ]] && continue 2
        done
        name=$(grep -m1 '"name":' "$f" | awk -F'"' '{print $4}')
        theme_ids+=("$id")
        
        prefix="  "
        if [[ "$current_mode" == "static" && "$current_theme" == "$id" ]]; then
            prefix="✔ "
        fi
        menu_items+="${prefix}${name}\0icon\x1fpreferences-desktop-theme\n"
    done
fi

# 3. Dynamic Theme
theme_ids+=("dynamic")
dyn_prefix="  "
if [[ "$current_mode" == "dynamic" ]]; then
    dyn_prefix="✔ "
fi
menu_items+="${dyn_prefix}Dynamic Wallpaper\0icon\x1fpreferences-desktop-wallpaper\n"

# Run Rofi
selected_idx=$(printf "%b" "$menu_items" | rofi -dmenu -format i -show-icons -p "Themes" ${RASI:+-theme "$RASI"} || true)

if [[ -z "$selected_idx" || "$selected_idx" -lt 0 ]]; then
    exit 0
fi

target_id="${theme_ids[$selected_idx]}"
exec "$THEME_SWITCH" "$target_id"
