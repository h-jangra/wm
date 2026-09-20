#!/usr/bin/env python3
"""
theme-engine.py: Central Theme Engine for Void Linux + MangoWC rice.

Generates and applies theme tokens across:
- Eww
- Foot
- Alacritty
- Mako
- MangoWC
- GTK 3 & 4
- btop
- Fastfetch
- MangoBar
- Rofi

Also handles wallpaper switching, terminal color broadcasting,
state tracking, and live subsystem reloads.
"""

import glob
import json
import os
import re
import subprocess
import sys
import time

SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
REPO_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "../.."))

THEMES_DIR = SCRIPT_DIR
PRESETS_DIR = os.path.join(THEMES_DIR, "presets")
DEFS_DIR = os.path.join(THEMES_DIR, "definitions")
GENERATED_DIR = os.path.join(THEMES_DIR, "generated")

STATE_DIR = os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state/wm"))
os.makedirs(STATE_DIR, exist_ok=True)

CONFIG_DIR = os.path.join(REPO_DIR, "config")
DOTFILES_DIR = CONFIG_DIR
COMPONENTS_DIR = CONFIG_DIR

MANGO_CONF = os.path.join(DOTFILES_DIR, "mango", "config.conf")
MAKO_CONF = os.path.join(DOTFILES_DIR, "mako", "config")
GTK_CSS = os.path.join(DOTFILES_DIR, "gtk-3.0", "theme.css")
ROFI_COLORS_PATH = os.path.join(COMPONENTS_DIR, "rofi", "colors.rasi")
MANGOBAR_STYLE_PATH = os.path.join(COMPONENTS_DIR, "mangobar", "theme.css")

BTOP_THEMES_DIR = os.path.expanduser("~/.config/btop/themes")
BTOP_CONF = os.path.expanduser("~/.config/btop/btop.conf")
FASTFETCH_CONF = os.path.expanduser("~/.config/fastfetch/config.jsonc")

DEFAULTS = {
    "background": "#1e1e2e",
    "foreground": "#cdd6f4",
    "accent": "#b4befe",
    "accent_alt": "#89b4fa",
    "border": "#45475a",
    "capsule_bg": "#181825",
    "capsule_hover": "#313244",
    "capsule_fg": "#cdd6f4",
    "ws_urgent": "#f38ba8",
    "color8": "#585b70",
    "vol": "#a6e3a1",
    "net": "#f9e2af",
    "bat": "#89b4fa",
    "bt": "#89b4fa",
    "clock": "#f5c2e7",
    "ram": "#cba6f7",
    "ws_focused": "#b4befe",
    "ws_occupied": "#cba6f7",
    "ws_empty": "#585b70",
}

def value(theme, key, fallback=None):
    """Read a theme value with a centralized fallback."""
    if fallback is None:
        fallback = DEFAULTS.get(key, "")
    return theme.get(key, fallback)

def write_file(path, content, *, create_parent=True):
    if create_parent:
        parent = os.path.dirname(path)
        if parent:
            os.makedirs(parent, exist_ok=True)
    if os.path.islink(path):
        try:
            os.unlink(path)
        except OSError:
            pass

    with open(path, "w", encoding="utf-8") as file:
        file.write(content)

def write_json(path, data):
    """Write formatted JSON to a file."""
    if os.path.dirname(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)

    with open(path, "w", encoding="utf-8") as file:
        json.dump(data, file, indent=2)
        file.write("\n")

def read_json(path):
    """Read a JSON file."""
    with open(path, "r", encoding="utf-8") as file:
        return json.load(file)

def run_quiet(command, **kwargs):
    """Run a command while suppressing output and tolerating missing binaries."""
    options = {
        "stdout": subprocess.DEVNULL,
        "stderr": subprocess.DEVNULL,
        **kwargs,
    }

    try:
        return subprocess.run(command, **options)
    except OSError:
        return None

def first_existing_file(paths):
    """Return the first existing regular file from a list of paths."""
    for path in paths:
        if os.path.isfile(path):
            return path
    return None

def strip_hash(color):
    """Remove a leading hash from a hexadecimal color."""
    if color and color.startswith("#"):
        return color[1:]
    return color or "000000"

def to_argb_hex(color, alpha="ff"):
    """Convert a CSS color into MangoWC's ARGB hexadecimal format."""
    return f"0x{strip_hash(color).lower()}{alpha}"

def find_theme_wallpaper(theme_id, preferred=""):
    """Resolve a preferred wallpaper or find one in the theme preset."""
    preferred = os.path.expanduser(os.path.expandvars(preferred or ""))

    if preferred and os.path.isfile(preferred):
        return preferred

    wallpaper_dir = os.path.join(PRESETS_DIR, theme_id, "wallpapers")
    if preferred and os.path.isdir(wallpaper_dir):
        candidate = os.path.join(wallpaper_dir, os.path.basename(preferred))
        if os.path.isfile(candidate):
            return candidate

    wallpaper_dir = os.path.join(PRESETS_DIR, theme_id, "wallpapers")
    if not os.path.isdir(wallpaper_dir):
        return ""

    patterns = (
        "*.jpg",
        "*.JPG",
        "*.jpeg",
        "*.JPEG",
        "*.webp",
        "*.WEBP",
        "*.png",
        "*.PNG",
    )

    wallpapers = []
    for pattern in patterns:
        wallpapers.extend(glob.glob(os.path.join(wallpaper_dir, pattern)))

    return sorted(set(wallpapers))[0] if wallpapers else ""

def load_bash_theme(theme_id):
    """Load a theme defined by a Bash configuration file."""
    candidates = (
        os.path.join(PRESETS_DIR, theme_id, "theme.conf"),
        os.path.join(PRESETS_DIR, theme_id, "theme-config.bash"),
        os.path.join(THEMES_DIR, theme_id, "theme-config.bash"),
        os.path.join(THEMES_DIR, theme_id, "theme.conf"),
    )

    theme_bash = first_existing_file(candidates)
    if not theme_bash:
        return None

    command = [
        "bash",
        "-c",
        (
            f'. "{theme_bash}" && printf "%s\\n" '
            '"bg=$bg" "fg=$fg" "black=$black" "red=$red" '
            '"green=$green" "yellow=$yellow" "blue=$blue" '
            '"magenta=$magenta" "cyan=$cyan" "white=$white" '
            '"NORMAL_BC=$NORMAL_BC" "FOCUSED_BC=$FOCUSED_BC" '
            '"DEFAULT_WALL=$DEFAULT_WALL" "gtk_theme=$gtk_theme" '
            '"gtk_icons=$gtk_icons" "accent_color=$accent_color"'
        ),
    ]

    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return None

    if result.returncode != 0:
        return None

    variables = {}
    for line in result.stdout.splitlines():
        if "=" in line:
            key, item = line.split("=", 1)
            variables[key] = item.strip()

    bg = variables.get("bg", "#181825")
    fg = variables.get("fg", "#cdd6f4")
    accent = (
        variables.get("FOCUSED_BC")
        or variables.get("magenta")
        or variables.get("blue")
        or "#b4befe"
    )
    border = (
        variables.get("NORMAL_BC")
        or variables.get("blue")
        or "#45475a"
    )
    capsule_bg = variables.get("black") or bg

    wallpaper = find_theme_wallpaper(
        theme_id,
        variables.get("DEFAULT_WALL", ""),
    )

    colors = {
        "color0": variables.get("black", "#1e1e2e"),
        "color1": variables.get("red", "#f38ba8"),
        "color2": variables.get("green", "#a6e3a1"),
        "color3": variables.get("yellow", "#ea9d34"),
        "color4": variables.get("blue", "#89b4fa"),
        "color5": variables.get("magenta", "#cba6f7"),
        "color6": variables.get("cyan", "#89dceb"),
        "color7": variables.get("white", "#cdd6f4"),
        "color8": variables.get("black", "#585b70"),
        "color9": variables.get("red", "#f38ba8"),
        "color10": variables.get("green", "#a6e3a1"),
        "color11": variables.get("yellow", "#ea9d34"),
        "color12": variables.get("blue", "#89b4fa"),
        "color13": variables.get("magenta", "#cba6f7"),
        "color14": variables.get("cyan", "#89dceb"),
        "color15": variables.get("white", "#cdd6f4"),
    }

    return {
        "id": theme_id,
        "name": theme_id.capitalize(),
        "background": bg,
        "foreground": fg,
        "accent": accent,
        "accent_alt": variables.get("cyan", accent),
        "border": border,
        "capsule_bg": capsule_bg,
        "capsule_hover": border,
        "capsule_fg": fg,
        "clock": variables.get("magenta", accent),
        "ram": variables.get("cyan", accent),
        "vol": variables.get("green", "#a6e3a1"),
        "net": variables.get("yellow", "#f9e2af"),
        "bat": variables.get("blue", "#89b4fa"),
        "bt": variables.get("blue", "#89b4fa"),
        "ws_focused": accent,
        "ws_occupied": variables.get("cyan", accent),
        "ws_empty": border,
        "ws_urgent": variables.get("red", "#f38ba8"),
        **colors,
        "wallpaper_path": wallpaper,
        "gtk_theme": variables.get("gtk_theme", "Adwaita-dark"),
        "gtk_icons": variables.get("gtk_icons", "Papirus-Custom"),
    }

def load_theme(theme_id):
    """Load a dynamic, Bash-based, or JSON theme."""
    if theme_id == "dynamic":
        for filename in ("dynamic.json", "palette.json"):
            for directory in (GENERATED_DIR, THEMES_DIR):
                path = os.path.join(directory, filename)
                if os.path.isfile(path):
                    return read_json(path)

        raise FileNotFoundError(
            "Dynamic theme palette not found. "
            "Run theme-from-wallpaper first."
        )

    bash_theme = load_bash_theme(theme_id)
    if bash_theme is not None:
        return bash_theme

    candidates = (
        os.path.join(DEFS_DIR, f"{theme_id}.json"),
        os.path.join(THEMES_DIR, "defs", f"{theme_id}.json"),
    )

    theme_file = first_existing_file(candidates)
    if theme_file:
        return read_json(theme_file)

    raise FileNotFoundError(
        f"Theme '{theme_id}' not found in {PRESETS_DIR} or {DEFS_DIR}"
    )
def generate_mangobar_css(theme):
    return f"""@define-color bg {value(theme, 'background')};
@define-color fg {value(theme, 'foreground')};
@define-color accent {value(theme, 'accent')};
@define-color accent_alt {value(theme, 'accent_alt')};
@define-color border {value(theme, 'border')};
@define-color capsule_bg {value(theme, 'capsule_bg')};
@define-color capsule_hover {value(theme, 'capsule_hover')};
@define-color capsule_fg {value(theme, 'capsule_fg')};
@define-color ws_occupied {value(theme, 'ws_occupied', value(theme, 'accent_alt'))};
@define-color ws_focused {value(theme, 'ws_focused', value(theme, 'accent'))};
@define-color ws_urgent {value(theme, 'ws_urgent')};
@define-color ws_empty {value(theme, 'ws_empty', value(theme, 'border'))};
@define-color clock_color {value(theme, 'clock', value(theme, 'accent'))};
@define-color ram_color {value(theme, 'ram', value(theme, 'accent_alt'))};
@define-color net_color {value(theme, 'net', value(theme, 'accent'))};
@define-color vol_color {value(theme, 'vol', value(theme, 'accent_alt'))};
@define-color bat_color {value(theme, 'bat', value(theme, 'accent'))};
@define-color session_color {value(theme, 'session', value(theme, 'ws_urgent'))};
@define-color recorder_color {value(theme, 'recorder', value(theme, 'ws_urgent'))};
@define-color keyviz_color {value(theme, 'accent')};
"""

def generate_rofi_shared_rasi(theme):
    bg = value(theme, "background")
    fg = value(theme, "foreground")
    bg_alt = value(theme, "capsule_bg")
    accent = value(theme, "accent")
    active = value(theme, "vol", value(theme, "color2"))
    urgent = value(theme, "ws_urgent", value(theme, "color1"))
    border = value(theme, "border")
    muted = value(theme, "color8")

    return f"""// Autogenerated
* {{
    font:                        "Maple Mono NF 11";
    background:                  {bg}EE;
    bg-alt:                      {bg_alt}FF;
    background-alt:              {bg_alt}FF;
    background-surface:          {value(theme, 'capsule_hover')}FF;
    border-color:                {border}FF;
    foreground:                  {fg}FF;
    foreground-muted:            {muted}FF;
    selected:                    {accent}FF;
    selected-fg:                 {bg}FF;
    active:                      {active}FF;
    urgent:                      {urgent}FF;
    accent:                      {accent}FF;
}}
"""

def generate_palette_css(theme):
    colors = {
        "capsule_bg": value(theme, "capsule_bg", "#1f2335"),
        "capsule_hover": value(theme, "capsule_hover", "#292e42"),
        "capsule_fg": value(theme, "capsule_fg", "#c0caf5"),
        "border_color": value(theme, "border", "#3b4261"),
        "clock_color": value(theme, "clock", "#bb9af7"),
        "ram_color": value(theme, "ram", "#7dcfff"),
        "keyviz_color": value(theme, "accent", "#7aa2f7"),
        "recorder_color": value(theme, "ws_urgent", "#f7768e"),
        "ws_focused": value(theme, "ws_focused", "#7aa2f7"),
        "ws_occupied": value(theme, "ws_occupied", "#bb9af7"),
        "ws_empty": value(theme, "ws_empty", "#565f89"),
        "ws_urgent": value(theme, "ws_urgent", "#f7768e"),
        "bt_color": value(theme, "bt", "#b4f9f8"),
        "net_color": value(theme, "net", "#e0af68"),
        "vol_color": value(theme, "vol", "#9ece6a"),
        "bat_color": value(theme, "bat", "#2ac3de"),
        "session_color": value(theme, "ws_urgent", "#f7768e"),
        "accent": value(theme, "accent", "#7aa2f7"),
        "accent_alt": value(theme, "accent_alt", "#7dcfff"),
        "rd1": value(theme, "accent", "#7aa2f7"),
        "dark_bg": value(theme, "capsule_bg", "#1f2335"),
        "hover_bg": value(theme, "capsule_hover", "#292e42"),
        "bg": value(theme, "background", "#1a1b26"),
        "fg": value(theme, "foreground", "#c0caf5"),
    }

    lines = [
        f"/* Theme - {theme.get('name', 'Theme')} */",
    ]

    lines.extend(
        f"@define-color {name} {color};"
        for name, color in colors.items()
    )

    return "\n".join(lines) + "\n"

def generate_foot_ini(theme):
    lines = [
        "# -*- conf -*-",
        f"# Theme - {theme.get('name', 'Theme')}",
        "",
        "[colors-dark]",
        f"background = {strip_hash(value(theme, 'background', '#2e3440'))}",
        f"foreground = {strip_hash(value(theme, 'foreground', '#d8dee9'))}",
        (
            "cursor = "
            f"{strip_hash(value(theme, 'background', '#2e3440'))} "
            f"{strip_hash(theme.get('cursor', value(theme, 'foreground', '#d8dee9')))}"
        ),
        f"selection-background = {strip_hash(theme.get('selection_bg', value(theme, 'border', '#4c566a')))}",
        f"selection-foreground = {strip_hash(theme.get('selection_fg', value(theme, 'foreground', '#eceff4')))}",
        "",
    ]

    for index in range(8):
        lines.append(
            f"regular{index} = {strip_hash(theme.get(f'color{index}', '#000000'))}"
        )

    lines.append("")

    for index in range(8, 16):
        lines.append(
            f"bright{index - 8} = {strip_hash(theme.get(f'color{index}', '#ffffff'))}"
        )

    lines.append("")
    return "\n".join(lines)

def ensure_hex_color(color, fallback="#000000"):
    """Ensure a color has a leading hash."""
    if not color:
        return fallback
    color_str = str(color).strip()
    if not color_str.startswith("#"):
        return f"#{color_str}"
    return color_str

def generate_alacritty_toml(theme):
    bg = ensure_hex_color(value(theme, "background", "#1e1e2e"))
    fg = ensure_hex_color(value(theme, "foreground", "#cdd6f4"))
    cursor_bg = ensure_hex_color(theme.get("cursor", fg))
    cursor_text = bg
    sel_bg = ensure_hex_color(theme.get("selection_bg", value(theme, "border", "#45475a")))
    sel_fg = ensure_hex_color(theme.get("selection_fg", fg))

    c = [ensure_hex_color(theme.get(f"color{i}", "#000000")) for i in range(16)]

    return f"""# Autogenerated rice colors for Alacritty
# Theme - {theme.get('name', 'Theme')}

[colors.primary]
background = "{bg}"
foreground = "{fg}"

[colors.cursor]
text = "{cursor_text}"
cursor = "{cursor_bg}"

[colors.selection]
text = "{sel_fg}"
background = "{sel_bg}"

[colors.normal]
black   = "{c[0]}"
red     = "{c[1]}"
green   = "{c[2]}"
yellow  = "{c[3]}"
blue    = "{c[4]}"
magenta = "{c[5]}"
cyan    = "{c[6]}"
white   = "{c[7]}"

[colors.bright]
black   = "{c[8]}"
red     = "{c[9]}"
green   = "{c[10]}"
yellow  = "{c[11]}"
blue    = "{c[12]}"
magenta = "{c[13]}"
cyan    = "{c[14]}"
white   = "{c[15]}"
"""

def generate_mako_conf(theme):
    accent = value(theme, "accent", "#88C0D0")
    bg = value(theme, "capsule_bg", "#242933")
    fg = value(theme, "capsule_fg", "#D8DEE9")
    border = value(theme, "border", "#4C566A")
    urgent = value(theme, "ws_urgent", "#BF616A")

    return f"""# Theme - {theme.get('name', 'Theme')}

font=Maple Mono NF 10
background-color={bg}F2
text-color={fg}
width=350
height=110
margin=14
padding=12
border-size=1
border-color={accent}
border-radius=6
icons=1
max-icon-size=48
default-timeout=5000
ignore-timeout=0
group-by=summary
progress-color={accent}FF

[urgency=low]
border-color={border}
default-timeout=3000

[urgency=normal]
border-color={accent}
default-timeout=5000

[urgency=critical]
border-color={urgent}
text-color=#FFFFFF
default-timeout=0
"""

def generate_shell_env(theme):
    lines = [
        f"# Theme - {theme.get('name', 'Theme')}",
        f"export WM_THEME='{theme.get('id', 'default')}'",
        f"export WM_THEME_NAME='{theme.get('name', 'Default')}'",
        f"export WM_BG='{value(theme, 'background', '#2e3440')}'",
        f"export WM_FG='{value(theme, 'foreground', '#d8dee9')}'",
        f"export WM_ACCENT='{value(theme, 'accent', '#88c0d0')}'",
        f"export WM_BORDER='{value(theme, 'border', '#4c566a')}'",
        f"export WM_CAPSULE_BG='{value(theme, 'capsule_bg', '#242933')}'",
        f"export WM_CAPSULE_HOVER='{value(theme, 'capsule_hover', '#3b4252')}'",
        f"export WM_CAPSULE_FG='{value(theme, 'capsule_fg', '#d8dee9')}'",
        f"export WM_WALLPAPER='{theme.get('wallpaper', '')}'",
    ]
    return "\n".join(lines) + "\n"

def update_mango_conf(theme):
    if not os.path.isfile(MANGO_CONF):
        return

    with open(MANGO_CONF, "r", encoding="utf-8") as file:
        config = file.read()

    colors = {
        "rootcolor": to_argb_hex(value(theme, "background", "#2e3440")),
        "bordercolor": to_argb_hex(value(theme, "border", "#4c566a")),
        "focuscolor": to_argb_hex(value(theme, "accent", "#88c0d0")),
        "maximizescreencolor": to_argb_hex(
            value(theme, "accent_alt", value(theme, "accent", "#81a1c1"))
        ),
        "urgentcolor": to_argb_hex(value(theme, "ws_urgent", "#bf616a")),
        "scratchpadcolor": to_argb_hex(
            value(theme, "capsule_hover", "#3b4252"),
            "cc",
        ),
        "globalcolor": to_argb_hex(value(theme, "clock", "#b48ead"), "aa"),
        "overlaycolor": to_argb_hex(value(theme, "accent", "#8fbcbb")),
    }

    color_block = "\n".join(
        [
            f"# {theme.get('name', 'Theme')} Palette Colors (ARGB)",
            *(f"{key} = {color}" for key, color in colors.items()),
        ]
    )

    patterns = (
        r"# .* Palette Colors \(ARGB\)[\s\S]*?overlaycolor = 0x[0-9a-fA-F]+",
        r"rootcolor = 0x[0-9a-fA-F]+[\s\S]*?overlaycolor = 0x[0-9a-fA-F]+",
    )

    for pattern in patterns:
        if re.search(pattern, config):
            config = re.sub(pattern, color_block, config)
            write_file(MANGO_CONF, config)
            return

def update_gtk_theme(theme):
    bg = value(theme, "background")
    fg = value(theme, "foreground")
    accent = value(theme, "accent")
    accent_alt = value(theme, "accent_alt", "#94e2d5")
    border = value(theme, "border")
    sidebar = value(theme, "capsule_bg")
    surface = value(theme, "capsule_hover")
    urgent = value(theme, "ws_urgent")
    success = value(theme, "vol")
    name = theme.get("name", "Theme")

    css = f"""/* Theme - {name} */

@define-color theme_bg {bg};
@define-color theme_fg {fg};
@define-color theme_sidebar {sidebar};
@define-color theme_surface {surface};
@define-color theme_border {border};
@define-color theme_accent {accent};
@define-color theme_accent_alt {accent_alt};
@define-color theme_selected_bg {accent};
@define-color theme_selected_fg {bg};
@define-color theme_urgent {urgent};
@define-color theme_success {success};

@define-color accent {accent};
@define-color accent_alt {accent_alt};
@define-color bg {bg};
@define-color fg {fg};
@define-color border {border};
@define-color sidebar {sidebar};
@define-color surface {surface};
@define-color urgent {urgent};
@define-color success {success};

@define-color theme_bg_color @theme_bg;
@define-color theme_fg_color @theme_fg;
@define-color theme_base_color @theme_bg;
@define-color theme_text_color @theme_fg;
@define-color theme_selected_bg_color @theme_selected_bg;
@define-color theme_selected_fg_color @theme_selected_fg;

@define-color theme_unfocused_bg_color @theme_bg;
@define-color theme_unfocused_fg_color @theme_fg;
@define-color theme_unfocused_base_color @theme_bg;
@define-color theme_unfocused_text_color @theme_fg;
@define-color theme_unfocused_selected_bg_color @theme_selected_bg;
@define-color theme_unfocused_selected_fg_color @theme_selected_fg;

@define-color insensitive_bg_color @theme_bg;
@define-color insensitive_fg_color alpha(@theme_fg, 0.45);
@define-color insensitive_base_color @theme_bg;
@define-color unfocused_insensitive_color alpha(@theme_fg, 0.35);

@define-color borders @theme_border;
@define-color unfocused_borders @theme_border;
@define-color warning_color @theme_urgent;
@define-color error_color @theme_urgent;
@define-color success_color @theme_success;
@define-color info_color @theme_accent;
@define-color question_color @theme_accent;
@define-color link_color @theme_accent;
@define-color link_visited_color @theme_accent_alt;

@define-color window_bg_color @theme_bg;
@define-color window_fg_color @theme_fg;
@define-color window_border_color @theme_border;
@define-color view_bg_color @theme_bg;
@define-color view_fg_color @theme_fg;
@define-color content_view_bg @theme_bg;
@define-color text_view_bg @theme_bg;

@define-color headerbar_bg_color @theme_sidebar;
@define-color headerbar_fg_color @theme_fg;
@define-color headerbar_border_color @theme_border;
@define-color headerbar_backdrop_color @theme_bg;
@define-color headerbar_shade_color rgba(0, 0, 0, 0.2);

@define-color toolbar_bg_color @theme_sidebar;
@define-color toolbar_fg_color @theme_fg;
@define-color toolbar_border_color @theme_border;
@define-color toolbar_backdrop_color @theme_bg;
@define-color actionbar_bg_color @theme_sidebar;
@define-color actionbar_fg_color @theme_fg;
@define-color actionbar_border_color @theme_border;
@define-color actionbar_backdrop_color @theme_bg;
@define-color searchbar_bg_color @theme_sidebar;
@define-color searchbar_fg_color @theme_fg;
@define-color searchbar_border_color @theme_border;
@define-color statusbar_bg_color @theme_sidebar;
@define-color statusbar_fg_color @theme_fg;
@define-color menubar_bg_color @theme_sidebar;
@define-color menubar_fg_color @theme_fg;
@define-color infobar_bg_color @theme_surface;
@define-color infobar_fg_color @theme_fg;

@define-color sidebar_bg_color @theme_sidebar;
@define-color sidebar_fg_color @theme_fg;
@define-color sidebar_backdrop_color @theme_bg;
@define-color sidebar_border_color @theme_border;
@define-color secondary_sidebar_bg_color @theme_bg;
@define-color secondary_sidebar_fg_color @theme_fg;

@define-color card_bg_color @theme_surface;
@define-color card_fg_color @theme_fg;
@define-color card_border_color @theme_border;
@define-color card_shade_color rgba(0, 0, 0, 0.15);
@define-color dialog_bg_color @theme_bg;
@define-color dialog_fg_color @theme_fg;
@define-color popover_bg_color @theme_surface;
@define-color popover_fg_color @theme_fg;
@define-color popover_shade_color rgba(0, 0, 0, 0.25);
@define-color overview_bg_color @theme_surface;
@define-color overview_fg_color @theme_fg;

@define-color tooltip_bg_color @theme_surface;
@define-color tooltip_fg_color @theme_fg;
@define-color tooltip_border_color @theme_border;
@define-color theme_tooltip_bg_color @theme_surface;
@define-color theme_tooltip_fg_color @theme_fg;
@define-color progress_bg_color @theme_accent;
@define-color progress_trough_color @theme_surface;
@define-color shade_color rgba(0, 0, 0, 0.25);
@define-color scrollbar_outline_color transparent;

@define-color accent_color @theme_accent;
@define-color accent_bg_color @theme_accent;
@define-color accent_fg_color @theme_selected_fg;
@define-color destructive_color @theme_urgent;
@define-color destructive_bg_color @theme_urgent;
@define-color destructive_fg_color @theme_selected_fg;
@define-color theme_destructive_bg @theme_urgent;
@define-color theme_destructive_hover alpha(@theme_urgent, 0.85);
@define-color theme_destructive_active @theme_urgent;
@define-color theme_border_dim alpha(@theme_border, 0.6);
@define-color warning_bg_color @theme_urgent;
@define-color warning_fg_color @theme_selected_fg;
@define-color success_bg_color @theme_success;
@define-color success_fg_color @theme_selected_fg;
@define-color error_color @theme_urgent;
@define-color error_bg_color @theme_urgent;
@define-color error_fg_color @theme_selected_fg;
"""

    write_file(GTK_CSS, css)

    # Keep GTK settings.ini icon theme synchronized
    settings_ini_path = os.path.join(DOTFILES_DIR, "gtk-3.0", "settings.ini")
    if os.path.isfile(settings_ini_path):
        try:
            with open(settings_ini_path, "r", encoding="utf-8") as f:
                ini_content = f.read()
            icon_theme = theme.get("gtk_icons", "Papirus-Custom")
            gtk_theme = theme.get("gtk_theme", "Adwaita-dark")
            ini_content = re.sub(
                r"gtk-icon-theme-name\s*=.*",
                f"gtk-icon-theme-name = {icon_theme}",
                ini_content,
            )
            ini_content = re.sub(
                r"gtk-theme-name\s*=.*",
                f"gtk-theme-name = {gtk_theme}",
                ini_content,
            )
            write_file(settings_ini_path, ini_content)
        except OSError:
            pass

def update_papirus_icons(theme):
    """
    Recolor minimal Papirus folder SVGs and update symbolic color scheme tokens
    to match the active theme's palette.
    """
    papirus_dir = os.path.join(REPO_DIR, "assets", "papirus")
    templates_dir = os.path.join(papirus_dir, "templates", "places")
    if not os.path.isdir(templates_dir):
        return

    accent = ensure_hex_color(value(theme, "accent", "#b4befe"))
    bg = ensure_hex_color(value(theme, "background", "#1e1e2e"))
    fg = ensure_hex_color(value(theme, "foreground", "#cdd6f4"))

    def hex_to_rgb(h):
        h = h.lstrip("#")
        return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

    def rgb_to_hex(rgb):
        return "#{:02x}{:02x}{:02x}".format(*[max(0, min(255, int(c))) for c in rgb])

    r, g, b = hex_to_rgb(accent)
    # Back flap is darker (~80% brightness)
    back_color = rgb_to_hex((r * 0.80, g * 0.80, b * 0.80))
    # Glyph on front flap: contrasting dark or light
    lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
    if lum > 0.45:
        glyph_color = rgb_to_hex((r * 0.35, g * 0.35, b * 0.35))
    else:
        glyph_color = rgb_to_hex((r + (255 - r) * 0.65, g + (255 - g) * 0.65, b + (255 - b) * 0.65))

    replacements = {
        "__FRONT_COLOR__": accent,
        "__BACK_COLOR__": back_color,
        "__GLYPH_COLOR__": glyph_color,
        "__HIGHLIGHT_COLOR__": accent,
        "__TEXT_COLOR__": fg,
    }

    for size_dir in glob.glob(os.path.join(templates_dir, "*")):
        if not os.path.isdir(size_dir):
            continue
        size_name = os.path.basename(size_dir)
        dest_dir = os.path.join(papirus_dir, size_name, "places")
        os.makedirs(dest_dir, exist_ok=True)
        for tf in glob.glob(os.path.join(size_dir, "*.svg")):
            try:
                with open(tf, "r", encoding="utf-8", errors="ignore") as fp:
                    content = fp.read()
                for k, v in replacements.items():
                    content = content.replace(k, v)
                with open(os.path.join(dest_dir, os.path.basename(tf)), "w", encoding="utf-8") as fp:
                    fp.write(content)
            except OSError:
                pass

    # Ensure icon cache is refreshed
    for icon_dir in [
        papirus_dir,
        os.path.expanduser("~/.local/share/icons/Papirus-Custom"),
        os.path.expanduser("~/.icons/Papirus-Custom"),
    ]:
        if os.path.isdir(icon_dir):
            run_quiet(["gtk-update-icon-cache", "-q", "-f", "-t", icon_dir])

def update_gsettings(theme):
    commands = [
        [
            "gsettings", "set", "org.gnome.desktop.interface",
            "gtk-theme", theme.get("gtk_theme", "Adwaita-dark"),
        ],
        [
            "gsettings", "set", "org.gnome.desktop.interface",
            "icon-theme", theme.get("gtk_icons", "Papirus-Custom"),
        ],
        [
            "gsettings", "set", "org.gnome.desktop.interface",
            "color-scheme", "prefer-dark",
        ],
        [
            "gsettings", "set", "org.gnome.desktop.interface",
            "font-name", "Maple Mono 10",
        ],
        [
            "gsettings", "set", "org.gnome.desktop.interface",
            "cursor-theme", "Adwaita",
        ],
        [
            "gsettings", "set", "org.gnome.desktop.interface",
            "cursor-size", "24",
        ],
    ]

    for command in commands:
        run_quiet(command)

def update_thunar_xfconf():
    settings = (
        ("last-menubar-visible", "false"),
        ("last-statusbar-visible", "false"),
        ("last-location-bar", "ThunarLocationButtons"),
        ("misc-symbolic-icons-in-toolbar", "true"),
        ("misc-single-click", "false"),
        ("shortcuts-icon-size", "THUNAR_ICON_SIZE_16"),
        (
            "last-toolbar-items",
            "location-bar:1,toggle-split-view:1,menu:1,back:0,forward:0,"
            "open-parent:0,reload:0,search:0,view-switcher:0,open-home:0,"
            "new-tab:0,new-window:0,undo:0,redo:0,zoom-out:0,zoom-in:0,"
            "zoom-reset:0,view-as-icons:0,view-as-detailed-list:0,"
            "view-as-compact-list:0",
        ),
    )

    for property_name, value_to_set in settings:
        run_quiet(
            [
                "xfconf-query",
                "-c",
                "thunar",
                "-p",
                f"/{property_name}",
                "-s",
                value_to_set,
            ]
        )

def update_btop(theme):
    repo_btop_themes = os.path.join(DOTFILES_DIR, "btop", "themes")
    os.makedirs(repo_btop_themes, exist_ok=True)
    theme_file_repo = os.path.join(repo_btop_themes, "wm.theme")

    content = f"""# Theme - {theme.get('name', 'Theme')}
theme[main_bg]="{value(theme, 'background', '#2e3440')}"
theme[main_fg]="{value(theme, 'foreground', '#d8dee9')}"
theme[title]="{value(theme, 'accent', '#88c0d0')}"
theme[hi_fg]="{value(theme, 'accent_alt', value(theme, 'accent', '#81a1c1'))}"
theme[selected_bg]="{value(theme, 'capsule_hover', '#3b4252')}"
theme[selected_fg]="{value(theme, 'foreground', '#eceff4')}"
theme[inactive_fg]="{value(theme, 'border', '#4c566a')}"
theme[proc_misc]="{value(theme, 'clock', '#b48ead')}"
theme[cpu_box]="{value(theme, 'border', '#4c566a')}"
theme[mem_box]="{value(theme, 'border', '#4c566a')}"
theme[net_box]="{value(theme, 'border', '#4c566a')}"
theme[proc_box]="{value(theme, 'border', '#4c566a')}"
theme[div_line]="{value(theme, 'border', '#4c566a')}"
theme[temp_start]="{value(theme, 'vol', '#a3be8c')}"
theme[temp_mid]="{value(theme, 'net', '#ebcb8b')}"
theme[temp_end]="{value(theme, 'ws_urgent', '#bf616a')}"
theme[cpu_start]="{value(theme, 'vol', '#a3be8c')}"
theme[cpu_mid]="{value(theme, 'net', '#ebcb8b')}"
theme[cpu_end]="{value(theme, 'ws_urgent', '#bf616a')}"
theme[free_start]="{value(theme, 'vol', '#a3be8c')}"
theme[free_mid]="{value(theme, 'net', '#ebcb8b')}"
theme[free_end]="{value(theme, 'ws_urgent', '#bf616a')}"
theme[cached_start]="{value(theme, 'accent', '#88c0d0')}"
theme[cached_mid]="{value(theme, 'clock', '#b48ead')}"
theme[cached_end]="{value(theme, 'ws_urgent', '#bf616a')}"
theme[available_start]="{value(theme, 'accent', '#88c0d0')}"
theme[available_mid]="{value(theme, 'vol', '#a3be8c')}"
theme[available_end]="{value(theme, 'net', '#ebcb8b')}"
theme[used_start]="{value(theme, 'accent', '#88c0d0')}"
theme[used_mid]="{value(theme, 'net', '#ebcb8b')}"
theme[used_end]="{value(theme, 'ws_urgent', '#bf616a')}"
theme[download_start]="{value(theme, 'accent', '#88c0d0')}"
theme[download_mid]="{value(theme, 'clock', '#b48ead')}"
theme[download_end]="{value(theme, 'ws_urgent', '#bf616a')}"
theme[upload_start]="{value(theme, 'net', '#ebcb8b')}"
theme[upload_mid]="{value(theme, 'accent', '#88c0d0')}"
theme[upload_end]="{value(theme, 'clock', '#b48ead')}"
"""

    write_file(theme_file_repo, content)
    try:
        if not os.path.islink(BTOP_THEMES_DIR):
            os.makedirs(BTOP_THEMES_DIR, exist_ok=True)
            write_file(os.path.join(BTOP_THEMES_DIR, "wm.theme"), content)
    except OSError:
        pass

    if not os.path.isfile(BTOP_CONF):
        return

    with open(BTOP_CONF, "r", encoding="utf-8") as file:
        config = file.read()

    if (
        'color_theme = "wm"' not in config
        and 'color_theme = "wm.theme"' not in config
    ):
        config = re.sub(r'color_theme = ".*?"', 'color_theme = "wm"', config)
        write_file(BTOP_CONF, config)

def update_fastfetch(theme):
    config = {
        "$schema": (
            "https://github.com/fastfetch-cli/fastfetch/"
            "raw/dev/doc/json_schema.json"
        ),
        "logo": {
            "type": "small",
            "padding": {"top": 1, "left": 1, "right": 2},
        },
        "display": {
            "separator": " 󰅂 ",
            "color": {"keys": "cyan", "title": "blue"},
        },
        "modules": [
            "title",
            "separator",
            {"type": "os", "key": "󰣚 OS"},
            {"type": "kernel", "key": "󰌽 KR"},
            {"type": "wm", "key": "󱂬 WM"},
            {"type": "terminal", "key": "󰞷 TM"},
            {"type": "uptime", "key": "󰅐 UP"},
            {"type": "memory", "key": "󰍛 MEM"},
            "break",
            "colors",
        ],
    }

    try:
        write_json(FASTFETCH_CONF, config)
    except OSError:
        pass

def broadcast_term_colors(theme):
    """Broadcast OSC foreground/background colors to writable PTYs."""
    background = value(theme, "background", "#2e3440")
    foreground = value(theme, "foreground", "#d8dee9")
    sequence = f"\033]10;{foreground}\007\033]11;{background}\007"

    for pty in glob.glob("/dev/pts/[0-9]*"):
        if not os.access(pty, os.W_OK):
            continue

        try:
            with open(pty, "w", encoding="utf-8", errors="ignore") as file:
                file.write(sequence)
        except OSError:
            pass

def reload_subsystems():
    """Reload MangoWC, Mako, MangoBar, and Thunar-related processes."""
    run_quiet(["makoctl", "reload"])
    run_quiet(["mmsg", "dispatch", "reload_config"])

    bar_check = subprocess.run(
        ["pgrep", "-x", "mangobar"],
        capture_output=True,
        text=True,
        check=False,
    )

    if bar_check.returncode == 0 and bar_check.stdout.strip():
        run_quiet(["pkill", "-x", "mangobar"])
        time.sleep(0.2)

        try:
            subprocess.Popen(
                ["mangobar"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        except OSError:
            pass

    run_quiet(["thunar", "-q"])
    alacritty_check = subprocess.run(
        ["pgrep", "-x", "alacritty"],
        capture_output=True,
        text=True,
        check=False,
    )
    if alacritty_check.returncode == 0:
        run_quiet(["alacritty", "msg", "config", "-r"])

def update_wallpaper_links(theme_id):
    """Update the theme and current wallpaper directory symlinks in XDG cache."""
    wallpaper_dir = os.path.join(PRESETS_DIR, theme_id, "wallpapers")
    if not os.path.isdir(wallpaper_dir):
        return

    cache_wall_root = os.path.expanduser("~/.cache/wm")
    os.makedirs(cache_wall_root, exist_ok=True)

    for link_name in ("theme", "current"):
        link_path = os.path.join(cache_wall_root, link_name)
        try:
            if os.path.islink(link_path) or os.path.exists(link_path):
                os.unlink(link_path)
            os.symlink(wallpaper_dir, link_path)
        except OSError:
            pass

def switch_wallpaper(theme_id, theme):
    if theme_id == "dynamic":
        return

    wallpaper = find_theme_wallpaper(
        theme_id,
        theme.get("wallpaper_path") or theme.get("wallpaper", ""),
    )

    if not wallpaper:
        return

    wallpaper_manager = first_existing_file(
        (
            os.path.join(COMPONENTS_DIR, "wallpaper", "wallpaper-manager"),
            os.path.expanduser("~/.local/bin/wallpaper-manager"),
            "/usr/local/bin/wallpaper-manager",
        )
    )

    if wallpaper_manager and os.access(wallpaper_manager, os.X_OK):
        run_quiet([wallpaper_manager, "set", wallpaper, "--skip-theme"])

def apply_theme(theme_id, set_wallpaper=True):
    theme = load_theme(theme_id)
    os.makedirs(GENERATED_DIR, exist_ok=True)

    rofi_tokens = generate_rofi_shared_rasi(theme)
    write_file(ROFI_COLORS_PATH, rofi_tokens)
    write_file(
        os.path.join(GENERATED_DIR, "palette.rasi"),
        rofi_tokens,
    )
    user_rofi_colors = os.path.expanduser("~/.config/rofi/colors.rasi")
    if os.path.exists(os.path.dirname(user_rofi_colors)) and not os.path.islink(user_rofi_colors):
        try:
            write_file(user_rofi_colors, rofi_tokens)
        except OSError:
            pass

    # Foot
    foot_config = generate_foot_ini(theme)
    write_file(os.path.join(GENERATED_DIR, "foot.ini"), foot_config)
    write_file(
        os.path.join(DOTFILES_DIR, "foot", "colors.ini"),
        foot_config,
    )

    # Alacritty
    alacritty_config = generate_alacritty_toml(theme)
    write_file(os.path.join(GENERATED_DIR, "alacritty.toml"), alacritty_config)
    write_file(
        os.path.join(DOTFILES_DIR, "alacritty", "colors.toml"),
        alacritty_config,
    )
    user_alacritty_colors = os.path.expanduser("~/.config/alacritty/colors.toml")
    if os.path.exists(os.path.dirname(user_alacritty_colors)) and not os.path.islink(user_alacritty_colors):
        try:
            write_file(user_alacritty_colors, alacritty_config)
        except OSError:
            pass

    # Mako
    mako_config = generate_mako_conf(theme)
    write_file(MAKO_CONF, mako_config)
    write_file(
        os.path.join(GENERATED_DIR, "mako.conf"),
        mako_config,
    )

    # Shell environment and palette files
    write_file(
        os.path.join(GENERATED_DIR, "palette.env"),
        generate_shell_env(theme),
    )
    write_json(os.path.join(GENERATED_DIR, "palette.json"), theme)
    write_file(
        os.path.join(GENERATED_DIR, "palette.css"),
        generate_palette_css(theme),
    )

    # MangoBar
    mangobar_css = generate_mangobar_css(theme)
    write_file(MANGOBAR_STYLE_PATH, mangobar_css)
    write_file(
        os.path.join(GENERATED_DIR, "mangobar.css"),
        mangobar_css,
    )

    # Desktop configuration
    update_mango_conf(theme)
    update_gtk_theme(theme)
    update_papirus_icons(theme)
    update_gsettings(theme)
    update_thunar_xfconf()
    update_btop(theme)
    update_fastfetch(theme)

    # State tracking
    write_file(
        os.path.join(STATE_DIR, "current"),
        f"{theme_id}\n",
    )
    write_file(
        os.path.join(STATE_DIR, "current_mode"),
        f"{'dynamic' if theme_id == 'dynamic' else 'static'}\n",
    )

    # Wallpaper directory links
    update_wallpaper_links(theme_id)

    # Wallpaper switching
    if set_wallpaper:
        switch_wallpaper(theme_id, theme)

    # Terminal colors and live reload
    broadcast_term_colors(theme)
    reload_subsystems()

    # Notification
    theme_name = theme.get("name", theme_id)
    run_quiet(
        [
            "notify-send",
            "-h",
            "string:x-canonical-private-synchronous:wm-theme",
            "Theme Applied",
            f"Active desktop theme: {theme_name}",
        ]
    )

    print(f"Successfully applied theme: {theme_name} ({theme_id})")

def main():
    if len(sys.argv) < 2:
        print("Usage: theme-engine.py <theme_id> [--no-wallpaper]")
        sys.exit(1)

    theme_id = sys.argv[1].strip()
    set_wallpaper = "--no-wallpaper" not in sys.argv

    try:
        apply_theme(theme_id, set_wallpaper=set_wallpaper)
    except Exception as error:
        print(
            f"Error applying theme '{theme_id}': {error}",
            file=sys.stderr,
        )
        sys.exit(1)

if __name__ == "__main__":
    main()
