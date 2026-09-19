#!/usr/bin/env bash
# ==============================================================================
# runit-setup.sh: Enable required system runit services on Void Linux
# Idempotent, validates service presence, disables conflicts, and configures groups.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [[ -f "$REPO_DIR/install.sh" ]]; then
    # shellcheck disable=SC1091
    source "$REPO_DIR/install.sh"
    services_setup
else
    echo "Error: Cannot locate install.sh in $REPO_DIR" >&2
    exit 1
fi
