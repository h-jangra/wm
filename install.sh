#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$HOME/.config/wm-backups-$TIMESTAMP"

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
BOLD='\033[1m'
RESET='\033[0m'

msg_info() { echo -e "${BLUE}[INFO]${RESET} $*"; }
msg_ok()   { echo -e "${GREEN}[OK]${RESET} $*"; }
msg_warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
msg_err()  { echo -e "${RED}[ERROR]${RESET} $*"; }

detect_platform() {
    local os_id=""
    local id_like=""
    local os_release_file="${1:-/etc/os-release}"

    if [[ -f "$os_release_file" ]]; then
        os_id=$(grep -E '^ID=' "$os_release_file" | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
        id_like=$(grep -E '^ID_LIKE=' "$os_release_file" | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]' || true)
    fi

    case "$os_id" in
        void)
            DISTRO_ID="void"
            DISTRO_NAME="Void Linux"
            ;;
        arch|archarm|endeavouros|manjaro|cachyos|garuda|artix)
            DISTRO_ID="arch"
            DISTRO_NAME="Arch Linux"
            ;;
        debian|ubuntu|linuxmint|pop|elementary|zorin|kali|raspbian)
            DISTRO_ID="debian"
            DISTRO_NAME="Debian/Ubuntu"
            ;;
        *)
            if [[ "$id_like" =~ (arch) ]]; then
                DISTRO_ID="arch"
                DISTRO_NAME="Arch Linux"
            elif [[ "$id_like" =~ (debian|ubuntu) ]]; then
                DISTRO_ID="debian"
                DISTRO_NAME="Debian/Ubuntu"
            elif command -v xbps-install >/dev/null 2>&1; then
                DISTRO_ID="void"
                DISTRO_NAME="Void Linux"
            elif command -v pacman >/dev/null 2>&1; then
                DISTRO_ID="arch"
                DISTRO_NAME="Arch Linux"
            elif command -v apt-get >/dev/null 2>&1; then
                DISTRO_ID="debian"
                DISTRO_NAME="Debian/Ubuntu"
            else
                DISTRO_ID="unknown"
                DISTRO_NAME="Unknown Linux (${os_id:-unknown})"
            fi
            ;;
    esac

    case "$DISTRO_ID" in
        void)
            INIT_SYSTEM="runit"
            ;;
        arch|debian)
            INIT_SYSTEM="systemd"
            ;;
        *)
            if [[ -d /run/systemd/system ]] || pidof systemd >/dev/null 2>&1; then
                INIT_SYSTEM="systemd"
            elif [[ -d /var/service && -d /etc/sv ]] || [[ -d /run/runit ]]; then
                INIT_SYSTEM="runit"
            else
                INIT_SYSTEM="unknown"
            fi
            ;;
    esac

    case "$DISTRO_ID" in
        void)
            PKG_MANAGER="xbps"
            PKG_MANIFEST="$REPO_DIR/packages.void"
            ;;
        arch)
            PKG_MANAGER="pacman"
            PKG_MANIFEST="$REPO_DIR/packages.arch"
            ;;
        debian)
            PKG_MANAGER="apt"
            PKG_MANIFEST="$REPO_DIR/packages.debian"
            ;;
        *)
            if command -v xbps-install >/dev/null 2>&1; then
                PKG_MANAGER="xbps"
                PKG_MANIFEST="$REPO_DIR/packages.void"
            elif command -v pacman >/dev/null 2>&1; then
                PKG_MANAGER="pacman"
                PKG_MANIFEST="$REPO_DIR/packages.arch"
            elif command -v apt-get >/dev/null 2>&1; then
                PKG_MANAGER="apt"
                PKG_MANIFEST="$REPO_DIR/packages.debian"
            else
                PKG_MANAGER="unknown"
                PKG_MANIFEST=""
            fi
            ;;
    esac
}

init_distro_vars() {
    case "$DISTRO_ID" in
        void)
            BUILD_DEPS_LY=(pam-devel base-devel libxcb-devel git xz)
            BUILD_DEPS_MANGOBAR=(meson ninja pkg-config wayland-devel wayland-protocols fcft-devel pixman-devel cairo-devel pango-devel pulseaudio-devel eudev-libudev-devel gdk-pixbuf-devel cJSON-devel basu-devel git)
            ESSENTIAL_SERVICES=(dbus elogind NetworkManager bluetoothd polkitd)
            HARDWARE_GROUPS=(video audio input network bluetooth poweroff)
            COMPETING_DMS=(sddm lightdm gdm lxdm greetd)
            ;;
        arch)
            BUILD_DEPS_LY=(pam base-devel libxcb git xz)
            BUILD_DEPS_MANGOBAR=(meson ninja pkgconf wayland wayland-protocols fcft pixman cairo pango libpulse systemd gdk-pixbuf2 cjson git)
            ESSENTIAL_SERVICES=(dbus NetworkManager bluetooth)
            HARDWARE_GROUPS=(video audio input network bluetooth poweroff)
            COMPETING_DMS=(sddm lightdm gdm lxdm greetd)
            ;;
        debian)
            BUILD_DEPS_LY=(libpam0g-dev base-devel libxcb1-dev libxcb-xkb-dev git xz)
            BUILD_DEPS_MANGOBAR=(meson ninja-build pkg-config libwayland-dev wayland-protocols libfcft-dev libpixman-1-dev libcairo2-dev libpango1.0-dev libpulse-dev libudev-dev libgdk-pixbuf-2.0-dev libcjson-dev libbasu-dev git)
            ESSENTIAL_SERVICES=(dbus NetworkManager bluetooth)
            HARDWARE_GROUPS=(video audio input netdev bluetooth poweroff)
            COMPETING_DMS=(sddm lightdm gdm lxdm greetd)
            ;;
        *)
            BUILD_DEPS_LY=(git base-devel xz)
            BUILD_DEPS_MANGOBAR=(meson ninja git pkg-config)
            ESSENTIAL_SERVICES=()
            HARDWARE_GROUPS=(video audio input bluetooth poweroff)
            COMPETING_DMS=(sddm lightdm gdm lxdm greetd)
            ;;
    esac
}

pkg_sync() {
    msg_info "Synchronizing package repository indexes ($PKG_MANAGER)..."
    case "$PKG_MANAGER" in
        xbps)
            sudo xbps-install -S || msg_warn "XBPS index synchronization completed with warnings."
            ;;
        pacman)
            sudo pacman -Sy || msg_warn "Pacman index synchronization completed with warnings."
            ;;
        apt)
            sudo DEBIAN_FRONTEND=noninteractive apt-get update || msg_warn "APT update completed with warnings."
            ;;
        *)
            msg_warn "Unknown package manager; skipping repository index sync."
            ;;
    esac
}

pkg_is_installed() {
    local pkg="$1"
    case "$PKG_MANAGER" in
        xbps)
            xbps-query "$pkg" >/dev/null 2>&1
            ;;
        pacman)
            pacman -Q "$pkg" >/dev/null 2>&1
            ;;
        apt)
            dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"
            ;;
        *)
            command -v "$pkg" >/dev/null 2>&1
            ;;
    esac
}

pkg_resolve_name() {
    local pkg="$1"
    case "$PKG_MANAGER" in
        xbps)
            if ! xbps-query -R "$pkg" >/dev/null 2>&1; then
                local candidate
                candidate=$(xbps-query -Rs "$pkg" 2>/dev/null | awk '{print $2}' | cut -d- -f1 | grep -i "^${pkg}$" | head -n1 || true)
                if [[ -n "$candidate" ]]; then
                    echo "$candidate"
                    return 0
                fi
            fi
            ;;
        pacman)
            if [[ "$pkg" == "rofi" ]] && ! pacman -Si rofi >/dev/null 2>&1 && pacman -Si rofi-wayland >/dev/null 2>&1; then
                echo "rofi-wayland"
                return 0
            fi
            ;;
        apt)
            if ! apt-cache show "$pkg" >/dev/null 2>&1; then
                if [[ "$pkg" == "rofi-wayland" ]] && apt-cache show rofi >/dev/null 2>&1; then
                    echo "rofi"
                    return 0
                elif [[ "$pkg" == "mako" ]] && apt-cache show mako-notifier >/dev/null 2>&1; then
                    echo "mako-notifier"
                    return 0
                elif [[ "$pkg" == "fd" ]] && apt-cache show fd-find >/dev/null 2>&1; then
                    echo "fd-find"
                    return 0
                fi
            fi
            ;;
    esac
    echo "$pkg"
}

pkg_install() {
    local pkgs=("$@")
    [[ ${#pkgs[@]} -eq 0 ]] && return 0
    case "$PKG_MANAGER" in
        xbps)
            sudo xbps-install -y "${pkgs[@]}"
            ;;
        pacman)
            sudo pacman -S --needed --noconfirm "${pkgs[@]}"
            ;;
        apt)
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
            ;;
        *)
            msg_err "Cannot install packages: unknown package manager '$PKG_MANAGER'."
            return 1
            ;;
    esac
}

pkg_setup_repos() {
    local enable_extra="${1:-1}"
    local auto_yes="${2:-0}"

    case "$DISTRO_ID" in
        void)
            msg_info "Checking Void Linux repositories..."
            local repo_pkgs=()
            if ! xbps-query void-repo-nonfree >/dev/null 2>&1; then
                repo_pkgs+=("void-repo-nonfree")
            fi

            local sys_arch
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

            if [[ ${#repo_pkgs[@]} -gt 0 && $enable_extra -eq 1 ]]; then
                msg_info "Enabling official Void Linux extra repositories (nonfree, multilib) & xmirror..."
                echo "  Packages to install: ${repo_pkgs[*]}"
                local do_repo_install="y"
                if [[ $auto_yes -ne 1 && -t 0 ]]; then
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
            ;;
        arch)
            msg_info "Checking Arch Linux repositories..."
            if [[ "$(uname -m 2>/dev/null)" == "x86_64" ]] && [[ -f /etc/pacman.conf ]]; then
                if grep -q "^\[multilib\]" /etc/pacman.conf; then
                    msg_ok "Arch multilib repository is active."
                fi
            fi
            ;;
        debian)
            msg_ok "APT repository configuration verified."
            ;;
        *)
            ;;
    esac
}

pkg_setup_mirror() {
    case "$DISTRO_ID" in
        void)
            if command -v xmirror >/dev/null 2>&1; then
                msg_info "Launching xmirror for mirror selection..."
                sudo xmirror
            else
                msg_warn "xmirror not found; skipping mirror selection."
            fi
            ;;
        arch)
            if command -v reflector >/dev/null 2>&1; then
                msg_info "Running reflector to update Arch mirrorlist..."
                sudo reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
            fi
            ;;
        *)
            msg_warn "Mirror selection is not supported on this platform."
            ;;
    esac
}

get_zig_url() {
    curl -fsSL https://ziglang.org/download/index.json | jq -r '.["0.16.0"]["x86_64-linux"].tarball'
}

install_zig() {
    msg_info "Installing Zig from official binary release..."
    local zig_url
    zig_url=$(get_zig_url)
    msg_info "Downloading Zig from: $zig_url"

    local tmp_dir
    tmp_dir=$(mktemp -d /tmp/zig-install-XXXXXX)
    local archive="$tmp_dir/zig.tar.xz"

    if curl -fSL --progress-bar "$zig_url" -o "$archive" 2>/dev/null || wget -q --show-progress -O "$archive" "$zig_url"; then
        msg_info "Extracting Zig..."
        mkdir -p "$tmp_dir/extracted"
        tar -xf "$archive" -C "$tmp_dir/extracted" --strip-components=1

        if [[ -f "$tmp_dir/extracted/zig" ]]; then
            sudo mkdir -p /opt
            sudo rm -rf /opt/zig
            sudo mv "$tmp_dir/extracted" /opt/zig
            sudo mkdir -p /usr/local/bin
            sudo ln -sf /opt/zig/zig /usr/local/bin/zig
            if [[ -L /usr/sbin/zig || -e /usr/sbin/zig ]]; then
                sudo ln -sf /opt/zig/zig /usr/sbin/zig
            fi
            if [[ -L /usr/bin/zig || -e /usr/bin/zig ]]; then
                sudo ln -sf /opt/zig/zig /usr/bin/zig
            fi
            export PATH="/usr/local/bin:$PATH"
            msg_ok "Zig successfully installed: $(/opt/zig/zig version 2>/dev/null || echo 'installed')"
        else
            msg_err "Failed to locate extracted zig binary."
            rm -rf "$tmp_dir"
            return 1
        fi
    else
        msg_err "Failed to download Zig from $zig_url"
        rm -rf "$tmp_dir"
        return 1
    fi

    rm -rf "$tmp_dir"
    return 0
}

ensure_zig() {
    local need_install=0
    if command -v zig >/dev/null 2>&1; then
        local current_version
        current_version=$(zig version 2>/dev/null || echo "0.0.0")
        msg_info "Found existing Zig version: $current_version at $(command -v zig)"
        local major minor
        major=$(echo "$current_version" | cut -d. -f1)
        minor=$(echo "$current_version" | cut -d. -f2)
        if [[ "$major" -eq 0 && "$minor" -lt 16 ]]; then
            msg_warn "Installed Zig version ($current_version) is older than required 0.16.0."
            need_install=1
        fi
    else
        need_install=1
    fi

    if [[ $need_install -eq 1 ]]; then
        install_zig
    fi
}

pkg_install_build_deps() {
    local target="$1"
    local deps=()
    case "$target" in
        ly)
            deps=("${BUILD_DEPS_LY[@]}")
            ensure_zig
            ;;
        mangobar)
            deps=("${BUILD_DEPS_MANGOBAR[@]}")
            ;;
        *)
            deps=()
            ;;
    esac

    local missing=()
    for d in "${deps[@]}"; do
        if ! pkg_is_installed "$d"; then
            missing+=("$d")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        msg_info "Installing missing build dependencies for $target: ${missing[*]}..."
        pkg_install "${missing[@]}"
    else
        msg_ok "Build dependencies for $target are satisfied."
    fi
}

service_is_enabled() {
    local svc="$1"
    case "$INIT_SYSTEM" in
        runit)
            [[ -e "/var/service/$svc" || -L "/var/service/$svc" ]]
            ;;
        systemd)
            systemctl is-enabled "$svc" >/dev/null 2>&1
            ;;
        *)
            false
            ;;
    esac
}

service_enable() {
    local svc="$1"
    case "$INIT_SYSTEM" in
        runit)
            if [[ -d "/etc/sv/$svc" ]]; then
                sudo ln -sf "/etc/sv/$svc" "/var/service/"
            else
                msg_warn "Service definition '/etc/sv/$svc' not found."
                return 1
            fi
            ;;
        systemd)
            sudo systemctl enable "$svc" 2>/dev/null || true
            sudo systemctl start "$svc" 2>/dev/null || true
            ;;
        *)
            msg_warn "Cannot enable service '$svc': unknown init system '$INIT_SYSTEM'."
            return 1
            ;;
    esac
}

service_disable() {
    local svc="$1"
    case "$INIT_SYSTEM" in
        runit)
            if [[ -e "/var/service/$svc" || -L "/var/service/$svc" ]]; then
                sudo rm -f "/var/service/$svc"
            fi
            ;;
        systemd)
            if systemctl is-enabled "$svc" >/dev/null 2>&1 || systemctl is-active "$svc" >/dev/null 2>&1; then
                sudo systemctl disable --now "$svc" 2>/dev/null || true
            fi
            ;;
        *)
            ;;
    esac
}

service_status() {
    local svc="$1"
    case "$INIT_SYSTEM" in
        runit)
            sudo sv status "$svc" 2>/dev/null || true
            ;;
        systemd)
            systemctl status "$svc" --no-pager 2>/dev/null || true
            ;;
        *)
            ;;
    esac
}

setup_poweroff_permissions() {
    msg_info "Configuring power management permissions for 'poweroff' group..."

    if command -v sudo >/dev/null 2>&1 && [[ -d /etc/sudoers.d ]]; then
        local sudoers_power="/etc/sudoers.d/99-poweroff"
        local sudoers_content="%poweroff ALL=(ALL) NOPASSWD: /usr/sbin/poweroff, /usr/sbin/reboot, /usr/sbin/shutdown, /usr/sbin/halt, /usr/bin/poweroff, /usr/bin/reboot, /usr/bin/shutdown, /usr/bin/halt"

        if [[ ! -f "$sudoers_power" ]] || ! grep -q "NOPASSWD" "$sudoers_power" 2>/dev/null; then
            msg_info "Configuring sudoers permissions in $sudoers_power..."
            echo "$sudoers_content" | sudo tee "$sudoers_power" >/dev/null
            sudo chmod 0440 "$sudoers_power"
            msg_ok "Created $sudoers_power."
        else
            msg_ok "Power management sudoers rule already present in $sudoers_power."
        fi
    fi

    if command -v sudo >/dev/null 2>&1; then
        local polkit_dir="/etc/polkit-1/rules.d"
        sudo mkdir -p "$polkit_dir" 2>/dev/null || true
        local polkit_rule="$polkit_dir/50-poweroff.rules"
        if [[ ! -f "$polkit_rule" ]]; then
            cat <<'EOF' | sudo tee "$polkit_rule" >/dev/null
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.login1.power-off" ||
         action.id == "org.freedesktop.login1.power-off-multiple-sessions" ||
         action.id == "org.freedesktop.login1.power-off-ignore-inhibit" ||
         action.id == "org.freedesktop.login1.reboot" ||
         action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
         action.id == "org.freedesktop.login1.reboot-ignore-inhibit" ||
         action.id == "org.freedesktop.login1.suspend" ||
         action.id == "org.freedesktop.login1.hibernate") &&
        subject.isInGroup("poweroff")) {
        return polkit.Result.YES;
    }
});
EOF
            sudo chmod 0644 "$polkit_rule"
            msg_ok "Configured polkit power management rule in $polkit_rule."
        fi
    fi
}

setup_recorder_permissions() {
    if command -v gpu-screen-recorder >/dev/null 2>&1; then
        for gsr_server in "/usr/bin/gsr-kms-server" "/usr/sbin/gsr-kms-server"; do
            if [[ -f "$gsr_server" ]] && command -v setcap >/dev/null 2>&1; then
                sudo setcap cap_sys_admin+ep "$gsr_server" 2>/dev/null || true
            fi
        done
    fi
}

setup_user_groups() {
    msg_info "Configuring user hardware and power group memberships..."
    local current_user="${USER:-$(id -un)}"

    if command -v sudo >/dev/null 2>&1 && ! getent group poweroff >/dev/null 2>&1; then
        sudo groupadd -r poweroff 2>/dev/null || sudo groupadd poweroff 2>/dev/null || true
    fi

    for grp in "${HARDWARE_GROUPS[@]}"; do
        if getent group "$grp" >/dev/null 2>&1; then
            if id -nG "$current_user" 2>/dev/null | grep -qw "$grp"; then
                msg_ok "User '$current_user' is already in group '$grp'."
            else
                msg_info "Adding user '$current_user' to group '$grp'..."
                if sudo usermod -aG "$grp" "$current_user" 2>/dev/null; then
                    msg_ok "Added '$current_user' to group '$grp'."
                fi
            fi
        fi
    done

    setup_poweroff_permissions
    setup_recorder_permissions
}

services_setup() {
    msg_info "Configuring essential services for $DISTRO_NAME ($INIT_SYSTEM)..."

    case "$INIT_SYSTEM" in
        runit)
            if [[ ! -d /var/service ]]; then
                msg_err "/var/service not found. Ensure this is a runit-based system."
                return 1
            fi

            if [[ -d "/etc/sv/NetworkManager" || -e "/var/service/NetworkManager" ]]; then
                for conflict_sv in "dhcpcd" "wpa_supplicant"; do
                    if [[ -e "/var/service/$conflict_sv" || -L "/var/service/$conflict_sv" ]]; then
                        msg_info "Disabling conflicting service '$conflict_sv' (NetworkManager active)..."
                        service_disable "$conflict_sv"
                        msg_ok "Disabled conflicting service '$conflict_sv'."
                    fi
                done
            fi

            for sv in "${ESSENTIAL_SERVICES[@]}"; do
                if service_is_enabled "$sv"; then
                    msg_ok "Service '$sv' is already enabled in /var/service/."
                elif [[ -d "/etc/sv/$sv" ]]; then
                    msg_info "Enabling service '$sv' in /var/service/..."
                    if service_enable "$sv"; then
                        msg_ok "Service '$sv' successfully enabled."
                    else
                        msg_warn "Failed to enable service '$sv'."
                    fi
                else
                    msg_warn "Service definition for '$sv' not found in /etc/sv/."
                fi
            done
            ;;

        systemd)
            for sv in "${ESSENTIAL_SERVICES[@]}"; do
                if service_is_enabled "$sv"; then
                    msg_ok "Service '$sv' is already enabled."
                else
                    msg_info "Enabling and starting service '$sv'..."
                    if service_enable "$sv"; then
                        msg_ok "Service '$sv' enabled successfully."
                    else
                        msg_warn "Could not enable service '$sv'."
                    fi
                fi
            done
            ;;

        *)
            msg_warn "Skipping service management: init system '$INIT_SYSTEM' is not directly supervised."
            ;;
    esac

    echo ""
    setup_user_groups
}

dm_disable_competing() {
    local auto_yes="${1:-0}"
    local active_competing=()

    for dm in "${COMPETING_DMS[@]}"; do
        if service_is_enabled "$dm"; then
            active_competing+=("$dm")
        fi
    done

    if [[ ${#active_competing[@]} -gt 0 ]]; then
        msg_warn "Competing display manager(s) detected: ${active_competing[*]}"
        local disable_choice="y"
        if [[ $auto_yes -ne 1 && -t 0 ]]; then
            read -rp "Disable competing display manager(s) to allow Ly to run? [y/N]: " disable_choice
        fi
        if [[ "$disable_choice" =~ ^[Yy]$ ]]; then
            for dm in "${active_competing[@]}"; do
                service_disable "$dm"
                msg_ok "Disabled $dm."
            done
        else
            msg_warn "Ly service enablement skipped to avoid display manager conflict."
            return 1
        fi
    fi
    return 0
}

dm_enable_ly() {
    case "$INIT_SYSTEM" in
        runit)
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

            if [[ -e /var/service/agetty-tty2 || -L /var/service/agetty-tty2 ]]; then
                msg_info "Disabling agetty-tty2 in /var/service/ to prevent TTY collision with Ly..."
                sudo rm -f /var/service/agetty-tty2
                msg_ok "Disabled conflicting /var/service/agetty-tty2."
            fi

            local target_sv=""
            if [[ -d /etc/sv/ly ]]; then
                target_sv="ly"
            elif [[ -d /etc/sv/ly-runit-service ]]; then
                target_sv="ly-runit-service"
            fi

            if [[ -n "$target_sv" ]]; then
                if ! service_is_enabled "$target_sv"; then
                    msg_info "Enabling Ly runit service in /var/service/..."
                    sudo ln -s "/etc/sv/$target_sv" /var/service/
                    msg_ok "Ly runit service enabled (/var/service/$target_sv)."
                else
                    msg_ok "Ly service is already enabled in /var/service/."
                fi
            else
                msg_warn "Service definition for Ly not found in /etc/sv/."
            fi
            ;;

        systemd)
            if [[ ! -f /etc/systemd/system/ly.service && ! -f /usr/lib/systemd/system/ly.service && ! -f /lib/systemd/system/ly.service ]]; then
                sudo mkdir -p /etc/systemd/system
                cat <<'EOF' | sudo tee /etc/systemd/system/ly.service >/dev/null
[Unit]
Description=TUI display manager
After=systemd-user-sessions.service plymouth-quit-wait.service
After=getty@tty2.service
Conflicts=getty@tty2.service

[Service]
Type=idle
ExecStart=/usr/local/bin/ly
StandardInput=tty
StandardOutput=tty
TTYPath=/dev/tty2
TTYReset=yes
TTYVHangup=yes

[Install]
Alias=display-manager.service
EOF
                sudo systemctl daemon-reload
            fi

            if ! service_is_enabled ly; then
                msg_info "Enabling Ly systemd service..."
                if sudo systemctl enable ly; then
                    msg_ok "Ly service enabled via systemd."
                else
                    msg_warn "Failed to enable ly.service."
                fi
            else
                msg_ok "Ly systemd service is already enabled."
            fi
            ;;

        *)
            msg_warn "Unsupported init system '$INIT_SYSTEM' for automatic Ly enablement."
            ;;
    esac
}

detect_platform
init_distro_vars

if [[ "${BASH_SOURCE[0]}" != "${0}" ]] || [[ "${1:-}" == "--source-only" ]]; then
    return 0 2>/dev/null || exit 0
fi

LOGIN_MANAGER=""
AUTO_YES=0
SETUP_MIRROR=0
ENABLE_EXTRA_REPOS=1
BUILD_LY=0
BUILD_MANGOBAR=0
FIX_AUDIO=0
FIX_DBUS=0
FIX_BLUETOOTH=0
FIX_VIDEO=0
INSTALL_ZIG=0

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
        --install-zig)
            INSTALL_ZIG=1
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
        --fix-video)
            FIX_VIDEO=1
            shift 1
            ;;
        -h|--help)
            echo "Usage: ./install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -y, --yes                   Non-interactive mode, automatically answer yes to prompts"
            echo "  --login-manager <ly|none>   Configure preferred login manager (optional)"
            echo "  --mirror                    Configure/select repository mirror (xmirror / reflector)"
            echo "  --no-extra-repos            Skip enabling nonfree and multilib Void repositories"
            echo "  --build-ly                  Build Ly from source (https://github.com/fairyglade/ly)"
            echo "  --build-mangobar            Build/rebuild MangoBar from source (https://github.com/mangowm/mangobar)"
            echo "  --install-zig               Install/update Zig compiler from official binary release"
            echo "  --fix-audio                 Diagnose and repair PipeWire/WirePlumber audio subsystem"
            echo "  --fix-dbus                  Diagnose and repair DBus system and session services"
            echo "  --fix-bluetooth             Diagnose and repair BlueZ Bluetooth daemon and rfkill"
            echo "  --fix-video                 Diagnose and repair webcam / V4L2 / UVC video subsystem"
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

if [[ $INSTALL_ZIG -eq 1 ]]; then
    install_zig
    exit 0
fi

if [[ $FIX_DBUS -eq 1 || $FIX_AUDIO -eq 1 || $FIX_BLUETOOTH -eq 1 || $FIX_VIDEO -eq 1 ]]; then
    [[ $FIX_DBUS -eq 1 ]] && "$REPO_DIR/system/scripts/fix-dbus"
    [[ $FIX_AUDIO -eq 1 ]] && "$REPO_DIR/system/scripts/fix-audio"
    [[ $FIX_BLUETOOTH -eq 1 ]] && "$REPO_DIR/system/scripts/fix-bluetooth"
    [[ $FIX_VIDEO -eq 1 ]] && "$REPO_DIR/system/scripts/fix-video"
    exit 0
fi

echo -e "${BOLD}========================================================${RESET}"
echo -e "${BOLD}      Void Linux × MangoWC Minimal Desktop Installer    ${RESET}"
echo -e "${BOLD}========================================================${RESET}"
echo ""

msg_info "Platform: $DISTRO_NAME ($DISTRO_ID) | Init: $INIT_SYSTEM | Package Manager: $PKG_MANAGER"

if [[ "$DISTRO_ID" == "unknown" ]]; then
    msg_warn "Unrecognized distribution. The installer will proceed with config linking."
    if [[ $AUTO_YES -eq 0 && -t 0 ]]; then
        read -rp "Proceed with configuration linking only? [y/N]: " choice
        [[ ! "$choice" =~ ^[Yy]$ ]] && exit 1
    fi
fi

pkg_setup_repos "$ENABLE_EXTRA_REPOS" "$AUTO_YES"

if [[ $SETUP_MIRROR -eq 1 ]]; then
    pkg_setup_mirror
fi

pkg_sync

if [[ -n "$PKG_MANIFEST" && -f "$PKG_MANIFEST" ]]; then
    msg_info "Checking required packages from $(basename "$PKG_MANIFEST")..."
    missing_packages=()
    while IFS= read -r raw_line; do
        pkg=$(echo "$raw_line" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [[ -z "$pkg" ]] && continue

        if [[ "$pkg" == "mangowc" ]]; then
            if command -v mango >/dev/null 2>&1 || command -v mangowc >/dev/null 2>&1; then
                msg_ok "MangoWC binary is already available."
                continue
            fi
        fi

        if [[ "$pkg" == "mangobar" ]]; then
            if command -v mangobar >/dev/null 2>&1; then
                msg_ok "MangoBar binary is already available."
                continue
            fi
        fi

        if pkg_is_installed "$pkg"; then
            continue
        fi

        resolved_pkg=$(pkg_resolve_name "$pkg")
        if pkg_is_installed "$resolved_pkg"; then
            continue
        fi

        missing_packages+=("$resolved_pkg")
    done < "$PKG_MANIFEST"

    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        msg_info "The following ${#missing_packages[@]} package(s) need installation:"
        echo "  ${missing_packages[*]}"
        echo ""
        do_install="y"
        if [[ $AUTO_YES -ne 1 && -t 0 ]]; then
            read -rp "Install missing packages? [Y/n]: " do_install
        fi
        if [[ ! "$do_install" =~ ^[Nn]$ ]]; then
            msg_info "Installing packages..."
            if ! pkg_install "${missing_packages[@]}"; then
                msg_warn "Bulk installation failed. Retrying packages individually..."
                for p in "${missing_packages[@]}"; do
                    if ! pkg_is_installed "$p"; then
                        pkg_install "$p" || msg_warn "Package '$p' could not be installed."
                    fi
                done
            fi
            msg_ok "Package installation step completed."
        else
            msg_warn "Skipped package installation."
        fi
    else
        msg_ok "All manifest packages are already installed."
    fi
fi

msg_info "Checking MangoBar status bar..."
do_build_mangobar=0
if [[ $BUILD_MANGOBAR -eq 1 ]]; then
    do_build_mangobar=1
elif ! command -v mangobar >/dev/null 2>&1; then
    msg_info "MangoBar binary not found on system."
    if [[ $AUTO_YES -eq 1 || ! -t 0 ]]; then
        do_build_mangobar=1
    else
        read -rp "Build and install MangoBar from source (https://github.com/mangowm/mangobar)? [Y/n]: " mb_choice
        if [[ ! "$mb_choice" =~ ^[Nn]$ ]]; then
            do_build_mangobar=1
        fi
    fi
else
    msg_ok "MangoBar binary found at $(command -v mangobar)."
fi

if [[ $do_build_mangobar -eq 1 ]]; then
    msg_info "Building MangoBar from source..."
    pkg_install_build_deps mangobar

    BUILD_TMP=$(mktemp -d /tmp/mangobar-build-XXXXXX)
    clone_ok=0
    if git clone --depth 1 https://github.com/mangowm/mangobar.git "$BUILD_TMP" 2>/dev/null; then
        clone_ok=1
    elif [[ -d "$HOME/mangobar" && -f "$HOME/mangobar/meson.build" ]]; then
        cp -r "$HOME/mangobar"/* "$BUILD_TMP"/ 2>/dev/null || true
        clone_ok=1
    fi

    if [[ $clone_ok -eq 1 ]]; then
        pushd "$BUILD_TMP" >/dev/null
        if meson setup build -Dprefix=/usr && ninja -C build -j"$(nproc 2>/dev/null || echo 2)" && sudo ninja -C build install; then
            msg_ok "MangoBar built and installed successfully."
        else
            msg_err "MangoBar build/install encountered errors."
        fi
        popd >/dev/null
    fi
    rm -rf "$BUILD_TMP"
fi

services_setup

msg_info "Setting up configuration symlinks..."
mkdir -p "$HOME/.config"

CONFIG_TARGETS=(
    "config/mango:mango"
    "config/mangobar:mangobar"
    "config/rofi:rofi"
    "config/foot:foot"
    "config/alacritty:alacritty"
    "config/mako:mako"
    "config/fontconfig:fontconfig"
    "config/thunar:Thunar"
    "config/gtk-3.0:gtk-3.0"
    "config/btop:btop"
    "config/themes:themes"
    "config/wallpaper:wallpaper"
)

backup_needed=0
for target in "${CONFIG_TARGETS[@]}"; do
    src_rel="${target%%:*}"
    dst_name="${target##*:}"
    src_path="$REPO_DIR/$src_rel"
    dst_path="$HOME/.config/$dst_name"

    [[ ! -d "$src_path" && ! -f "$src_path" ]] && continue

    if [[ -e "$dst_path" || -L "$dst_path" ]]; then
        if [[ -L "$dst_path" && "$(readlink -f "$dst_path" 2>/dev/null || true)" == "$(readlink -f "$src_path" 2>/dev/null || true)" ]]; then
            msg_ok "Symlink '$dst_path' is already active."
            continue
        fi

        if diff -rq "$dst_path" "$src_path" >/dev/null 2>&1; then
            rm -rf "$dst_path"
            ln -s "$src_path" "$dst_path"
            msg_ok "Config '$dst_path' matches repository; converted to symlink."
            continue
        fi

        if [[ $backup_needed -eq 0 ]]; then
            mkdir -p "$BACKUP_DIR"
            msg_info "Backing up existing configurations to '$BACKUP_DIR'..."
            backup_needed=1
        fi
        mv "$dst_path" "$BACKUP_DIR/$dst_name"
        msg_ok "Backed up '$dst_path' -> '$BACKUP_DIR/$dst_name'."
    fi

    ln -s "$src_path" "$dst_path"
    msg_ok "Linked '$dst_path' -> '$src_path'."
done

mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/wm"
mkdir -p "$HOME/.cache/wm"

if [[ ! -L "$HOME/.config/wm" || "$(readlink -f "$HOME/.config/wm" 2>/dev/null || true)" != "$(readlink -f "$REPO_DIR" 2>/dev/null || true)" ]]; then
    ln -sfn "$REPO_DIR" "$HOME/.config/wm"
fi

mkdir -p "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
if [[ -f "$REPO_DIR/config/thunar/thunar.xml" ]]; then
    if [[ ! -f "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml" ]] || ! cmp -s "$REPO_DIR/config/thunar/thunar.xml" "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml"; then
        cp "$REPO_DIR/config/thunar/thunar.xml" "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml"
        msg_ok "Configured Thunar preferences."
    fi
fi

mkdir -p "$HOME/.config/gtk-4.0"
if [[ -f "$REPO_DIR/config/gtk-3.0/gtk.css" ]]; then
    ln -sf "$REPO_DIR/config/gtk-3.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
    ln -sf "$REPO_DIR/config/gtk-3.0/theme.css" "$HOME/.config/gtk-4.0/theme.css"
    ln -sf "$REPO_DIR/config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
    msg_ok "Configured GTK 4.0 dark theme symlinks."
fi

if [[ -d "$REPO_DIR/assets/papirus" ]]; then
    mkdir -p "$HOME/.local/share/icons" "$HOME/.icons"
    ln -sfn "$REPO_DIR/assets/papirus" "$HOME/.local/share/icons/Papirus-Custom"
    ln -sfn "$REPO_DIR/assets/papirus" "$HOME/.icons/Papirus-Custom"
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -q -f -t "$REPO_DIR/assets/papirus" 2>/dev/null || true
    fi
    msg_ok "Configured Papirus-Custom icon theme symlinks."
fi

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Custom' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface font-name 'Maple Mono 10' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null || true
fi

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
    if [[ $fonts_updated -eq 1 ]] && command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$FONT_DIR"
        msg_ok "Icon fonts installed and font cache updated."
    fi
fi

msg_info "Setting script execution permissions..."
chmod +x "$REPO_DIR"/config/mangobar/scripts/* \
         "$REPO_DIR"/config/rofi/*/* \
         "$REPO_DIR"/config/wallpaper/* \
         "$REPO_DIR"/config/themes/theme-* \
         "$REPO_DIR"/system/scripts/* \
         "$REPO_DIR"/system/services/*.sh \
         "$REPO_DIR"/install.sh 2>/dev/null || true

desktop_scripts=(
    "$REPO_DIR/config/mangobar/scripts/battery-status"
    "$REPO_DIR/config/mangobar/scripts/brightness"
    "$REPO_DIR/config/mangobar/scripts/media"
    "$REPO_DIR/config/mangobar/scripts/get_window"
    "$REPO_DIR/config/mangobar/scripts/keyviz"
    "$REPO_DIR/config/mangobar/scripts/launch-audio"
    "$REPO_DIR/config/mangobar/scripts/launch-bluetooth"
    "$REPO_DIR/config/mangobar/scripts/launch-btop"
    "$REPO_DIR/config/mangobar/scripts/launch-wifi"
    "$REPO_DIR/config/mangobar/scripts/listener.py"
    "$REPO_DIR/config/mangobar/scripts/recorder"
    "$REPO_DIR/config/mangobar/scripts/rofi-battery"
    "$REPO_DIR/config/mangobar/scripts/volume"
    "$REPO_DIR/config/rofi/launcher/rofi-launcher"
    "$REPO_DIR/config/rofi/launcher/rofi-run"
    "$REPO_DIR/config/rofi/calendar/rofi-calander"
    "$REPO_DIR/config/rofi/clipboard/clipboard-menu"
    "$REPO_DIR/config/rofi/powermenu/rofi-powermenu"
    "$REPO_DIR/config/rofi/network/rofi-wifi"
    "$REPO_DIR/config/rofi/network/rofi-bluetooth"
    "$REPO_DIR/config/rofi/audio/rofi-audio"
    "$REPO_DIR/config/rofi/screenshot/rofi-screenshot"
    "$REPO_DIR/config/rofi/wallpaper/rofi-wallpaper"
    "$REPO_DIR/config/rofi/theme-selector/theme-select"
    "$REPO_DIR/config/rofi/keymaps/rofi-keymaps"
    "$REPO_DIR/config/wallpaper/wallpaper-manager"
    "$REPO_DIR/config/wallpaper/wallpaper-random"
    "$REPO_DIR/config/wallpaper/wallpaper-switch"
    "$REPO_DIR/config/wallpaper/wallpaper-select"
    "$REPO_DIR/config/themes/theme-engine.py"
    "$REPO_DIR/config/themes/theme-switch"
    "$REPO_DIR/config/themes/theme-from-wallpaper"
    "$REPO_DIR/system/scripts/start-mango"
    "$REPO_DIR/system/scripts/reload"
    "$REPO_DIR/system/scripts/backup"
    "$REPO_DIR/system/scripts/restore"
    "$REPO_DIR/system/scripts/audio-check"
    "$REPO_DIR/system/scripts/fix-audio"
    "$REPO_DIR/system/scripts/fix-bluetooth"
    "$REPO_DIR/system/scripts/fix-dbus"
    "$REPO_DIR/system/scripts/fix-video"
    "$REPO_DIR/system/scripts/wm-doctor"
    "$REPO_DIR/system/services/pipewire-launcher.sh"
)

mkdir -p "$HOME/.local/bin"
for script in "${desktop_scripts[@]}"; do
    if [[ -f "$script" && -x "$script" ]]; then
        script_name="$(basename "$script")"
        ln -sf "$script" "$HOME/.local/bin/$script_name"
    fi
done

ln -sf "$REPO_DIR/config/rofi/clipboard/clipboard-menu" "$HOME/.local/bin/rofi-clipboard"
ln -sf "$REPO_DIR/config/rofi/theme-selector/theme-select" "$HOME/.local/bin/rofi-theme"
ln -sf "$REPO_DIR/config/rofi/theme-selector/theme-select" "$HOME/.local/bin/rofi-theme-selector"

if command -v mango >/dev/null 2>&1 && ! command -v mangowc >/dev/null 2>&1; then
    ln -sf "$(command -v mango)" "$HOME/.local/bin/mangowc"
fi

if command -v sudo >/dev/null 2>&1; then
    sudo mkdir -p /usr/local/bin
    for script in "${desktop_scripts[@]}"; do
        if [[ -f "$script" && -x "$script" ]]; then
            script_name="$(basename "$script")"
            sudo ln -sf "$script" "/usr/local/bin/$script_name" 2>/dev/null || true
        fi
    done
    sudo ln -sf "$REPO_DIR/config/rofi/clipboard/clipboard-menu" "/usr/local/bin/rofi-clipboard" 2>/dev/null || true
    sudo ln -sf "$REPO_DIR/config/rofi/theme-selector/theme-select" "/usr/local/bin/rofi-theme" 2>/dev/null || true
    sudo ln -sf "$REPO_DIR/config/rofi/theme-selector/theme-select" "/usr/local/bin/rofi-theme-selector" 2>/dev/null || true
    if command -v mango >/dev/null 2>&1 && ! command -v mangowc >/dev/null 2>&1; then
        sudo ln -sf "$(command -v mango)" /usr/local/bin/mangowc 2>/dev/null || true
    fi
fi
msg_ok "Desktop scripts linked into ~/.local/bin and /usr/local/bin."

msg_info "Configuring Wayland session entry for MangoWC..."
mkdir -p "$HOME/.local/share/wayland-sessions"
cp "$REPO_DIR/system/services/mango.desktop" "$HOME/.local/share/wayland-sessions/mango.desktop"

if command -v sudo >/dev/null 2>&1 && [[ -f "$REPO_DIR/system/services/mango.desktop" ]]; then
    sudo mkdir -p /usr/share/wayland-sessions
    sudo cp "$REPO_DIR/system/services/mango.desktop" /usr/share/wayland-sessions/mango.desktop
    msg_ok "Wayland session entry installed (/usr/share/wayland-sessions/mango.desktop)."
fi

if [[ -x "$REPO_DIR/config/themes/theme-engine.py" ]]; then
    if [[ ! -f "$REPO_DIR/config/themes/generated/palette.css" ]]; then
        msg_info "Initializing default theme palette (catppuccin-mocha)..."
        python3 "$REPO_DIR/config/themes/theme-engine.py" catppuccin-mocha --no-wallpaper >/dev/null 2>&1 || true
        msg_ok "Theme palette initialized."
    else
        msg_ok "Theme palette already active."
    fi
fi

if [[ -z "$LOGIN_MANAGER" ]]; then
    ly_is_installed=0
    [[ -x "$(command -v ly 2>/dev/null || true)" ]] && ly_is_installed=1

    ly_is_enabled=0
    if [[ -e /var/service/ly || -L /var/service/ly || -e /var/service/ly-runit-service || -L /var/service/ly-runit-service ]]; then
        ly_is_enabled=1
    elif command -v systemctl >/dev/null 2>&1 && systemctl is-enabled ly >/dev/null 2>&1; then
        ly_is_enabled=1
    fi

    if [[ $ly_is_installed -eq 1 && $ly_is_enabled -eq 1 ]]; then
        msg_ok "Ly login manager is already installed and enabled."
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
    msg_info "Configuring Ly login manager..."
    ly_ready=0

    if command -v ly >/dev/null 2>&1 && [[ $BUILD_LY -eq 0 ]]; then
        ly_ready=1
    else
        msg_info "Building Ly from source..."
        pkg_install_build_deps ly

        BUILD_TMP=$(mktemp -d /tmp/ly-build-XXXXXX)

        if git clone --recurse-submodules --depth 1 \
            https://github.com/fairyglade/ly.git "$BUILD_TMP"; then

            pushd "$BUILD_TMP" >/dev/null || exit 1

            if command -v zig >/dev/null 2>&1; then
                local_init="runit"
                [[ "$INIT_SYSTEM" == "systemd" ]] && local_init="systemd"

                if zig build -Doptimize=ReleaseSmall &&
                    sudo zig build installexe \
                        -Dinit_system="$local_init" \
                        -Doptimize=ReleaseSmall &&
                    command -v ly >/dev/null 2>&1; then
                    ly_ready=1
                    msg_ok "Ly successfully built and installed."
                else
                    msg_error "Ly build or installation failed."
                fi
            else
                msg_error "Zig is not installed."
            fi

            popd >/dev/null
        else
            msg_error "Failed to clone Ly repository."
        fi

        rm -rf "$BUILD_TMP"
    fi

    if [[ $ly_ready -eq 1 ]]; then
        if [[ ! -f /etc/pam.d/ly && -f /etc/pam.d/login ]]; then
            sudo mkdir -p /etc/pam.d
            sudo cp /etc/pam.d/login /etc/pam.d/ly
        fi

        dm_disable_competing "$AUTO_YES"
        dm_enable_ly
    else
        msg_warn "Ly is unavailable. Skipping login manager configuration."
    fi
fi

echo ""
msg_info "Running wm-doctor system diagnosis..."
echo ""
bash "$REPO_DIR/system/scripts/wm-doctor" || true

echo ""
echo -e "${BOLD}========================================================${RESET}"
echo -e "${BOLD}                Installation Complete!                  ${RESET}"
echo -e "${BOLD}========================================================${RESET}"
echo ""
if [[ $backup_needed -eq 1 ]]; then
    echo "Previous configurations were backed up to: $BACKUP_DIR"
    echo ""
fi
echo "To start the desktop session manually from any TTY:"
echo -e "  ${BOLD}start-mango${RESET}  or  ${BOLD}$REPO_DIR/system/scripts/start-mango${RESET}"
echo ""
