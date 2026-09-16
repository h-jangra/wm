#!/usr/bin/env python3
"""
rofi-calendar: Lightweight interactive Rofi calendar popup.
Toggled by clicking the Waybar clock module.
Features:
- Dynamic theme coloring from themes/palette.json
- Highlights current day with accent pill
- Previous / Next month navigation
- Quick copy of ISO date (YYYY-MM-DD) or human-readable full date
- Toggle support (clicking Waybar date again closes this instance)
"""
import sys
import os
import json
import subprocess
import datetime
import calendar
import signal

SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
REPO_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "../../.."))
PALETTE_FILE = os.path.join(REPO_DIR, "components/themes/generated/palette.json")
CACHE_PALETTE = os.path.expanduser("~/.cache/wm-palette.json")
CONF_RASI = os.path.expanduser("~/.config/rofi/calendar/calendar.rasi")
REPO_RASI = os.path.join(SCRIPT_DIR, "calendar.rasi")
PID_FILE = "/tmp/rofi-calendar.pid"

DEFAULT_COLORS = {
    "accent": "#88c0d0",
    "accent_alt": "#81a1c1",
    "background": "#2e3440",
    "foreground": "#d8dee9",
    "foreground_muted": "#6c7086",
    "border": "#4c566a"
}

def load_palette():
    colors = DEFAULT_COLORS.copy()
    target = None
    if os.path.isfile(PALETTE_FILE):
        target = PALETTE_FILE
    elif os.path.isfile(CACHE_PALETTE):
        target = CACHE_PALETTE

    if target:
        try:
            with open(target, "r") as f:
                data = json.load(f)
                colors["accent"] = data.get("accent", DEFAULT_COLORS["accent"])
                colors["accent_alt"] = data.get("accent_alt", colors["accent"])
                colors["background"] = data.get("background", DEFAULT_COLORS["background"])
                colors["foreground"] = data.get("foreground", DEFAULT_COLORS["foreground"])
                colors["border"] = data.get("border", DEFAULT_COLORS["border"])
                colors["foreground_muted"] = data.get("color8", DEFAULT_COLORS["foreground_muted"])
        except Exception:
            pass
    return colors

def cleanup(signum=None, frame=None):
    try:
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)
    except Exception:
        pass
    sys.exit(0)

def notify(msg):
    try:
        subprocess.run([
            "notify-send",
            "-h", "string:x-canonical-private-synchronous:wm-calendar",
            "Calendar",
            msg
        ], check=False)
    except Exception:
        pass

def copy_to_clipboard(text):
    try:
        proc = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE)
        proc.communicate(input=text.encode("utf-8"))
        notify(f"Copied '{text}' to clipboard")
    except Exception as e:
        notify(f"Error copying to clipboard: {e}")

def get_theme_path():
    if os.path.isfile(CONF_RASI):
        return CONF_RASI
    elif os.path.isfile(REPO_RASI):
        return REPO_RASI
    return ""

def format_calendar_mesg(year, month, today, colors):
    cal = calendar.Calendar(firstweekday=calendar.SUNDAY)
    weeks = cal.monthdayscalendar(year, month)

    month_date = datetime.date(year, month, 1)
    month_name = month_date.strftime("%B %Y")
    today_str = today.strftime("%A, %d %B %Y")

    accent = colors.get("accent", "#88c0d0")
    accent_alt = colors.get("accent_alt", "#81a1c1")
    bg = colors.get("background", "#2e3440")
    fg_muted = colors.get("foreground_muted", "#6c7086")

    # Header with month, year, and current date
    lines = [
        f'<span size="140%" weight="bold" color="{accent}">󰸗  {month_name}</span>',
        f'<span size="100%" color="{fg_muted}">{today_str}</span>',
        "",
        f'<span weight="bold" color="{accent_alt}"> Su  Mo  Tu  We  Th  Fr  Sa </span>'
    ]

    for week in weeks:
        row = []
        for day in week:
            if day == 0:
                row.append("    ")
            elif day == today.day and month == today.month and year == today.year:
                row.append(f'<span background="{accent}" color="{bg}" weight="bold"> {day:2d} </span>')
            else:
                row.append(f" {day:2d} ")
        lines.append("".join(row))

    return "\n".join(lines)

def main():
    # Toggle behavior: if an existing rofi-calendar process is running, kill it
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, "r") as f:
                old_pid = int(f.read().strip())
            if old_pid != os.getpid():
                try:
                    os.kill(old_pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
                try:
                    os.remove(PID_FILE)
                except OSError:
                    pass
                sys.exit(0)
        except Exception:
            pass

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    try:
        with open(PID_FILE, "w") as f:
            f.write(str(os.getpid()))
    except Exception:
        pass

    today = datetime.date.today()
    curr_year = today.year
    curr_month = today.month

    rasi = get_theme_path()
    colors = load_palette()

    while True:
        mesg = format_calendar_mesg(curr_year, curr_month, today, colors)

        options = [
            "󰸗  Today",
            "󰥔  Current Month",
            "󰁍  Previous Month",
            "󰁔  Next Month"
        ]

        cmd = ["rofi", "-dmenu", "-mesg", mesg]
        if rasi:
            cmd.extend(["-theme", rasi])

        try:
            proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
            stdout, _ = proc.communicate(input="\n".join(options))
            chosen = stdout.strip()
        except Exception:
            break

        if not chosen or proc.returncode != 0:
            break

        if "Previous Month" in chosen:
            if curr_month == 1:
                curr_month = 12
                curr_year -= 1
            else:
                curr_month -= 1
        elif "Next Month" in chosen:
            if curr_month == 12:
                curr_month = 1
                curr_year += 1
            else:
                curr_month += 1
        elif "Today" in chosen or "Current Month" in chosen:
            curr_year = today.year
            curr_month = today.month
        else:
            break

    cleanup()

if __name__ == "__main__":
    main()
