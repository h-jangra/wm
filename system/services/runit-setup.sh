#!/usr/bin/env bash
# ==============================================================================
# runit-setup.sh: Enable required system runit services on Void Linux
# Idempotent, validates service presence, disables conflicts, and configures groups.
# ==============================================================================
set -euo pipefail

echo "==> Configuring Void Linux runit services..."

declare -A SERVICE_PACKAGE_MAP=(
    ["dbus"]="dbus"
    ["elogind"]="elogind"
    ["NetworkManager"]="NetworkManager"
    ["bluetoothd"]="bluez"
    ["polkitd"]="polkit"
)

if [[ ! -d /var/service ]]; then
    echo "Error: /var/service not found. Ensure this is a Void Linux installation running runit." >&2
    exit 1
fi

# 1. Resolve network daemon conflicts
# When NetworkManager is active, dhcpcd and wpa_supplicant standalone services
# conflict and cause dropped connections or duplicate IP lease requests.
if [[ -d "/etc/sv/NetworkManager" || -e "/var/service/NetworkManager" ]]; then
    for conflict_sv in "dhcpcd" "wpa_supplicant"; do
        if [[ -e "/var/service/$conflict_sv" || -L "/var/service/$conflict_sv" ]]; then
            echo "  -> Disabling conflicting service '$conflict_sv' (NetworkManager manages DHCP & Wi-Fi)..."
            if sudo rm -f "/var/service/$conflict_sv"; then
                echo "  ✓ Successfully disabled conflicting service '$conflict_sv'."
            else
                echo "  ! Failed to remove /var/service/$conflict_sv (requires root privileges)." >&2
            fi
        fi
    done
fi

missing_count=0

# 2. Enable essential system services idempotently
for sv in "dbus" "elogind" "NetworkManager" "bluetoothd" "polkitd"; do
    pkg="${SERVICE_PACKAGE_MAP[$sv]}"
    if [[ -e "/var/service/$sv" || -L "/var/service/$sv" ]]; then
        echo "  ✓ Service '$sv' is already enabled in /var/service/."
    elif [[ -d "/etc/sv/$sv" ]]; then
        echo "  -> Enabling service '$sv' in /var/service/ (requires sudo)..."
        if sudo ln -s "/etc/sv/$sv" "/var/service/"; then
            echo "  ✓ Service '$sv' successfully enabled."
        else
            echo "  ✗ Failed to enable service '$sv'." >&2
            missing_count=$((missing_count + 1))
        fi
    else
        echo "  ✗ Service definition for '$sv' not found in /etc/sv/." >&2
        echo "    Remediation: Install the required package: sudo xbps-install -Sy $pkg" >&2
        missing_count=$((missing_count + 1))
    fi
done

# 3. Report active service supervisor status
echo ""
echo "==> Verifying runit service supervisor status..."
for sv in "dbus" "elogind" "NetworkManager" "bluetoothd" "polkitd"; do
    if [[ -e "/var/service/$sv" ]]; then
        status_line=$(sudo sv status "$sv" 2>/dev/null || true)
        if [[ -n "$status_line" ]]; then
            echo "  ✓ $status_line"
        fi
    fi
done

# 4. User hardware group memberships
echo ""
echo "==> Configuring user hardware group memberships..."
GROUPS=("video" "audio" "input" "network" "bluetooth")

current_user="${USER:-$(id -un)}"
for grp in "${GROUPS[@]}"; do
    if getent group "$grp" >/dev/null 2>&1; then
        if id -nG "$current_user" 2>/dev/null | grep -qw "$grp"; then
            echo "  ✓ User '$current_user' is already in group '$grp'."
        else
            echo "  -> Adding user '$current_user' to group '$grp' (requires sudo)..."
            sudo usermod -aG "$grp" "$current_user"
            echo "  ✓ Added '$current_user' to group '$grp'."
        fi
    else
        echo "  ! Group '$grp' does not exist on this system."
    fi
done

echo ""
if [[ $missing_count -eq 0 ]]; then
    echo "✓ All required runit services and group memberships are properly configured."
    exit 0
else
    echo "✗ $missing_count service(s) could not be enabled. Review missing packages above." >&2
    exit 1
fi
