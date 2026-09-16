#!/usr/bin/env bash
# ==============================================================================
# Void Linux × MangoWC Desktop Installer Entrypoint
# Delegates to system/setup/install.sh
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
exec "$SCRIPT_DIR/system/setup/install.sh" "$@"
