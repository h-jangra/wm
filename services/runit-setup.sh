#!/usr/bin/env bash
# ==============================================================================
# runit-setup.sh: Enable required system runit services on Void Linux
# Validates service presence, links to /var/service/, and checks user groups.
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

missing_count=0

for sv in "dbus" "elogind" "NetworkManager" "bluetoothd" "polkitd"; do
    pkg="${SERVICE_PACKAGE_MAP[$sv]}"
    if [[ -d "/var/service/$sv" || -L "/var/service/$sv" ]]; then
        echo "  ✓ Service '$sv' is active in /var/service/."
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

echo ""
echo "==> Configuring user hardware group memberships..."
GROUPS=("video" "audio" "input" "network" "bluetooth")

for grp in "${GROUPS[@]}"; do
    if getent group "$grp" >/dev/null 2>&1; then
        if id -nG "$USER" | grep -qw "$grp"; then
            echo "  ✓ User '$USER' is already in group '$grp'."
        else
            echo "  -> Adding user '$USER' to group '$grp' (requires sudo)..."
            sudo usermod -aG "$grp" "$USER"
            echo "  ✓ Added '$USER' to group '$grp'."
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
