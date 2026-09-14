#!/usr/bin/env bash
# ==============================================================================
# pipewire-launcher.sh: Session Daemon Supervisor for PipeWire & WirePlumber
# Designed for Void Linux runit systems as a user session daemon supervisor.
# Starts PipeWire, WirePlumber, and PipeWire-Pulse safely without duplicates.
# ==============================================================================
set -euo pipefail

# 1. PipeWire Core Daemon
if ! pgrep -x pipewire >/dev/null 2>&1; then
    pipewire &
    sleep 0.2
fi

# 2. WirePlumber Session Manager
if ! pgrep -x wireplumber >/dev/null 2>&1; then
    wireplumber &
    sleep 0.2
fi

# 3. PulseAudio Compatibility Daemon
if ! pgrep -x pipewire-pulse >/dev/null 2>&1; then
    pipewire-pulse &
fi
