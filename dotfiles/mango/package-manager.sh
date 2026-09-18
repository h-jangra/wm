#!/usr/bin/env bash
set -euo pipefail

command -v xbps-install >/dev/null || exit 1
command -v xhog >/dev/null || {
    echo "Error: xhog not found. Install xtools."
    exit 1
}

list_repo() {
    xbps-query -Rs "" |
        sed 's/^[-+?] //; s/^[^ ]* //'
}

list_installed() {
    xhog |
        awk '{
            size = $2
            gsub(/B$/, "", size)      # "45.3MB" -> "45.3M", "512KB" -> "512K", "140B" -> "140"
            val = size + 0
            if (size ~ /G$/)      bytes = val * 1073741824
            else if (size ~ /M$/) bytes = val * 1048576
            else if (size ~ /K$/) bytes = val * 1024
            else                  bytes = val
            print bytes "\t" $1
        }' |
        sort -nr -k1,1 |
        awk -F '\t' '{
            b = $1
            if (b >= 1073741824)
                printf "[✓] %6.2f GiB %s\n", b / 1073741824, $2
            else if (b >= 1048576)
                printf "[✓] %6.2f MiB %s\n", b / 1048576, $2
            else if (b >= 1024)
                printf "[✓] %6.2f KiB %s\n", b / 1024, $2
            else
                printf "[✓] %6d B    %s\n", b, $2
        }'
}

preview() {
    local entry="$1"
    local pkg="${entry##* }"
    local name="${pkg%-[0-9]*}"

    xbps-query -S "$name" 2>/dev/null ||
        xbps-query -Rs "^$name\$" 2>/dev/null
}

export -f preview list_repo list_installed

selected="$(
    list_repo |
        fzf \
            --multi \
            --layout=reverse \
            --height=100% \
            --border \
            --preview='bash -c "preview {}"' \
            --preview-window='right:55%:wrap' \
            --bind='alt-p:toggle-preview' \
            --bind='alt-i:reload(bash -c list_installed)+change-prompt(Installed> )' \
            --bind='alt-a:reload(bash -c list_repo)+change-prompt(Package> )' \
            --bind='tab:toggle+down' \
            --bind='btab:toggle+up' \
            --color='pointer:green,marker:green' \
            --header='TAB select • ENTER install/remove • ALT-I installed • ALT-A packages • ALT-P preview' \
            --prompt='Package> '
)"

[[ -z "$selected" ]] && exit 0

mapfile -t pkgs < <(
    awk '{print $NF}' <<< "$selected" |
    sed -E 's/-[0-9][^ ]*$//'
)

install=()
remove=()

for pkg in "${pkgs[@]}"; do
    if xbps-query "$pkg" >/dev/null 2>&1; then
        remove+=("$pkg")
    else
        install+=("$pkg")
    fi
done

if ((${#install[@]})); then
    sudo xbps-install "${install[@]}"
fi

if ((${#remove[@]})); then
    sudo xbps-remove -Ry "${remove[@]}"
fi
