# Minimalist Void Linux Desktop Rice (MangoWC)

A clean, modular, keyboard-driven Wayland desktop environment for **Void Linux** built around **MangoWC**.

Designed by fusing the visual polish of modern minimal rice aesthetics with the lightweight, utilitarian modularity of standalone components, tailored natively for Void Linux, runit, and Wayland.

---

## 1. Architecture & Core Components

| Component | Upstream / Technology | Purpose |
| :--- | :--- | :--- |
| **Operating System** | [Void Linux](https://voidlinux.org) (glibc & musl) | Rolling-release, systemd-free Linux distribution |
| **Init & Services** | `runit` | Fast, lightweight UNIX init and service supervision |
| **Login Manager** | [Ly](https://github.com/fairyglade/ly) | Minimalist TUI display manager running on TTY2 |
| **Compositor** | [MangoWC](https://github.com/DreamMaoMao/mangowc) | High-performance wlroots + scenefx tiling Wayland compositor |
| **Primary Status Bar**| [MangoBar](https://github.com/mangowm/mangobar) | Native MangoWC status bar with modular popups and system stats |
| **Widget Engine** | [Eww](https://github.com/elkowar/eww) | Standalone dashboard, media player, profile card, and OSD widgets |
| **Application Launcher**| [Rofi-Wayland](https://github.com/davatorium/rofi) | Standalone modal menus for apps, clipboard, power, audio, wifi, etc. |
| **Terminal** | [Foot](https://codeberg.org/dnkl/foot) | Fast, lightweight, Wayland-native terminal emulator |
| **Notifications** | [Mako](https://github.com/emersion/mako) | Wayland notification daemon styled dynamically to active theme |
| **File Manager** | [Thunar](https://docs.xfce.org/xfce/thunar/start) | Fast XFCE file manager with custom actions and dark GTK theme |
| **Audio Stack** | [PipeWire](https://pipewire.org) + [WirePlumber](https://pipewire.pages.freedesktop.org/wireplumber/) | Low-latency audio server and session manager via `wpctl` |
| **Network & Bluetooth**| NetworkManager & BlueZ | Robust connectivity managed via standalone Rofi interfaces |
| **Wallpapers** | [swaybg](https://github.com/swaywm/swaybg) | Minimalist Wayland wallpaper renderer |
| **Theming Engine** | Python 3 + pywal16 | Dynamic wallpaper palette extraction & 8 curated presets |

---

## 2. Directory Structure

The repository is organized into five clean, modular namespaces:

```text
~/wm/
├── install.sh                  # Root installer wrapper delegating to system/setup/install.sh
├── packages.void               # Comprehensive Void Linux XBPS package manifest
├── README.md                   # Complete architectural guide, manual, and cheatsheet
│
├── components/                 # Standalone, reusable desktop UI components
│   ├── mangobar/               # Native MangoWC status bar configuration, styles & helpers
│   │   ├── config.jsonc        # Bar layout and module definitions
│   │   ├── style.css           # Base GTK stylesheet
│   │   ├── theme.css           # Active theme color tokens (auto-generated)
│   │   └── scripts/            # Helper scripts (volume, brightness, battery, etc.)
│   │
│   ├── rofi/                   # Modular Rofi menus (standalone per-feature directories)
│   │   ├── launcher/           # Application launcher (launcher.sh, style_1..3)
│   │   ├── calendar/           # Interactive month calendar with event indicators
│   │   ├── clipboard/          # Clipboard history search & manager (cliphist)
│   │   ├── powermenu/          # Void Linux runit power options (lock, suspend, reboot, off)
│   │   ├── network/            # Wi-Fi (nmcli) & Bluetooth (bluetoothctl) managers
│   │   ├── audio/              # PipeWire audio output/sink switcher & volume
│   │   ├── screenshot/         # Grim/slurp screen snip, window snip, and full capture
│   │   ├── wallpaper/          # Wallpaper selector and randomizer
│   │   ├── theme-selector/     # Visual theme switcher with live reload
│   │   ├── config.rasi         # Global rofi configuration
│   │   ├── shared.rasi         # Dynamic font & layout definitions
│   │   └── theme.rasi          # Active color variables (symlinked/compiled)
│   │
│   ├── eww/                    # ElKowar's Wacky Widgets dashboard & control center
│   │   ├── widgets/            # Yuck widget modules (bar, player, profilecard)
│   │   ├── styles/             # Modular SCSS styling & color imports
│   │   ├── assets/             # Crisp vector SVG icons
│   │   ├── scripts/            # Polling daemons (battery, game-mode, workspaces)
│   │   ├── eww.yuck            # Master widget layout
│   │   └── eww.scss            # Master SCSS stylesheet
│   │
│   ├── wallpaper/              # Wallpaper daemon and switching utilities
│   │   ├── wallpaper-manager   # Backend daemon controlling swaybg & palette sync
│   │   ├── wallpaper-select    # CLI/menu selector
│   │   ├── wallpaper-random    # Randomize wallpaper from active preset or directory
│   │   └── wallpaper-switch    # Apply specific wallpaper path
│   │
│   └── themes/                 # Universal theming engine & presets
│       ├── definitions/        # Curated JSON color schemes (catppuccin, nord, gruvbox, etc.)
│       ├── presets/            # Curated rice presets with bundled wallpapers
│       │   ├── catppuccin-mocha/
│       │   ├── everforest/
│       │   ├── gruvbox-dark/
│       │   ├── kanagawa/
│       │   ├── matte-black/
│       │   ├── nord/
│       │   ├── rose-pine/
│       │   └── tokyo-night/
│       ├── generated/          # Auto-generated runtime theme files (gitignored)
│       ├── theme-engine.py     # Central cross-desktop compiler (Mango, Bar, Foot, Rofi, Mako)
│       ├── theme-switch        # CLI wrapper to apply preset
│       ├── theme-from-wallpaper# Dynamic pywal16 extractor from arbitrary images
│       └── generate-palette    # Shell helper generating palette tokens
│
├── dotfiles/                   # Standard user dotfiles (symlinked directly to ~/.config/)
│   ├── mango/                  # MangoWC compositor config (config.conf)
│   ├── foot/                   # Foot terminal configuration (foot.ini, colors.ini)
│   ├── mako/                   # Mako notification daemon configuration (config)
│   ├── gtk-3.0/                # GTK3/4 styles (gtk.css, settings.ini)
│   ├── thunar/                 # Thunar file manager settings (thunar.xml, uca.xml)
│   ├── btop/                   # btop system monitor configuration & themes
│   └── fontconfig/             # Typography and font preferences (fonts.conf)
│
├── assets/                     # High-quality vector assets and typography
│   ├── fonts/                  # Bundled icon & monospace fonts (Maple Mono, Material Symbols)
│   └── icons/                  # Scalable vector graphics (SVG)
│
└── system/                     # System services, installation, scripts & diagnostics
    ├── services/               # Runit services, Wayland desktop session, Ly config
    │   ├── mango.desktop       # Wayland session descriptor (/usr/share/wayland-sessions/)
    │   ├── pipewire-launcher.sh# User-session PipeWire/WirePlumber starter
    │   ├── runit-setup.sh      # Service enablement helper for Void runit
    │   └── ly/config.ini       # Ly display manager minimal configuration
    ├── setup/
    │   └── install.sh          # Idempotent master installer implementation
    ├── diagnostics/
    │   └── wm-doctor           # Comprehensive 34-point system health check
    └── scripts/                # System management utilities
        ├── start-mango         # Wayland session launcher & environment setup
        ├── reload              # Live hot-reloader for all desktop components
        ├── backup              # Idempotent user configuration backup tool
        ├── restore             # Rollback utility restoring previous configurations
        ├── audio-check         # Diagnostic tool for PipeWire sinks and sources
        ├── fix-audio           # Automated repair script for PipeWire/ALSA stack
        ├── fix-bluetooth       # Automated repair script for BlueZ / rfkill
        └── fix-dbus            # Automated repair script for system & session DBus
```

---

## 3. Component Independence & Modularity

Each component in `components/` and `dotfiles/` is engineered to be **self-contained**:
- **Independent Usage**: You can extract and copy `components/rofi/`, `components/mangobar/`, or `components/eww/` to any Linux system running Wayland and use it without needing the rest of the repository.
- **Relative Path Resolution**: All scripts calculate their own location dynamically via `BASH_SOURCE` and `dirname`, freeing them from hardcoded paths like `/home/hj/wm` or `~/wm`.
- **Runtime State Decoupling**: All mutable state (such as the active theme name, mode, and launcher style) is stored outside the Git repository in `${XDG_STATE_HOME:-$HOME/.local/state}/wm` and `${XDG_CACHE_HOME:-$HOME/.cache}/wm`. The Git working tree remains permanently clean.
- **Self-Contained Rofi Menus**: Every feature inside `components/rofi/<feature>/` includes relative style links to parent tokens, allowing both modular invocation (`bash components/rofi/powermenu/powermenu.sh`) and system-wide execution (`rofi-powermenu`).

---

## 4. Installation Guide

### Quick Start on Void Linux

Clone the repository and run the installer:

```bash
git clone https://github.com/h-jangra/wm.git ~/wm
cd ~/wm
./install.sh
```

### Installation Options & CLI Flags

The installer is completely idempotent and safe to run multiple times. Supported flags include:

```bash
# Non-interactive installation (answers yes to prompts):
./install.sh -y

# Configure Ly as the default login manager on TTY2:
./install.sh --login-manager ly

# Interactively select an official XBPS mirror with xmirror:
./install.sh --mirror

# Force compilation of MangoBar from source via meson:
./install.sh --build-mangobar

# Force compilation of Ly display manager from source:
./install.sh --build-ly

# Skip extra repositories (nonfree and multilib):
./install.sh --no-extra-repos

# Run targeted system repair modules directly:
./install.sh --fix-audio
./install.sh --fix-dbus
./install.sh --fix-bluetooth
```

### What the Installer Does

1. **OS Detection**: Validates that the system is running Void Linux.
2. **Repository Setup**: Enables official Void Linux `nonfree` and `multilib` repositories and syncs XBPS repository indexes.
3. **Package Installation**: Audits installed packages against `packages.void` and installs any missing utilities via `xbps-install`.
4. **MangoBar Check**: Verifies if `mangobar` is available; builds it from upstream source if absent.
5. **Runit Services**: Enables required system services (`dbus`, `elogind`, `NetworkManager`, `bluetoothd`, `polkitd`) and disables conflicting network daemons (`dhcpcd`, `wpa_supplicant`).
6. **User Permissions**: Adds your user to essential hardware groups: `video`, `audio`, `input`, `network`, `bluetooth`.
7. **Idempotent Symlinking**: Symlinks `dotfiles/*` and `components/*` cleanly to `~/.config/`, safely backing up any conflicting user files to `~/.config/wm-backups-<timestamp>/`.
8. **Font Installation**: Installs bundled typography and icon fonts to `~/.local/share/fonts/wm/` and triggers `fc-cache`.
9. **Desktop Binaries**: Symlinks all component scripts and helpers into `~/.local/bin/` and `/usr/local/bin/` for instant access.
10. **Session Entry**: Installs `/usr/share/wayland-sessions/mango.desktop` configured with `dbus-run-session mangowc`.
11. **Initial Theme**: Compiles the default Catppuccin-Mocha theme palette and initializes `${XDG_STATE_HOME:-$HOME/.local/state}/wm`.
12. **Verification**: Executes `wm-doctor` to run a 34-point sanity check on the environment.

---

## 5. Starting the Session

### Option 1: Via Login Manager (Ly - Recommended)
If configured during installation, your machine boots directly into Ly on TTY2. Select the **MangoWC** session to start the desktop.

### Option 2: Manual Console Launch (`start-mango`)
If booting to a standard console TTY, simply run:
```bash
start-mango
```

To automatically start MangoWC upon login on `tty1`, add the following to `~/.bash_profile` or `~/.zprofile`:
```bash
if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
    exec start-mango
fi
```

---

## 6. Keybindings Cheatsheet

All primary shortcuts use the **Super** (Windows) key:

| Shortcut | Action | Command / Target |
| :--- | :--- | :--- |
| `Super + Return` | **Terminal** | `footclient` (spawns new client connected to foot server) |
| `Super + E` | **File Manager** | `thunar` |
| `Super + W` | **Web Browser** | `firefox` |
| `Super + D` or `Super + Space` | **App Launcher** | `rofi-launcher` |
| `Super + Q` | **Close Window** | Closes focused client (`killclient`) |
| `Super + Escape` | **Power Menu** | `rofi-powermenu` (Lock, Suspend, Reboot, Shutdown) |
| `Super + T` | **Theme Selector** | `theme-select` (Interactive Rofi theme switcher) |
| `Super + Ctrl + T` | **Theme from Wallpaper**| `theme-from-wallpaper` (Extracts palette via pywal16) |
| `Super + Shift + W` | **Wallpaper Menu** | `wallpaper-select` (Interactive Rofi wallpaper browser) |
| `Super + S` or `Print` | **Screenshot Menu** | `rofi-screenshot` (Selection, window snip, or display) |
| `Super + V` | **Clipboard Menu** | `clipboard-menu` (Search cliphist clipboard history) |
| `Super + R` | **Reload Config** | Hot-reloads MangoWC configuration and theme tokens |
| `Super + F` | **Maximize Screen** | `togglemaximizescreen` |
| `Super + Shift + F` | **Fullscreen** | `togglefullscreen` |
| `Super + C` | **Floating Toggle** | `togglefloating` |
| `Super + O` | **Overlay Mode** | `toggleoverlay` |
| `Super + Tab` | **Overview Mode** | `toggleoverview` |
| `Super + L` | **Lock Screen** | `swaylock -c 000000` |
| `Super + [1-9]` | **Workspace 1-9** | Switch active tag / workspace |
| `Super + Shift + [1-9]` | **Move Window 1-9** | Move focused window to tag / workspace |
| `Super + H/J/K/L` | **Focus Navigation** | Focus left, down, up, right (Vim keys) |
| `Super + Arrow Keys` | **Focus Navigation** | Focus left, down, up, right |
| `Super + Shift + H/J/K/L` | **Move Window** | Swap window position in tiling tree |
| `Super + Ctrl + Arrow Keys`| **Resize Window** | Resize active tiled window |
| `Alt + Print` | **Active Window Snip** | Snips focused window and copies to clipboard |
| `XF86AudioRaiseVolume` | **Volume Up** | Raises audio volume (+5%) with OSD feedback |
| `XF86AudioLowerVolume` | **Volume Down** | Lowers audio volume (-5%) with OSD feedback |
| `XF86AudioMute` | **Mute Output** | Toggles audio sink mute |
| `XF86AudioMicMute` | **Mute Mic** | Toggles microphone source mute |
| `XF86MonBrightnessUp` | **Brightness Up** | Raises display backlight (+5%) with OSD feedback |
| `XF86MonBrightnessDown` | **Brightness Down** | Lowers display backlight (-5%) with OSD feedback |

---

## 7. Theming & Customization

The rice features a centralized, cross-desktop theming engine located at `components/themes/theme-engine.py`.

### Bundled Presets
- **Catppuccin Mocha** (`catppuccin-mocha`)
- **Nord** (`nord`)
- **Gruvbox Dark** (`gruvbox-dark`)
- **Everforest** (`everforest`)
- **Tokyo Night** (`tokyo-night`)
- **Rose Pine** (`rose-pine`)
- **Kanagawa** (`kanagawa`)
- **Matte Black** (`matte-black`)

### Switching Themes via CLI
To switch themes from the command line:
```bash
# Switch to a preset theme:
theme-switch nord
theme-switch catppuccin-mocha

# Or invoke the compiler directly:
python3 components/themes/theme-engine.py everforest
```

### Dynamic Theming from Any Wallpaper
Extract a cohesive color palette from any image on your system:
```bash
# Automatically extract palette, set wallpaper, and re-theme desktop:
theme-from-wallpaper ~/Pictures/Wallpapers/my_wallpaper.jpg

# Or press Super + Ctrl + T inside the desktop
```

### What Theme Engine Updates
When a theme or wallpaper is applied, `theme-engine.py` atomically compiles and reloads:
1. **MangoWC**: Window borders, accent colors, and tag indicators (`dotfiles/mango/config.conf`).
2. **MangoBar**: CSS color tokens (`components/mangobar/theme.css`).
3. **Rofi**: Active color definitions (`components/rofi/colors.rasi`).
4. **Foot**: Terminal 16-color palette and background (`dotfiles/foot/colors.ini`).
5. **Mako**: Notification borders, background, and text colors.
6. **Eww**: SCSS color tokens (`components/eww/styles/_colors.scss`).
7. **btop**: System monitor color scheme.
8. **swaybg**: Wallpaper rendering.

---

## 8. System Diagnostics & Subsystem Repair

### Diagnostics (`wm-doctor`)
A comprehensive diagnostic utility is available to verify all system services, hardware groups, daemons, and dependencies:

```bash
wm-doctor
# or run directly:
bash system/diagnostics/wm-doctor
```

### Subsystem Repair Scripts

If an individual subsystem experiences issues, automated fix scripts resolve them:

```bash
# PipeWire / WirePlumber Audio Stack
# Verifies ALSA routing, cleans stale runtime sockets, configures permissions, restarts daemons:
fix-audio

# DBus System & Session Bus
# Ensures /var/lib/dbus/machine-id, restarts runit service, checks session bus socket:
fix-dbus

# Bluetooth Daemon & Hardware
# Enables bluetoothd service, enables AutoEnable in /etc/bluetooth/main.conf, unblocks rfkill:
fix-bluetooth
```

---

## 9. Backup, Restoration & Uninstall

### Creating a Manual Backup
```bash
backup
# Configurations are safely archived into ~/.config/wm-backups-<timestamp>/
```

### Restoring Configurations
```bash
restore
# Follow interactive prompts to restore an earlier snapshot
```

### Removing the Rice
```bash
# Remove symlinks
rm -f ~/.config/{mango,mangobar,rofi,eww,foot,mako,Thunar,gtk-3.0,btop,fontconfig,themes,wm}

# Restore your original backup
cp -r ~/.config/wm-backups-<timestamp>/* ~/.config/
```

---

## 10. Upstream Projects & Credits

- [MangoWC](https://github.com/DreamMaoMao/mangowc) - Lightweight wlroots + scenefx Wayland compositor
- [MangoBar](https://github.com/mangowm/mangobar) - Status bar for MangoWC
- [Eww](https://github.com/elkowar/eww) - ElKowar's Wacky Widgets
- [Rofi-Wayland](https://github.com/davatorium/rofi) - Application launcher and menu provider
- [Foot](https://codeberg.org/dnkl/foot) - Fast, lightweight Wayland terminal emulator
- [Ly](https://github.com/fairyglade/ly) - Minimalist TUI display manager
- [PipeWire](https://pipewire.org) & [WirePlumber](https://pipewire.pages.freedesktop.org/wireplumber/) - Linux multimedia framework
- [pywal16](https://github.com/eylles/pywal16) - 16-color palette generator
- [Void Linux](https://voidlinux.org) - The independent Linux distribution
