#!/usr/bin/env bash
# ==============================================================================
# pipewire-launcher.sh: Session Daemon Supervisor for PipeWire & WirePlumber
# Designed for Void Linux runit systems as a user session daemon supervisor.
# Starts PipeWire, WirePlumber, and PipeWire-Pulse safely without duplicates.
# ==============================================================================
set -euo pipefail

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# If pipewire processes are lingering from a previous dead session, restart them cleanly
if pgrep -u "$USER" -x pipewire >/dev/null 2>&1; then
    if ! pactl info >/dev/null 2>&1; then
        pkill -u "$USER" -x pipewire-pulse 2>/dev/null || true
        pkill -u "$USER" -x wireplumber 2>/dev/null || true
        pkill -u "$USER" -x pipewire 2>/dev/null || true
        sleep 0.5
        rm -f "$RUNTIME_DIR"/pipewire* 2>/dev/null || true
    fi
fi

# 1. PipeWire Core Daemon
if ! pgrep -u "$USER" -x pipewire >/dev/null 2>&1; then
    pipewire &
    sleep 0.2
fi

# 2. WirePlumber Session Manager
if ! pgrep -u "$USER" -x wireplumber >/dev/null 2>&1; then
    wireplumber &
    sleep 0.2
fi

# 3. PulseAudio Compatibility Daemon
if ! pgrep -u "$USER" -x pipewire-pulse >/dev/null 2>&1; then
    pipewire-pulse &
    sleep 0.2
fi
