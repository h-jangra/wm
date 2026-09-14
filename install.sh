#!/usr/bin/env bash
# ==============================================================================
# install.sh: Void Linux Desktop Installer
# Configures MangoWC, Waybar, Rofi, Foot, PipeWire, runit, and optional Ly DM.
#
# Idempotent, safe to run multiple times, backs up existing configs.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

while [[ $# -gt 0 ]]; do
    case "$1" in
        --login-manager)
            LOGIN_MANAGER="$2"
            shift 2
            ;;
        --login-manager=*)
            LOGIN_MANAGER="${1#*=}"
            shift 1
            ;;
        -h|--help)
            echo "Usage: ./install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --login-manager <ly|none>   Configure preferred login manager (optional, default: prompt or none)"
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
    read -rp "Would you like to proceed with configuration symlinking only? [y/N]: " choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
        msg_err "Installation aborted by user on non-Void system."
        exit 1
    fi
else
    msg_ok "Void Linux detected successfully."
fi

# ------------------------------------------------------------------------------
# 2. Package Installation (Void Linux XBPS only)
# ------------------------------------------------------------------------------
if [[ $is_void -eq 1 && -f "$SCRIPT_DIR/packages.void" ]]; then
    msg_info "Checking required XBPS packages..."
    
    missing_packages=()
    while IFS= read -r pkg; do
        [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue

        # Special handling for mangowc (may be installed via xbps-src or source)
        if [[ "$pkg" == "mangowc" ]]; then
            if command -v mango >/dev/null 2>&1; then
                msg_ok "MangoWC binary ('mango') is already available."
                continue
            fi
            # Check if available in binary repo pool
            if xbps-query -Rs mangowc >/dev/null 2>&1; then
                missing_packages+=("mangowc")
            else
                msg_warn "MangoWC is not yet in pre-built binary mirrors."
                msg_info "Install via void-packages: ./xbps-src pkg mangowc && xi mangowc"
                msg_info "Or build via meson: git clone https://github.com/mangowm/mango && cd mango && meson setup build && ninja -C build && sudo ninja -C build install"
            fi
            continue
        fi

        if ! xbps-query -s "$pkg" >/dev/null 2>&1; then
            missing_packages+=("$pkg")
        fi
    done < "$SCRIPT_DIR/packages.void"

    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        msg_info "The following ${#missing_packages[@]} package(s) need installation:"
        echo "  ${missing_packages[*]}"
        echo ""
        read -rp "Install missing packages with xbps-install? [Y/n]: " do_install
        if [[ ! "$do_install" =~ ^[Nn]$ ]]; then
            msg_info "Installing packages (requires sudo)..."
            sudo xbps-install -Sy "${missing_packages[@]}"
            msg_ok "Packages installed successfully."
        else
            msg_warn "Skipped package installation. Ensure required packages are installed manually."
        fi
    else
        msg_ok "All required XBPS packages are already installed."
    fi
fi

# ------------------------------------------------------------------------------
# 3. Runit Services Configuration
# ------------------------------------------------------------------------------
if [[ $is_void -eq 1 ]]; then
    msg_info "Executing runit service setup..."
    bash "$SCRIPT_DIR/services/runit-setup.sh"
fi

# ------------------------------------------------------------------------------
# 4. Configuration Backup & Symlinking
# ------------------------------------------------------------------------------
msg_info "Setting up configuration symlinks..."
mkdir -p "$HOME/.config"

CONFIG_TARGETS=(
    "mango:mango"
    "waybar:waybar"
    "rofi:rofi"
    "terminal/foot:foot"
    "mako:mako"
)

backup_needed=0

for target in "${CONFIG_TARGETS[@]}"; do
    src_rel="${target%%:*}"
    dst_name="${target##*:}"
    
    src_path="$SCRIPT_DIR/$src_rel"
    dst_path="$HOME/.config/$dst_name"

    if [[ -e "$dst_path" || -L "$dst_path" ]]; then
        # Check if already symlinked to our repo
        if [[ -L "$dst_path" && "$(readlink -f "$dst_path")" == "$(readlink -f "$src_path")" ]]; then
            msg_ok "Symlink '$dst_path' is already pointing to '$src_path'."
            continue
        fi

        # Backup existing file/directory
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

# Symlink entire wm repository to ~/.config/wm for convenience
if [[ ! -e "$HOME/.config/wm" ]]; then
    ln -s "$SCRIPT_DIR" "$HOME/.config/wm"
    msg_ok "Created convenience link: ~/.config/wm -> $SCRIPT_DIR"
fi

# ------------------------------------------------------------------------------
# 5. Font Installation
# ------------------------------------------------------------------------------
msg_info "Installing bundled icon fonts..."
FONT_DIR="$HOME/.local/share/fonts/wm"
mkdir -p "$FONT_DIR"

if [[ -d "$SCRIPT_DIR/fonts" ]]; then
    cp -u "$SCRIPT_DIR"/fonts/*.ttf "$FONT_DIR/" 2>/dev/null || cp "$SCRIPT_DIR"/fonts/*.ttf "$FONT_DIR/"
    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$FONT_DIR"
        msg_ok "Icon fonts installed and font cache updated."
    fi
fi

# ------------------------------------------------------------------------------
# 6. Script Permissions & System Binaries
# ------------------------------------------------------------------------------
msg_info "Setting script execution permissions..."
chmod +x "$SCRIPT_DIR"/scripts/*
chmod +x "$SCRIPT_DIR"/services/*
msg_ok "Scripts in scripts/ and services/ are executable."

# Symlink all desktop scripts to /usr/local/bin for global accessibility
if command -v sudo >/dev/null 2>&1; then
    sudo mkdir -p /usr/local/bin
    for script in "$SCRIPT_DIR"/scripts/* "$SCRIPT_DIR"/services/pipewire-launcher.sh; do
        if [[ -f "$script" && -x "$script" ]]; then
            script_name="$(basename "$script")"
            sudo ln -sf "$script" "/usr/local/bin/$script_name"
        fi
    done
    msg_ok "Desktop scripts and helpers linked into /usr/local/bin/."
fi

# Ensure user-local ~/.local/bin also has links
mkdir -p "$HOME/.local/bin"
for script in "$SCRIPT_DIR"/scripts/* "$SCRIPT_DIR"/services/pipewire-launcher.sh; do
    if [[ -f "$script" && -x "$script" ]]; then
        script_name="$(basename "$script")"
        ln -sf "$script" "$HOME/.local/bin/$script_name"
    fi
done

# Wayland session desktop entry:
# When installing mangowc, upstream automatically creates /usr/share/wayland-sessions/mango.desktop.
# Only deploy our fallback template if /usr/share/wayland-sessions/mango.desktop does not already exist.
if [[ -f /usr/share/wayland-sessions/mango.desktop ]]; then
    msg_ok "Wayland session entry present (/usr/share/wayland-sessions/mango.desktop, provided by mangowc)."
elif command -v sudo >/dev/null 2>&1 && [[ -f "$SCRIPT_DIR/services/mango.desktop" ]]; then
    msg_info "Installing fallback Wayland session file to /usr/share/wayland-sessions/..."
    sudo mkdir -p /usr/share/wayland-sessions
    sudo cp "$SCRIPT_DIR/services/mango.desktop" /usr/share/wayland-sessions/mango.desktop
    msg_ok "Wayland session entry installed (/usr/share/wayland-sessions/mango.desktop)."
fi

# Initialize dynamic wallpaper theme palette
if [[ -x "$SCRIPT_DIR/scripts/generate-palette" ]]; then
    msg_info "Initializing dynamic theme palette..."
    "$SCRIPT_DIR/scripts/generate-palette" "$SCRIPT_DIR/wallpapers/nord.jpg" >/dev/null 2>&1 || true
    msg_ok "Dynamic theme palette initialized."
fi

# ------------------------------------------------------------------------------
# 7. Optional Login Manager Setup (Ly)
# ------------------------------------------------------------------------------
if [[ -z "$LOGIN_MANAGER" ]]; then
    if [[ -t 0 ]]; then
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

    # Check if ly binary is available
    if ! command -v ly >/dev/null 2>&1; then
        msg_warn "Ly executable ('ly') is not currently found in PATH."
        if [[ $is_void -eq 1 ]]; then
            if xbps-query -Rs ly >/dev/null 2>&1; then
                read -rp "Install Ly from XBPS repository? [Y/n]: " install_ly_choice
                if [[ ! "$install_ly_choice" =~ ^[Nn]$ ]]; then
                    sudo xbps-install -Sy ly || true
                fi
            else
                msg_info "Ly is not in default pre-built XBPS binary mirrors."
                msg_info "Install via void-packages or compile from source (see ly/README.md)."
                msg_info "Deploying Ly configuration now so it is ready once installed."
            fi
        fi
    else
        msg_ok "Ly binary found at $(command -v ly)."
    fi

    # Backup existing /etc/ly/config.ini if present
    sudo mkdir -p /etc/ly
    if [[ -f /etc/ly/config.ini ]]; then
        ly_backup="/etc/ly/config.ini.bak.$TIMESTAMP"
        msg_info "Backing up existing /etc/ly/config.ini to $ly_backup..."
        sudo cp /etc/ly/config.ini "$ly_backup"
        msg_ok "Backup created: $ly_backup."
    fi

    # Deploy Nord-themed Ly config
    msg_info "Deploying Nord-themed Ly configuration to /etc/ly/config.ini..."
    sudo cp "$SCRIPT_DIR/ly/config.ini" /etc/ly/config.ini
    msg_ok "Deployed /etc/ly/config.ini."

    # Handle runit service enablement on Void Linux
    if [[ $is_void -eq 1 && -d /var/service ]]; then
        # Check for competing display managers
        competing_dms=()
        for dm in "sddm" "lightdm" "gdm" "lxdm" "greetd"; do
            if [[ -e "/var/service/$dm" ]]; then
                competing_dms+=("$dm")
            fi
        done

        if [[ ${#competing_dms[@]} -gt 0 ]]; then
            msg_warn "Competing display manager(s) detected in /var/service/: ${competing_dms[*]}"
            msg_warn "Under Void Linux runit, only one display manager may be enabled at a time."
            read -rp "Disable competing display manager(s) to allow Ly to run? [y/N]: " disable_choice
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
            if [[ -d /etc/sv/ly ]]; then
                # Prevent TTY2 conflict if agetty-tty2 is active
                if [[ -e /var/service/agetty-tty2 ]]; then
                    msg_info "Disabling agetty-tty2 in /var/service/ to prevent TTY collision with Ly..."
                    sudo rm -f /var/service/agetty-tty2
                fi
                if [[ ! -e /var/service/ly ]]; then
                    msg_info "Enabling Ly runit service in /var/service/..."
                    sudo ln -s /etc/sv/ly /var/service/
                    msg_ok "Ly runit service enabled."
                else
                    msg_ok "Ly service is already enabled in /var/service/."
                fi
            else
                msg_warn "Service definition /etc/sv/ly not found."
                msg_info "Once Ly is installed, enable with: sudo ln -s /etc/sv/ly /var/service/"
            fi
        fi
    fi
elif [[ "$LOGIN_MANAGER" != "none" ]]; then
    msg_warn "Unknown login manager option: '$LOGIN_MANAGER'. Valid options: 'ly', 'none'."
fi

# ------------------------------------------------------------------------------
# 8. System Verification (wm-doctor)
# ------------------------------------------------------------------------------
echo ""
msg_info "Running wm-doctor system diagnosis..."
echo ""
bash "$SCRIPT_DIR/scripts/wm-doctor" || true

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
echo -e "  ${BOLD}start-mango${RESET}  or  ${BOLD}$SCRIPT_DIR/scripts/start-mango${RESET}"
echo ""
echo "Key shortcuts cheatsheet:"
echo "  Super + Return : Foot Terminal"
echo "  Super + D      : Rofi Application Launcher"
echo "  Super + Q      : Close Focused Window"
echo "  Super + X      : Power Menu (Lock, Suspend, Reboot, Shutdown)"
echo "  Super + W      : Wallpaper Menu"
echo "  Super + N      : Wi-Fi Menu"
echo "  Super + B      : Bluetooth Menu"
echo "  Super + A      : Audio Output/Input Menu"
echo "  Super + S      : Screenshot Menu"
echo ""
