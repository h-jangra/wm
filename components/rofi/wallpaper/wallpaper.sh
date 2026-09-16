#!/usr/bin/env bash
# ==============================================================================
# rofi-wallpaper: Interactive Rofi Wallpaper Selector with Thumbnails
# Self-contained within components/rofi/wallpaper/
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
PRESETS_DIR="${REPO_DIR}/components/themes/presets"
USER_WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

RASI="${SCRIPT_DIR}/wallpaper.rasi"
[[ -f "$RASI" ]] || RASI="${SCRIPT_DIR}/../theme.rasi"

# Locate wallpaper-manager
WALL_MGR="$(command -v wallpaper-manager || true)"
if [[ -z "$WALL_MGR" || ! -x "$WALL_MGR" ]]; then
    WALL_MGR="${REPO_DIR}/components/wallpaper/wallpaper-manager"
fi

search_dirs=()
if [[ -d "$USER_WALLPAPER_DIR" ]]; then
    search_dirs+=("$USER_WALLPAPER_DIR")
fi
if [[ -d "$PRESETS_DIR" ]]; then
    for pwd_dir in "$PRESETS_DIR"/*/wallpapers; do
        [[ -d "$pwd_dir" ]] && search_dirs+=("$pwd_dir")
    done
fi

declare -A seen_paths
declare -a wallpapers=()
menu_entries="🎲  Random Wallpaper\0icon\x1fview-refresh\n"

# Collect and deduplicate all valid image files
while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue
    real_path=$(readlink -f "$file")
    
    # Avoid duplicate wallpaper entries
    if [[ -n "${seen_paths["$real_path"]:-}" ]]; then
        continue
    fi
    seen_paths["$real_path"]=1
    wallpapers+=("$real_path")

    bname=$(basename "$real_path")
    clean_display="${bname%.*}"
    
    # Strip long wallhaven prefixes for clean card display
    clean_display="${clean_display#wallhaven-}"

    menu_entries+="${clean_display}\0icon\x1f${real_path}\n"
done < <(find "${search_dirs[@]}" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) 2>/dev/null | sort)

# Use -format i to get exact selected index (0-based) from rofi
selected_idx=$(printf "%b" "$menu_entries" | rofi -dmenu -format i -show-icons -p "Wallpapers" ${RASI:+-theme "$RASI"} || true)

# Exit if cancelled
if [[ -z "$selected_idx" || "$selected_idx" -lt 0 ]]; then
    exit 0
fi

# Index 0 is Random Wallpaper
if [[ "$selected_idx" -eq 0 ]]; then
    exec "$WALL_MGR" random
fi

# Index > 0 corresponds to wallpapers[selected_idx - 1]
target_idx=$((selected_idx - 1))
if [[ "$target_idx" -ge 0 && "$target_idx" -lt "${#wallpapers[@]}" ]]; then
    target_file="${wallpapers[$target_idx]}"
    exec "$WALL_MGR" set "$target_file"
fi
