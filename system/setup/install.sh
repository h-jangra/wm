#!/usr/bin/env bash
# ==============================================================================
# install.sh: Void Linux Desktop Installer
# Configures MangoWC, Eww, Fuzzel, Foot, PipeWire, runit, repos, and optional Ly DM.
#
# Idempotent, safe to run multiple times, manages Void repos/mirrors & services.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$HOME/.config/wm-backups-$TIMESTAMP"

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
BOLD='\033[1m'
RESET='\033[0m'

msg_info()  { echo -e "${BLUE}[INFO]${RESET} $*"; }
msg_ok()    { echo -e "${GREEN}[OK]${RESET} $*"; }
msg_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
msg_err()   { echo -e "${RED}[ERROR]${RESET} $*"; }

LOGIN_MANAGER=""
AUTO_YES=0
SETUP_MIRROR=0
ENABLE_EXTRA_REPOS=1
BUILD_LY=0
BUILD_MANGOBAR=0
FIX_AUDIO=0
FIX_DBUS=0
FIX_BLUETOOTH=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)
            AUTO_YES=1
            shift 1
            ;;
        --login-manager)
            LOGIN_MANAGER="$2"
            shift 2
            ;;
        --login-manager=*)
            LOGIN_MANAGER="${1#*=}"
            shift 1
            ;;
        --mirror)
            SETUP_MIRROR=1
            shift 1
            ;;
        --no-extra-repos)
            ENABLE_EXTRA_REPOS=0
            shift 1
            ;;
        --build-ly)
            BUILD_LY=1
            LOGIN_MANAGER="ly"
            shift 1
            ;;
        --build-mangobar)
            BUILD_MANGOBAR=1
            shift 1
            ;;
        --fix-audio)
            FIX_AUDIO=1
            shift 1
            ;;
        --fix-dbus)
            FIX_DBUS=1
            shift 1
            ;;
        --fix-bluetooth)
            FIX_BLUETOOTH=1
            shift 1
            ;;
        -h|--help)
            echo "Usage: ./install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -y, --yes                   Non-interactive mode, automatically answer yes to prompts"
            echo "  --login-manager <ly|none>   Configure preferred login manager (optional)"
            echo "  --mirror                    Launch xmirror to configure/select an XBPS mirror"
            echo "  --no-extra-repos            Skip enabling nonfree and multilib Void repositories"
            echo "  --build-ly                  Force building Ly from source (https://github.com/fairyglade/ly)"
            echo "  --build-mangobar            Force building/rebuilding MangoBar from source (https://github.com/mangowm/mangobar)"
            echo "  --fix-audio                 Diagnose and repair PipeWire/WirePlumber audio subsystem"
            echo "  --fix-dbus                  Diagnose and repair DBus system and session services"
            echo "  --fix-bluetooth             Diagnose and repair BlueZ Bluetooth daemon and rfkill"
            echo "  -h, --help                  Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Run ./install.sh --help for available options." >&2
            exit 1
            ;;
    esac
done

# Handle standalone subsystem fix modules if requested
if [[ $FIX_DBUS -eq 1 || $FIX_AUDIO -eq 1 || $FIX_BLUETOOTH -eq 1 ]]; then
    if [[ $FIX_DBUS -eq 1 ]]; then
        "$REPO_DIR/scripts/system/fix-dbus"
    fi
    if [[ $FIX_AUDIO -eq 1 ]]; then
        "$REPO_DIR/scripts/system/fix-audio"
    fi
    if [[ $FIX_BLUETOOTH -eq 1 ]]; then
        "$REPO_DIR/scripts/system/fix-bluetooth"
    fi
    exit 0
fi

echo -e "${BOLD}========================================================${RESET}"
echo -e "${BOLD}      Void Linux × MangoWC Minimal Desktop Installer    ${RESET}"
echo -e "${BOLD}========================================================${RESET}"
echo ""

# ------------------------------------------------------------------------------
# 1. Distro Detection
# ------------------------------------------------------------------------------
msg_info "Checking target operating system..."

is_void=0
distro_id="unknown"
if [[ -f /etc/os-release ]]; then
    distro_id=$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    if [[ "$distro_id" == "void" ]]; then
        is_void=1
    fi
fi

if [[ $is_void -eq 0 ]]; then
    msg_warn "This installer is tailored for Void Linux with runit & XBPS."
    msg_warn "Current system identified as: ${distro_id}."
    echo ""
    if [[ $AUTO_YES -eq 1 ]]; then
        choice="y"
    else
        read -rp "Would you like to proceed with configuration symlinking only? [y/N]: " choice
    fi
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
        msg_err "Installation aborted by user on non-Void system."
        exit 1
    fi
else
    msg_ok "Void Linux detected successfully."
fi

# ------------------------------------------------------------------------------
# 2. Void Linux Repositories & Mirror Configuration
# ------------------------------------------------------------------------------
if [[ $is_void -eq 1 ]]; then
    msg_info "Checking Void Linux repositories..."

    repo_pkgs=()
    if ! xbps-query void-repo-nonfree >/dev/null 2>&1; then
        repo_pkgs+=("void-repo-nonfree")
    fi

    sys_arch=$(uname -m 2>/dev/null || echo "unknown")
    if [[ "$sys_arch" == "x86_64" ]]; then
        if ! xbps-query void-repo-multilib >/dev/null 2>&1; then
            repo_pkgs+=("void-repo-multilib")
        fi
        if ! xbps-query void-repo-multilib-nonfree >/dev/null 2>&1; then
            repo_pkgs+=("void-repo-multilib-nonfree")
        fi
    fi

    if ! xbps-query xmirror >/dev/null 2>&1; then
        repo_pkgs+=("xmirror")
    fi

    if [[ ${#repo_pkgs[@]} -gt 0 && $ENABLE_EXTRA_REPOS -eq 1 ]]; then
        msg_info "Enabling official Void Linux extra repositories (nonfree, multilib) & xmirror..."
        echo "  Packages to install: ${repo_pkgs[*]}"
        if [[ $AUTO_YES -eq 1 ]]; then
            do_repo_install="y"
        else
            echo ""
            read -rp "Install Void extra repositories (nonfree, multilib) and xmirror? [Y/n]: " do_repo_install
        fi
        if [[ ! "$do_repo_install" =~ ^[Nn]$ ]]; then
            msg_info "Installing repository packages (requires sudo)..."
            if sudo xbps-install -y "${repo_pkgs[@]}"; then
                msg_ok "Extra repositories and xmirror installed successfully."
            else
                msg_warn "Some repository packages failed to install, proceeding with existing repositories..."
            fi
        fi
    else
        msg_ok "Extra Void Linux repositories (nonfree, multilib) and xmirror are already configured."
    fi

    # Interactive Mirror Selection via xmirror
    if [[ $SETUP_MIRROR -eq 1 ]]; then
        if command -v xmirror >/dev/null 2>&1; then
            msg_info "Launching xmirror for mirror selection..."
            sudo xmirror
        else
            msg_warn "xmirror not found; skipping mirror selection."
        fi
    fi

    msg_info "Synchronizing XBPS repository indexes..."
    sudo xbps-install -S || msg_warn "Repository index synchronization completed with warnings."
fi

# ------------------------------------------------------------------------------
# 3. Package Installation (Void Linux XBPS)
# ------------------------------------------------------------------------------
if [[ $is_void -eq 1 && -f "$REPO_DIR/packages.void" ]]; then
    msg_info "Checking required XBPS packages against installed state..."
    pkg_file="$REPO_DIR/packages.void"    

    missing_packages=()
    while IFS= read -r raw_line; do
        # Strip comments and trim whitespace
        pkg=$(echo "$raw_line" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [[ -z "$pkg" ]] && continue

        # Special handling for mangowc (may be built from source / meson)
        if [[ "$pkg" == "mangowc" ]]; then
            if command -v mango >/dev/null 2>&1; then
                msg_ok "MangoWC binary ('mango') is already available."
                continue
            fi
            if xbps-query -R mangowc >/dev/null 2>&1; then
                if ! xbps-query mangowc >/dev/null 2>&1; then
                    missing_packages+=("mangowc")
                fi
            else
                msg_warn "MangoWC binary not in pre-built repository mirrors."
                msg_info "Install via void-packages: ./xbps-src pkg mangowc && xi mangowc"
                msg_info "Or build via meson: git clone https://github.com/mangowm/mango && cd mango && meson setup build && sudo ninja -C build install"
            fi
            continue
        fi

        # Special handling for mangobar (built from source via meson)
        if [[ "$pkg" == "mangobar" ]]; then
            if command -v mangobar >/dev/null 2>&1; then
                msg_ok "MangoBar binary ('mangobar') is already available."
                continue
            fi
            if xbps-query -R mangobar >/dev/null 2>&1; then
                if ! xbps-query mangobar >/dev/null 2>&1; then
                    missing_packages+=("mangobar")
                fi
            else
                msg_info "MangoBar will be built from source via meson in step 4."
            fi
            continue
        fi

        # Check if installed locally (xbps-query <pkg> returns 0 if installed, 2 if missing)
        if xbps-query "$pkg" >/dev/null 2>&1; then
            continue
        fi

        # Handle case-sensitivity fallback (e.g. waybar vs Waybar)
        resolved_pkg="$pkg"
        if ! xbps-query -R "$pkg" >/dev/null 2>&1; then
            candidate=$(xbps-query -Rs "$pkg" 2>/dev/null | awk '{print $2}' | cut -d- -f1 | grep -i "^${pkg}$" | head -n1 || true)
            if [[ -n "$candidate" ]]; then
                resolved_pkg="$candidate"
            fi
        fi

        if xbps-query "$resolved_pkg" >/dev/null 2>&1; then
            continue
        fi

        missing_packages+=("$resolved_pkg")
    done < "$pkg_file"

    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        msg_info "The following ${#missing_packages[@]} package(s) need installation:"
        echo "  ${missing_packages[*]}"
        echo ""
        if [[ $AUTO_YES -eq 1 ]]; then
            do_install="y"
        else
            read -rp "Install missing packages with xbps-install? [Y/n]: " do_install
        fi
        if [[ ! "$do_install" =~ ^[Nn]$ ]]; then
            msg_info "Installing packages (requires sudo)..."
            if ! sudo xbps-install -y "${missing_packages[@]}"; then
                msg_warn "Bulk installation encountered errors. Retrying missing packages individually..."
                for p in "${missing_packages[@]}"; do
                    if ! xbps-query "$p" >/dev/null 2>&1; then
                        sudo xbps-install -y "$p" || msg_warn "Package '$p' could not be installed."
                    fi
                done
            fi
            msg_ok "Package installation step completed."
        else
            msg_warn "Skipped package installation. Ensure required packages are installed manually."
        fi
    else
        msg_ok "All required XBPS packages are already installed."
    fi
fi

# ------------------------------------------------------------------------------
# 4. MangoBar Build & Installation (Source: https://github.com/mangowm/mangobar)
# ------------------------------------------------------------------------------
msg_info "Checking MangoBar (native status bar for MangoWC)..."

do_build_mangobar=0
if [[ $BUILD_MANGOBAR -eq 1 ]]; then
    do_build_mangobar=1
elif ! command -v mangobar >/dev/null 2>&1; then
    msg_info "MangoBar binary not found on system."
    if [[ $AUTO_YES -eq 1 || ! -t 0 ]]; then
        do_build_mangobar=1
    else
        echo ""
        read -rp "Build and install MangoBar from source (https://github.com/mangowm/mangobar)? [Y/n]: " mb_choice
        if [[ ! "$mb_choice" =~ ^[Nn]$ ]]; then
            do_build_mangobar=1
        fi
    fi
else
    msg_ok "MangoBar binary found at $(command -v mangobar)."
    if [[ $AUTO_YES -eq 0 && -t 0 ]]; then
        echo ""
        read -rp "Rebuild and reinstall MangoBar from source? [y/N]: " mb_rebuild
        if [[ "$mb_rebuild" =~ ^[Yy]$ ]]; then
            do_build_mangobar=1
        fi
    fi
fi

if [[ $do_build_mangobar -eq 1 ]]; then
    echo ""
    msg_info "Building and installing MangoBar from https://github.com/mangowm/mangobar..."

    # Ensure required build tools exist
    mb_build_tools=()
    for tool in meson ninja git pkg-config; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            mb_build_tools+=("$tool")
        fi
    done
    if [[ ${#mb_build_tools[@]} -gt 0 && $is_void -eq 1 ]]; then
        msg_info "Installing missing build tool(s): ${mb_build_tools[*]}..."
        sudo xbps-install -y "${mb_build_tools[@]}" || msg_warn "Some build tools could not be installed."
    fi

    BUILD_TMP=$(mktemp -d /tmp/mangobar-build-XXXXXX)
    msg_info "Fetching mangowm/mangobar into $BUILD_TMP..."
    clone_ok=0
    if git clone --depth 1 https://github.com/mangowm/mangobar.git "$BUILD_TMP" 2>/dev/null; then
        clone_ok=1
    elif [[ -d "$HOME/mangobar" && -f "$HOME/mangobar/meson.build" ]]; then
        msg_warn "Git clone failed; using local source tree at $HOME/mangobar..."
        cp -r "$HOME/mangobar"/* "$BUILD_TMP"/ 2>/dev/null || true
        clone_ok=1
    fi

    if [[ $clone_ok -eq 1 ]]; then
        pushd "$BUILD_TMP" >/dev/null
        built_ok=0
        msg_info "Configuring MangoBar build with meson (prefix=/usr)..."
        if meson setup build -Dprefix=/usr; then
            msg_info "Compiling MangoBar with ninja..."
            if ninja -C build -j"$(nproc 2>/dev/null || echo 2)"; then
                msg_info "Installing MangoBar via ninja install (requires sudo)..."
                if sudo ninja -C build install; then
                    built_ok=1
                else
                    msg_err "Failed to install MangoBar (ninja install returned non-zero)."
                fi
            else
                msg_err "Failed to compile MangoBar with ninja."
            fi
        else
            msg_err "Failed to configure MangoBar build with meson."
        fi
        popd >/dev/null
        rm -rf "$BUILD_TMP"

        if [[ $built_ok -eq 1 ]] || command -v mangobar >/dev/null 2>&1; then
            msg_ok "MangoBar built and installed successfully ($(command -v mangobar))."
        else
            msg_err "MangoBar build/install encountered errors."
        fi
    else
        msg_err "Failed to obtain MangoBar source code."
        rm -rf "$BUILD_TMP"
    fi
fi

# ------------------------------------------------------------------------------
# 5. Runit Services Configuration
# ------------------------------------------------------------------------------
if [[ $is_void -eq 1 ]]; then
    msg_info "Executing runit service setup..."
    bash "$REPO_DIR/system/services/runit-setup.sh"
fi

# ------------------------------------------------------------------------------
# 6. Configuration Backup & Symlinking (Idempotent)
# ------------------------------------------------------------------------------
msg_info "Setting up configuration symlinks..."
mkdir -p "$HOME/.config"

CONFIG_TARGETS=(
    "config/mango:mango"
    "config/mangobar:mangobar"
    "config/eww:eww"
    "config/rofi:rofi"
    "config/foot:foot"
    "config/mako:mako"
    "config/fontconfig:fontconfig"
    "config/thunar:Thunar"
    "config/gtk-3.0:gtk-3.0"
    "config/btop:btop"
    "themes:themes"
)

backup_needed=0

for target in "${CONFIG_TARGETS[@]}"; do
    src_rel="${target%%:*}"
    dst_name="${target##*:}"
    
    src_path="$REPO_DIR/$src_rel"
    dst_path="$HOME/.config/$dst_name"

    if [[ -e "$dst_path" || -L "$dst_path" ]]; then
        # 1. Check if already symlinked to our repo
        if [[ -L "$dst_path" && "$(readlink -f "$dst_path" 2>/dev/null || true)" == "$(readlink -f "$src_path" 2>/dev/null || true)" ]]; then
            msg_ok "Symlink '$dst_path' is already pointing to '$src_path'."
            continue
        fi

        # 2. Check if content is already identical (avoids creating unnecessary backup archive)
        if diff -rq "$dst_path" "$src_path" >/dev/null 2>&1; then
            rm -rf "$dst_path"
            ln -s "$src_path" "$dst_path"
            msg_ok "Config '$dst_path' matches repository; cleanly converted to symlink."
            continue
        fi

        # 3. Content differs: backup existing file/directory
        if [[ $backup_needed -eq 0 ]]; then
            mkdir -p "$BACKUP_DIR"
            msg_info "Backing up existing configurations to '$BACKUP_DIR'..."
            backup_needed=1
        fi
        
        mv "$dst_path" "$BACKUP_DIR/$dst_name"
        msg_ok "Backed up '$dst_path' -> '$BACKUP_DIR/$dst_name'."
    fi

    # Create symlink
    ln -s "$src_path" "$dst_path"
    msg_ok "Linked '$dst_path' -> '$src_path'."
done

# Ensure themes/foot.ini and config/foot/colors.ini exist for Foot terminal
if [[ ! -e "$REPO_DIR/themes/foot.ini" && -f "$REPO_DIR/themes/generated/foot.ini" ]]; then
    ln -sfn "generated/foot.ini" "$REPO_DIR/themes/foot.ini"
fi
if [[ ! -f "$REPO_DIR/config/foot/colors.ini" && -f "$REPO_DIR/themes/generated/foot.ini" ]]; then
    cp "$REPO_DIR/themes/generated/foot.ini" "$REPO_DIR/config/foot/colors.ini"
fi

# Symlink entire wm repository to ~/.config/wm for convenience (idempotent)
if [[ -L "$HOME/.config/wm" && "$(readlink -f "$HOME/.config/wm" 2>/dev/null || true)" == "$(readlink -f "$REPO_DIR" 2>/dev/null || true)" ]]; then
    msg_ok "Convenience link ~/.config/wm already points to $REPO_DIR."
else
    ln -sfn "$REPO_DIR" "$HOME/.config/wm"
fi

# Thunar xfconf configuration (~/.config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml)
mkdir -p "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
if [[ ! -f "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml" ]] || ! cmp -s "$REPO_DIR/config/thunar/thunar.xml" "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml"; then
    cp "$REPO_DIR/config/thunar/thunar.xml" "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml"
    msg_ok "Configured Thunar preferences (xfce4/thunar.xml)."
fi

# GTK 4.0 theme configuration (~/.config/gtk-4.0)
mkdir -p "$HOME/.config/gtk-4.0"
if [[ -f "$REPO_DIR/config/gtk-3.0/gtk.css" ]]; then
    ln -sf "$REPO_DIR/config/gtk-3.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
    ln -sf "$REPO_DIR/config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
    msg_ok "Configured GTK 4.0 dark theme symlinks."
fi

# GSettings synchronization for Wayland GTK apps (idempotent)
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface font-name 'Maple Mono 10' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null || true
    msg_ok "Configured GSettings (dark mode, Papirus-Dark, Maple Mono)."
fi

# ------------------------------------------------------------------------------
# 7. Font Installation (Idempotent)
# ------------------------------------------------------------------------------
msg_info "Checking bundled icon fonts..."
FONT_DIR="$HOME/.local/share/fonts/wm"
mkdir -p "$FONT_DIR"

fonts_updated=0
if [[ -d "$REPO_DIR/assets/fonts" ]]; then
    for font_file in "$REPO_DIR"/assets/fonts/*.ttf "$REPO_DIR"/assets/fonts/*.otf; do
        [[ -f "$font_file" ]] || continue
        font_base="$(basename "$font_file")"
        if [[ ! -f "$FONT_DIR/$font_base" ]] || ! cmp -s "$font_file" "$FONT_DIR/$font_base"; then
            cp "$font_file" "$FONT_DIR/$font_base"
            fonts_updated=1
        fi
    done

    if [[ $fonts_updated -eq 1 ]]; then
        if command -v fc-cache >/dev/null 2>&1; then
            fc-cache -f "$FONT_DIR"
            msg_ok "Icon fonts installed and font cache updated."
        fi
    else
        msg_ok "Icon fonts are already up to date in $FONT_DIR."
    fi
fi

# ------------------------------------------------------------------------------
# 8. Script Permissions & System Binaries (Idempotent)
# ------------------------------------------------------------------------------
msg_info "Setting script execution permissions..."
chmod +x "$REPO_DIR"/scripts/* "$REPO_DIR"/scripts/*/* "$REPO_DIR"/system/services/* 2>/dev/null || true
msg_ok "Scripts in scripts/ and system/services/ are executable."

# Symlink all desktop scripts to /usr/local/bin for global accessibility
if command -v sudo >/dev/null 2>&1; then
    sudo mkdir -p /usr/local/bin
    for script in "$REPO_DIR"/scripts/*/* "$REPO_DIR"/system/services/pipewire-launcher.sh; do
        if [[ -f "$script" && -x "$script" ]]; then
            script_name="$(basename "$script")"
            sudo ln -sf "$script" "/usr/local/bin/$script_name"
        fi
    done
    if command -v mango >/dev/null 2>&1 && ! command -v mangowc >/dev/null 2>&1; then
        sudo ln -sf "$(command -v mango)" /usr/local/bin/mangowc
    fi
    msg_ok "Desktop scripts and helpers linked into /usr/local/bin/."
fi

# Ensure user-local ~/.local/bin also has links
mkdir -p "$HOME/.local/bin"
for script in "$REPO_DIR"/scripts/*/* "$REPO_DIR"/system/services/pipewire-launcher.sh; do
    if [[ -f "$script" && -x "$script" ]]; then
        script_name="$(basename "$script")"
        ln -sf "$script" "$HOME/.local/bin/$script_name"
    fi
done
if command -v mango >/dev/null 2>&1 && ! command -v mangowc >/dev/null 2>&1; then
    ln -sf "$(command -v mango)" "$HOME/.local/bin/mangowc"
fi

# Wayland session desktop entry:
msg_info "Configuring Wayland session entry for MangoWC (dbus-run-session mangowc)..."
mkdir -p "$HOME/.local/share/wayland-sessions"
cp "$REPO_DIR/system/services/mango.desktop" "$HOME/.local/share/wayland-sessions/mango.desktop"

if command -v sudo >/dev/null 2>&1 && [[ -f "$REPO_DIR/system/services/mango.desktop" ]]; then
    sudo mkdir -p /usr/share/wayland-sessions
    sudo cp "$REPO_DIR/system/services/mango.desktop" /usr/share/wayland-sessions/mango.desktop
    msg_ok "Wayland session entry installed to /usr/share/wayland-sessions/mango.desktop."
elif [[ -f /usr/share/wayland-sessions/mango.desktop ]]; then
    msg_ok "Wayland session entry present (/usr/share/wayland-sessions/mango.desktop)."
fi

# List wayland session directory
if [[ -d /usr/share/wayland-sessions ]]; then
    msg_info "Listing /usr/share/wayland-sessions/:"
    ls -la /usr/share/wayland-sessions/
fi

# Verify Exec command in mango.desktop
if [[ -f /usr/share/wayland-sessions/mango.desktop ]]; then
    desktop_cmd=$(grep -E "^Exec=" /usr/share/wayland-sessions/mango.desktop | cut -d= -f2- || true)
    if [[ "$desktop_cmd" == "dbus-run-session mangowc" ]]; then
        msg_ok "Verified command in /usr/share/wayland-sessions/mango.desktop: '$desktop_cmd'"
    else
        msg_warn "Command in /usr/share/wayland-sessions/mango.desktop is '$desktop_cmd'."
        msg_info "To enforce 'dbus-run-session mangowc', run: sudo cp $REPO_DIR/system/services/mango.desktop /usr/share/wayland-sessions/"
    fi
fi

# Initialize dynamic wallpaper theme palette
if [[ -x "$REPO_DIR/scripts/theme/generate-palette" && -f "$REPO_DIR/wallpapers/nord.jpg" ]]; then
    if [[ ! -f "$REPO_DIR/themes/generated/palette.css" && ! -f "$REPO_DIR/themes/palette.css" ]]; then
        msg_info "Initializing dynamic theme palette..."
        "$REPO_DIR/scripts/theme/generate-palette" "$REPO_DIR/wallpapers/nord.jpg" >/dev/null 2>&1 || true
        msg_ok "Dynamic theme palette initialized."
    else
        msg_ok "Dynamic theme palette already active."
    fi
fi

# ------------------------------------------------------------------------------
# 9. Optional Login Manager Setup (Ly)
# ------------------------------------------------------------------------------
if [[ -z "$LOGIN_MANAGER" ]]; then
    # Detect if Ly is already installed and enabled as a service
    ly_is_installed=0
    if command -v ly >/dev/null 2>&1; then
        ly_is_installed=1
    fi

    ly_is_enabled=0
    if [[ -e /var/service/ly || -L /var/service/ly || -e /var/service/ly-runit-service || -L /var/service/ly-runit-service ]]; then
        ly_is_enabled=1
    elif command -v systemctl >/dev/null 2>&1 && systemctl is-enabled ly >/dev/null 2>&1; then
        ly_is_enabled=1
    fi

    if [[ $ly_is_installed -eq 1 && $ly_is_enabled -eq 1 ]]; then
        msg_ok "Ly login manager is already installed and enabled (skipping prompt)."
        LOGIN_MANAGER="ly"
    elif [[ $AUTO_YES -eq 1 ]]; then
        LOGIN_MANAGER="none"
    elif [[ -t 0 ]]; then
        echo ""
        read -rp "Would you like to configure Ly as your login manager? [y/N]: " ly_choice
        if [[ "$ly_choice" =~ ^[Yy]$ ]]; then
            LOGIN_MANAGER="ly"
        else
            LOGIN_MANAGER="none"
        fi
    else
        LOGIN_MANAGER="none"
    fi
fi

if [[ "$LOGIN_MANAGER" == "ly" ]]; then
    echo ""
    msg_info "Configuring Ly login manager..."

    # Ensure Ly binary is installed
    if ! command -v ly >/dev/null 2>&1 || [[ $BUILD_LY -eq 1 ]]; then
        msg_info "Building and installing Ly from https://github.com/fairyglade/ly..."
        if [[ $is_void -eq 1 ]]; then
            sudo xbps-install -y pam-devel libxcb-devel git make || true
        fi

        BUILD_TMP=$(mktemp -d /tmp/ly-build-XXXXXX)
        msg_info "Cloning fairyglade/ly into $BUILD_TMP..."
        if git clone --depth 1 https://github.com/fairyglade/ly.git "$BUILD_TMP"; then
            pushd "$BUILD_TMP" >/dev/null
            built_ok=0
            if [[ -f Makefile || -f makefile ]]; then
                msg_info "Compiling Ly with make..."
                if make -j"$(nproc 2>/dev/null || echo 2)"; then
                    msg_info "Installing Ly via make install..."
                    sudo make install && built_ok=1
                    if [[ -d res/ly-runit-service ]]; then
                        sudo make installrunit 2>/dev/null || true
                    fi
                fi
            elif command -v zig >/dev/null 2>&1; then
                msg_info "Compiling and installing Ly with zig..."
                if zig build -Doptimize=ReleaseSmall; then
                    sudo zig build installnoconf -Dinit_system=runit -Doptimize=ReleaseSmall && built_ok=1
                fi
            else
                msg_err "Neither makefile nor zig compiler found to build Ly."
            fi
            popd >/dev/null
            rm -rf "$BUILD_TMP"

            if [[ $built_ok -eq 1 ]] || command -v ly >/dev/null 2>&1; then
                msg_ok "Ly successfully built and installed."
            else
                msg_err "Failed to compile/install Ly from https://github.com/fairyglade/ly."
            fi
        else
            msg_err "Failed to clone https://github.com/fairyglade/ly.git"
            rm -rf "$BUILD_TMP"
        fi
    else
        msg_ok "Ly binary found at $(command -v ly)."
    fi

    # Ensure /etc/pam.d/ly exists for authentication
    if command -v sudo >/dev/null 2>&1 && [[ ! -f /etc/pam.d/ly ]]; then
        sudo mkdir -p /etc/pam.d
        if [[ -f /etc/pam.d/login ]]; then
            msg_info "Creating default PAM configuration for Ly (/etc/pam.d/ly)..."
            sudo cp /etc/pam.d/login /etc/pam.d/ly
            msg_ok "Created /etc/pam.d/ly from system login PAM."
        fi
    fi

    # Ensure runit service definition exists (supporting /etc/sv/ly and /etc/sv/ly-runit-service)
    if command -v sudo >/dev/null 2>&1; then
        if [[ -d /etc/sv/ly-runit-service && ! -d /etc/sv/ly ]]; then
            sudo ln -sfn /etc/sv/ly-runit-service /etc/sv/ly
            msg_ok "Configured service alias: /etc/sv/ly -> /etc/sv/ly-runit-service."
        elif [[ ! -d /etc/sv/ly ]]; then
            msg_info "Creating runit service definition for Ly (/etc/sv/ly)..."
            sudo mkdir -p /etc/sv/ly
            cat <<'EOF' | sudo tee /etc/sv/ly/run >/dev/null
#!/bin/sh
exec 2>&1
exec ly
EOF
            sudo chmod +x /etc/sv/ly/run
            msg_ok "Created /etc/sv/ly/run."
        fi
    fi

    # Ensure config.lua does not override config.ini if config.ini is deployed
    if [[ -f /etc/ly/config.lua ]]; then
        sudo mv /etc/ly/config.lua /etc/ly/config.lua.bak."$TIMESTAMP"
        msg_info "Archived /etc/ly/config.lua to ensure repository config.ini is active."
    fi

    # Deploy Nord-themed Ly config idempotently
    if [[ -f "$REPO_DIR/config/ly/config.ini" ]]; then
        sudo mkdir -p /etc/ly
        if [[ -f /etc/ly/config.ini ]]; then
            if ! cmp -s "$REPO_DIR/config/ly/config.ini" /etc/ly/config.ini; then
                ly_backup="/etc/ly/config.ini.bak.$TIMESTAMP"
                msg_info "Backing up existing /etc/ly/config.ini to $ly_backup..."
                sudo cp /etc/ly/config.ini "$ly_backup"
                sudo cp "$REPO_DIR/config/ly/config.ini" /etc/ly/config.ini
                msg_ok "Updated /etc/ly/config.ini (backup created at $ly_backup)."
            else
                msg_ok "/etc/ly/config.ini is already up to date with repository theme."
            fi
        else
            msg_info "Deploying Nord-themed Ly configuration to /etc/ly/config.ini..."
            sudo cp "$REPO_DIR/config/ly/config.ini" /etc/ly/config.ini
            msg_ok "Deployed /etc/ly/config.ini."
        fi
    fi

    # Handle runit service enablement on Void Linux
    if [[ $is_void -eq 1 && -d /var/service ]]; then
        # Check for competing display managers
        competing_dms=()
        for dm in "sddm" "lightdm" "gdm" "lxdm" "greetd"; do
            if [[ -e "/var/service/$dm" || -L "/var/service/$dm" ]]; then
                competing_dms+=("$dm")
            fi
        done

        if [[ ${#competing_dms[@]} -gt 0 ]]; then
            msg_warn "Competing display manager(s) detected in /var/service/: ${competing_dms[*]}"
            msg_warn "Under Void Linux runit, only one display manager may be enabled at a time."
            if [[ $AUTO_YES -eq 1 ]]; then
                disable_choice="y"
            else
                read -rp "Disable competing display manager(s) to allow Ly to run? [y/N]: " disable_choice
            fi
            if [[ "$disable_choice" =~ ^[Yy]$ ]]; then
                for dm in "${competing_dms[@]}"; do
                    sudo rm -f "/var/service/$dm"
                    msg_ok "Disabled /var/service/$dm."
                done
            else
                msg_warn "Ly service enablement skipped to avoid display manager conflict."
            fi
        fi

        # If no competing DM is active, enable Ly
        if [[ ! -e /var/service/sddm && ! -e /var/service/lightdm && ! -e /var/service/gdm && ! -e /var/service/greetd ]]; then
            target_sv=""
            if [[ -d /etc/sv/ly ]]; then
                target_sv="ly"
            elif [[ -d /etc/sv/ly-runit-service ]]; then
                target_sv="ly-runit-service"
            fi

            if [[ -n "$target_sv" ]]; then
                # Prevent TTY2 conflict if agetty-tty2 is active
                if [[ -e /var/service/agetty-tty2 || -L /var/service/agetty-tty2 ]]; then
                    msg_info "Disabling agetty-tty2 in /var/service/ to prevent TTY collision with Ly..."
                    sudo rm -f /var/service/agetty-tty2
                    msg_ok "Disabled conflicting /var/service/agetty-tty2."
                fi
                if [[ ! -e /var/service/ly && ! -L /var/service/ly && ! -e /var/service/ly-runit-service && ! -L /var/service/ly-runit-service ]]; then
                    msg_info "Enabling Ly runit service in /var/service/..."
                    sudo ln -s "/etc/sv/$target_sv" /var/service/
                    msg_ok "Ly runit service enabled (/var/service/$target_sv)."
                else
                    msg_ok "Ly service is already enabled in /var/service/."
                fi
            else
                msg_warn "Service definition for Ly not found in /etc/sv/."
                msg_info "Once Ly is installed, enable with: sudo ln -s /etc/sv/ly /var/service/"
            fi
        fi
    fi
elif [[ "$LOGIN_MANAGER" != "none" ]]; then
    msg_warn "Unknown login manager option: '$LOGIN_MANAGER'. Valid options: 'ly', 'none'."
fi

# ------------------------------------------------------------------------------
# 10. System Verification (wm-doctor)
# ------------------------------------------------------------------------------
echo ""
msg_info "Running wm-doctor system diagnosis..."
echo ""
bash "$REPO_DIR/scripts/diagnostics/wm-doctor" || true

echo ""
echo -e "${BOLD}========================================================${RESET}"
echo -e "${BOLD}                Installation Complete!                  ${RESET}"
echo -e "${BOLD}========================================================${RESET}"
echo ""
if [[ $backup_needed -eq 1 ]]; then
    echo "Previous configurations were backed up to:"
    echo "  $BACKUP_DIR"
    echo "To revert changes: cp -r $BACKUP_DIR/* ~/.config/"
    echo ""
fi
if [[ "$LOGIN_MANAGER" == "ly" ]]; then
    echo "Boot flow: System will boot directly into Ly login manager on TTY2."
    echo "Select 'MangoWC' session to log into the desktop."
    echo ""
fi
echo "To start the desktop session manually from any TTY:"
echo -e "  ${BOLD}start-mango${RESET}  or  ${BOLD}$REPO_DIR/scripts/system/start-mango${RESET}"
echo ""
echo "Key shortcuts cheatsheet:"
echo "  Super + Return : Foot Terminal"
echo "  Super + E      : Thunar File Manager"
echo "  Super + D / Spc: Rofi Application Launcher"
echo "  Super + Q      : Close Focused Window"
echo "  Super + Esc    : Power Menu (Rofi)"
echo "  Super + Shift+W: Wallpaper Selector (Rofi)"
echo "  Super + T      : Theme Selector (Rofi)"
echo "  Super + V      : Clipboard History (Rofi)"
echo "  Super + S / Prt: Screenshot Menu (Rofi)"
echo ""
