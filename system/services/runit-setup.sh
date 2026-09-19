#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [[ -f "$REPO_DIR/install.sh" ]]; then
    # shellcheck disable=SC1091
    source "$REPO_DIR/install.sh" --source-only
    services_setup
else
    echo "Error: Cannot locate install.sh in $REPO_DIR" >&2
    exit 1
fi
