#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR"

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
        # shellcheck disable=SC1091
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

    # Init System Detection
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

    # Package Manager Detection
    case "$DISTRO_ID" in
        void)
            PKG_MANAGER="xbps"
            ;;
        arch)
            PKG_MANAGER="pacman"
            ;;
        debian)
            PKG_MANAGER="apt"
            ;;
        *)
            if command -v xbps-install >/dev/null 2>&1; then
                PKG_MANAGER="xbps"
            elif command -v pacman >/dev/null 2>&1; then
                PKG_MANAGER="pacman"
            elif command -v apt-get >/dev/null 2>&1; then
                PKG_MANAGER="apt"
            else
                PKG_MANAGER="unknown"
            fi
            ;;
    esac

    # Manifest Selection
    case "$DISTRO_ID" in
        void)
            PKG_MANIFEST="$REPO_DIR/packages.void"
            ;;
        arch)
            PKG_MANIFEST="$REPO_DIR/packages.arch"
            ;;
        debian)
            PKG_MANIFEST="$REPO_DIR/packages.debian"
            ;;
        *)
            PKG_MANIFEST=""
            ;;
    esac
}

init_distro_vars() {
    case "$DISTRO_ID" in
        void)
            BUILD_DEPS_LY=(pam-devel libxcb-devel git make)
            BUILD_DEPS_MANGOBAR=(meson ninja pkg-config wayland-devel wayland-protocols fcft-devel pixman-devel cairo-devel pango-devel pulseaudio-devel eudev-libudev-devel gdk-pixbuf-devel cJSON-devel basu-devel git)
            ESSENTIAL_SERVICES=(dbus elogind NetworkManager bluetoothd polkitd)
            HARDWARE_GROUPS=(video audio input network bluetooth poweroff)
            COMPETING_DMS=(sddm lightdm gdm lxdm greetd)
            ;;
        arch)
            BUILD_DEPS_LY=(pam libxcb git make)
            BUILD_DEPS_MANGOBAR=(meson ninja pkgconf wayland wayland-protocols fcft pixman cairo pango libpulse systemd gdk-pixbuf2 cjson git)
            ESSENTIAL_SERVICES=(dbus NetworkManager bluetooth)
            HARDWARE_GROUPS=(video audio input network bluetooth poweroff)
            COMPETING_DMS=(sddm lightdm gdm lxdm greetd)
            ;;
        debian)
            BUILD_DEPS_LY=(libpam0g-dev libxcb1-dev libxcb-xkb-dev git make)
            BUILD_DEPS_MANGOBAR=(meson ninja-build pkg-config libwayland-dev wayland-protocols libfcft-dev libpixman-1-dev libcairo2-dev libpango1.0-dev libpulse-dev libudev-dev libgdk-pixbuf-2.0-dev libcjson-dev libbasu-dev git)
            ESSENTIAL_SERVICES=(dbus NetworkManager bluetooth)
            HARDWARE_GROUPS=(video audio input netdev bluetooth poweroff)
            COMPETING_DMS=(sddm lightdm gdm lxdm greetd)
            ;;
        *)
            BUILD_DEPS_LY=(git make)
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

pkg_is_available() {
    local pkg="$1"
    case "$PKG_MANAGER" in
        xbps)
            xbps-query -R "$pkg" >/dev/null 2>&1
            ;;
        pacman)
            pacman -Si "$pkg" >/dev/null 2>&1
            ;;
        apt)
            apt-cache show "$pkg" >/dev/null 2>&1
            ;;
        *)
            false
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
                else
                    msg_info "Note: multilib repository is optional and not active in /etc/pacman.conf."
                fi
            fi
            ;;
        debian)
            msg_info "Checking Debian/Ubuntu package repositories..."
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
            else
                msg_info "Reflector not installed; mirrors can be configured in /etc/pacman.d/mirrorlist."
            fi
            ;;
        debian)
            msg_info "Debian/Ubuntu mirrors can be configured in /etc/apt/sources.list."
            ;;
        *)
            msg_warn "Mirror selection is not supported on this platform."
            ;;
    esac
}

pkg_install_build_deps() {
    local target="$1"
    local deps=()
    case "$target" in
        ly)
            deps=("${BUILD_DEPS_LY[@]}")
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

service_is_active() {
    local svc="$1"
    case "$INIT_SYSTEM" in
        runit)
            sudo sv status "$svc" 2>/dev/null | grep -q "^run:"
            ;;
        systemd)
            systemctl is-active "$svc" >/dev/null 2>&1
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

    # Sudoers rule: allow poweroff group to run shutdown/poweroff/reboot/halt without password
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

    # Polkit rule (for elogind / systemd-logind passwordless actions)
    if command -v sudo >/dev/null 2>&1; then
        local polkit_dir="/etc/polkit-1/rules.d"
        sudo mkdir -p "$polkit_dir" 2>/dev/null || true
        local polkit_rule="$polkit_dir/50-poweroff.rules"
        if [[ ! -f "$polkit_rule" ]]; then
            msg_info "Configuring polkit rules for 'poweroff' group in $polkit_rule..."
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

setup_user_groups() {
    msg_info "Configuring user hardware and power group memberships..."
    local current_user="${USER:-$(id -un)}"

    # Ensure poweroff group exists for passwordless shutdown/reboot
    if command -v sudo >/dev/null 2>&1 && ! getent group poweroff >/dev/null 2>&1; then
        msg_info "Creating 'poweroff' group..."
        if sudo groupadd -r poweroff 2>/dev/null || sudo groupadd poweroff 2>/dev/null; then
            msg_ok "Created 'poweroff' group."
        else
            msg_warn "Failed to create 'poweroff' group."
        fi
    fi

    for grp in "${HARDWARE_GROUPS[@]}"; do
        if getent group "$grp" >/dev/null 2>&1; then
            if id -nG "$current_user" 2>/dev/null | grep -qw "$grp"; then
                msg_ok "User '$current_user' is already in group '$grp'."
            else
                msg_info "Adding user '$current_user' to group '$grp' (requires sudo)..."
                if sudo usermod -aG "$grp" "$current_user"; then
                    msg_ok "Added '$current_user' to group '$grp'."
                else
                    msg_warn "Failed to add '$current_user' to group '$grp'."
                fi
            fi
        fi
    done

    setup_poweroff_permissions
}

services_setup() {
    msg_info "Configuring essential services for $DISTRO_NAME ($INIT_SYSTEM)..."

    case "$INIT_SYSTEM" in
        runit)
            if [[ ! -d /var/service ]]; then
                msg_err "/var/service not found. Ensure this is a runit-based system."
                return 1
            fi

            # Resolve network daemon conflicts (dhcpcd / wpa_supplicant vs NetworkManager)
            if [[ -d "/etc/sv/NetworkManager" || -e "/var/service/NetworkManager" ]]; then
                for conflict_sv in "dhcpcd" "wpa_supplicant"; do
                    if [[ -e "/var/service/$conflict_sv" || -L "/var/service/$conflict_sv" ]]; then
                        msg_info "Disabling conflicting service '$conflict_sv' (NetworkManager manages DHCP & Wi-Fi)..."
                        service_disable "$conflict_sv"
                        msg_ok "Disabled conflicting service '$conflict_sv'."
                    fi
                done
            fi

            local missing_count=0
            for sv in "${ESSENTIAL_SERVICES[@]}"; do
                if service_is_enabled "$sv"; then
                    msg_ok "Service '$sv' is already enabled in /var/service/."
                elif [[ -d "/etc/sv/$sv" ]]; then
                    msg_info "Enabling service '$sv' in /var/service/..."
                    if service_enable "$sv"; then
                        msg_ok "Service '$sv' successfully enabled."
                    else
                        msg_warn "Failed to enable service '$sv'."
                        missing_count=$((missing_count + 1))
                    fi
                else
                    msg_warn "Service definition for '$sv' not found in /etc/sv/."
                    missing_count=$((missing_count + 1))
                fi
            done

            echo ""
            msg_info "Verifying runit service supervisor status..."
            for sv in "${ESSENTIAL_SERVICES[@]}"; do
                if service_is_enabled "$sv"; then
                    local st
                    st=$(service_status "$sv")
                    [[ -n "$st" ]] && echo "  ✓ $st"
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

dm_is_ly_enabled() {
    case "$INIT_SYSTEM" in
        runit)
            [[ -e /var/service/ly || -L /var/service/ly || -e /var/service/ly-runit-service || -L /var/service/ly-runit-service ]]
            ;;
        systemd)
            systemctl is-enabled ly >/dev/null 2>&1
            ;;
        *)
            false
            ;;
    esac
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
        msg_warn "Only one display manager should be active at a time."
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
                msg_info "Installing default systemd service unit for Ly..."
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
                msg_ok "Created /etc/systemd/system/ly.service."
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

    ly_disable_session_log
}

ly_disable_session_log() {
    if [[ -f /etc/ly/config.ini ]] && command -v sudo >/dev/null 2>&1; then
        if grep -q "^session_log[[:space:]]*=" /etc/ly/config.ini; then
            sudo sed -i 's/^session_log[[:space:]]*=.*/session_log = null/' /etc/ly/config.ini
        else
            echo "session_log = null" | sudo tee -a /etc/ly/config.ini >/dev/null
        fi
        msg_ok "Configured 'session_log = null' in /etc/ly/config.ini."
    fi
    rm -f "$HOME/ly-session.log"
}

detect_platform
init_distro_vars

# If invoked directly, execute system/setup/install.sh with all arguments.
# If sourced, environment variables and functions remain exported in caller shell.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # shellcheck disable=SC1091
    source "$REPO_DIR/system/setup/install.sh" "$@"
fi
