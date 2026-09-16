# Minimalist Void Linux Desktop Rice (MangoWC)

A custom, minimal, keyboard-first Wayland desktop environment for **Void Linux** built around **MangoWC**.

Designed by fusing the clean visual polish of **Omarchy 3** with the lightweight, utilitarian Rofi workflows of **Archcraft**, built natively for Void Linux and Wayland.

---

## 1. Overview & Architecture

- **Operating System**: [Void Linux](https://voidlinux.org) (glibc or musl)
- **Init & Service Manager**: `runit`
- **Login Manager (Recommended)**: [Ly](https://github.com/fairyglade/ly) (Nord TUI display manager)
- **Wayland Compositor**: [MangoWC](https://github.com/DreamMaoMao/mangowc) (wlroots 0.19 + scenefx tiling compositor)
- **Status Bar**: [Eww](https://github.com/elkowar/eww) (ElKowars wacky widgets - top bar, rounded corners, dynamic tray, and workspace indicators)
- **Menu & Launcher**: [Rofi](https://github.com/davatorium/rofi) (Wayland-native application launcher, powermenu, screenshot menu, theme & wallpaper switcher)
- **Primary Terminal**: [Foot](https://codeberg.org/dnkl/foot) (fast, Wayland-native)
- **Audio Stack**: [PipeWire](https://pipewire.org) + [WirePlumber](https://pipewire.pages.freedesktop.org/wireplumber/)
- **Networking**: [NetworkManager](https://networkmanager.dev) (`nmcli` + linktui interface)
- **Bluetooth**: [BlueZ](http://www.bluez.org) (`bluetoothctl` + linktui interface)
- **Notifications**: [Mako](https://github.com/emersion/mako)
- **Wallpapers**: [swaybg](https://github.com/swaywm/swaybg)
- **Theming**: Dynamic wallpaper-derived palette engine & 18 curated rice themes (Aline, Andrea, Brenda, etc.) + static palettes (Nord, Catppuccin, etc.)

---

## 2. Directory Structure

```text
~/wm/
├── install.sh                  # Root installer wrapper delegating to system/setup/install.sh
├── packages.void               # Backward-compatible symlink to packages/void
├── README.md                   # Documentation & keybindings cheatsheet
│
├── config/                     # Application configurations (symlinked to ~/.config/)
│   ├── mango/                  # MangoWC compositor configuration (config.conf)
│   ├── eww/                    # Eww status bar, widgets, and SCSS stylesheets
│   │   ├── widgets/            # Modular yuck widgets (bar, profilecard, player)
│   │   ├── styles/             # Modular SCSS stylesheets & theme tokens
│   │   ├── assets/             # Crisp vector SVG icons and graphics (0 PNGs)
│   │   ├── scripts/            # Polling and listener scripts (battery, volume, etc.)
│   │   ├── eww.yuck            # Master widget entrypoint
│   │   └── eww.scss            # Master stylesheet
│   ├── rofi/                   # Rofi Wayland menus, launcher, powermenu, screenshot
│   │   ├── styles/             # 17 presentation styles (style_1 .. style_17)
│   │   ├── assets/             # Vector preview assets & icons
│   │   ├── config.rasi         # Base configuration
│   │   └── shared.rasi         # Active theme palette tokens (auto-compiled)
│   ├── foot/                   # Foot terminal configuration (foot.ini, colors.ini)
│   ├── mako/                   # Mako notification daemon configuration
│   ├── gtk-3.0/                # GTK3/4 styles, theme.css, and settings.ini
│   ├── thunar/                 # Thunar file manager preferences (thunar.xml)
│   ├── btop/                   # btop system monitor configuration & themes
│   ├── fontconfig/             # Typography and font preferences (fonts.conf)
│   ├── fuzzel/                 # Fuzzel minimal fallback launcher configuration
│   └── ly/                     # Ly display manager configuration (config.ini)
│
├── themes/                     # Central theme architecture
│   ├── definitions/            # Curated JSON color palettes (Catppuccin, Nord, Tokyo Night, etc.)
│   ├── presets/                # 18 curated rice presets (aline .. z0mbi3)
│   │   └── <theme>/            # theme.conf, wallpapers/, preview.webp, overrides/
│   └── generated/              # Compiled runtime themes (palette.json, palette.css, foot.ini, etc.)
│
├── scripts/                    # Categorized Void-native utility scripts
│   ├── launcher/               # rofi-launcher, rofi-clipboard, rofi-calendar
│   ├── power/                  # rofi-powermenu, rofi-power-profile, battery-status
│   ├── screenshot/             # rofi-screenshot
│   ├── theme/                  # theme-engine.py, theme-switch, theme-select, theme-from-wallpaper
│   ├── wallpaper/              # wallpaper-manager, wallpaper-select, wallpaper-random
│   ├── media/                  # volume, brightness, rofi-audio, launch-audio
│   ├── network/                # rofi-wifi, rofi-bluetooth, launch-wifi, launch-bluetooth
│   ├── system/                 # start-mango, reload, backup, restore, fix-* scripts
│   └── diagnostics/            # wm-doctor
│
├── system/                     # System integration and setup
│   ├── services/               # mango.desktop, pipewire-launcher.sh, runit-setup.sh
│   └── setup/                  # install.sh (primary installer implementation)
│
├── packages/                   # Distribution package manifests
│   └── void                    # Minimal essential Void Linux XBPS packages
│
├── assets/                     # High-quality vector assets
│   ├── fonts/                  # Curated fonts (Maple Mono, Material Symbols, Nerd Fonts)
│   └── icons/                  # Crisp SVG action and notification icons (0 PNGs)
│
├── wallpapers/                 # Curated minimal wallpapers (and preset wallpapers)
└── state/                      # Runtime state tracking (current theme, mode, launcher style)
```

---

## 3. Installation

### Quick Start on Void Linux

```bash
git clone https://github.com/your-username/wm.git ~/wm
cd ~/wm
./install.sh
```

Or configure with flags (e.g. unattended mode, mirror selection, or Ly login manager):
```bash
./install.sh -y --login-manager ly
# Or launch xmirror to pick a regional/community mirror:
./install.sh --mirror

# Or run dedicated subsystem repair modules directly:
./install.sh --fix-audio
./install.sh --fix-dbus
./install.sh --fix-bluetooth
```

The installer will:
1. Verify that your system is Void Linux.
2. Ensure official Void extra repositories (`void-repo-nonfree`, `void-repo-multilib`, `void-repo-multilib-nonfree`) and `xmirror` are enabled, and sync XBPS indexes.
3. Accurately detect and install all missing packages from `packages.void` using `xbps-install`.
4. Enable essential `runit` services (`dbus`, `elogind`, `NetworkManager`, `bluetoothd`, `polkitd`) and disable conflicting daemons (`dhcpcd`, `wpa_supplicant`).
5. Add your user to hardware groups (`video`, `audio`, `input`, `network`, `bluetooth`).
6. Idempotently symlink configurations to `~/.config/` without generating redundant backups.
7. Install icon fonts to `~/.local/share/fonts/wm/` and update `fc-cache`.
8. Ensure Wayland session entry `/usr/share/wayland-sessions/mango.desktop` is present.
9. Link all desktop utility scripts and helpers into `/usr/local/bin/` and `~/.local/bin/`.
10. Optionally configure or compile Ly DM, create its runit service and PAM configuration, and resolve TTY2 conflicts.
11. Execute `scripts/wm-doctor` to verify your environment.

---

## 4. Login Manager & Session Startup

### Boot Flow
When a display manager is configured, you do **not** need to type `start-mango` manually after each boot:

```text
Boot
 └── runit initializes services (dbus, elogind, NetworkManager)
      └── Ly launches on TTY2
           └── Select "MangoWC" session (automatically saved after first login)
                └── Ly executes /usr/share/wayland-sessions/mango.desktop
                     └── scripts/start-mango sets Wayland environment
                          ├── MangoWC Compositor
                          ├── Waybar (Status Bar)
                          ├── Mako (Notifications)
                          ├── Swaybg (Nord Wallpaper)
                          └── PipeWire + WirePlumber (Audio stack)
```

### 1. Recommended: Ly (TUI Display Manager)
[Ly](https://github.com/fairyglade/ly) is the recommended display manager for this rice:
- Extremely lightweight (~2–4 MB RAM consumption, ncurses-like TUI).
- No heavy web engines or Qt/GTK dependencies.
- Beautifully styled with the repository's **Nord palette** (`bg = #2E3440`, `fg = #D8DEE9`, `border = #88C0D0`).
- Distraction-free (animations disabled, clean borders).
- Automatically saves and reloads your previous user and desktop session.

#### Automated Setup
```bash
cd ~/wm
./install.sh --login-manager ly
```

#### Manual Setup
1. **Build & Install Ly**:
   ```bash
   sudo xbps-install -Sy git zig pam-devel libxcb-devel make
   git clone --depth 1 https://github.com/fairyglade/ly.git
   cd ly
   zig build -Doptimize=ReleaseFast
   sudo zig build installnoconf -Dinit_system=runit -Doptimize=ReleaseFast
   ```
2. **Deploy Configuration & Session File**:
   ```bash
   sudo mkdir -p /etc/ly
   sudo cp ~/wm/config/ly/config.ini /etc/ly/config.ini
   # Deploy repository mango.desktop template (configured with dbus-run-session mangowc):
   sudo mkdir -p /usr/share/wayland-sessions
   sudo cp ~/wm/system/services/mango.desktop /usr/share/wayland-sessions/
   ```
3. **Enable Runit Service**:
   ```bash
   # Disable conflicting display managers
   sudo rm -f /var/service/sddm /var/service/lightdm /var/service/gdm /var/service/greetd
   # Disable getty on TTY2 to avoid conflict
   sudo rm -f /var/service/agetty-tty2
   # Enable Ly
   sudo ln -s /etc/sv/ly /var/service/
   ```
See [config/ly/README.md](file:///home/hj/wm/config/ly/README.md) for full details and source compilation instructions.

### 2. Alternative: SDDM (Graphical Display Manager)
If you prefer a full graphical login manager:
```bash
sudo xbps-install -Sy sddm
# Disable conflicting display managers first
sudo rm -f /var/service/ly /var/service/lightdm
sudo ln -s /etc/sv/sddm /var/service/
```
SDDM automatically detects MangoWC through the installed `/usr/share/wayland-sessions/mango.desktop`.

### 3. Manual TTY Fallback (`start-mango`)
A display manager is completely optional. You can always boot directly to a console TTY and launch the desktop manually:

```bash
start-mango
# or directly by path:
~/wm/scripts/start-mango
```

To automatically launch MangoWC upon logging in on `tty1`, append to `~/.bash_profile` or `~/.zprofile`:
```bash
if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
    exec start-mango
fi
```

### 4. Safe Rollback & Emergency Recovery
If a display manager fails to start or locks you out:
1. Press `Ctrl + Alt + F3` (or `F4` / `F5`) to switch to another console TTY.
2. Log in with your standard username and password.
3. Disable the display manager service immediately:
   ```bash
   sudo rm -f /var/service/ly /var/service/sddm
   ```
4. Restore the default console login on TTY2 (if needed):
   ```bash
   sudo ln -s /etc/sv/agetty-tty2 /var/service/
   ```
5. Launch MangoWC directly:
   ```bash
   start-mango
   ```

---

## 5. Keybindings Cheatsheet

All primary desktop shortcuts use the **Super** key:

| Shortcut | Action | Description |
| :--- | :--- | :--- |
| `Super + Return` | **Terminal** | Launches Foot terminal client |
| `Super + E` | **File Manager** | Launches Thunar file manager |
| `Super + W` | **Browser** | Launches Firefox browser |
| `Super + D` | **App Launcher** | Opens Rofi application launcher (`rofi-launcher`) |
| `Super + Space`| **App Launcher** | Alternative Rofi launcher shortcut |
| `Super + Q` | **Close Window** | Closes the focused application (`killclient`) |
| `Super + Escape` | **Power Menu** | Opens Rofi power menu (`rofi-powermenu`) |
| `Super + T` | **Theme Selector** | Interactive Rofi theme selector with previews |
| `Super + Ctrl + T` | **Dynamic Theme** | Regenerates theme palette from current wallpaper |
| `Super + Shift + W`| **Wallpaper Menu**| Interactive Rofi wallpaper picker & randomizer |
| `Super + S` | **Screenshot** | Opens Rofi screenshot menu (`rofi-screenshot`) |
| `Print` | **Screenshot** | Alternative screenshot menu shortcut |
| `Super + V` | **Clipboard** | Interactive Rofi clipboard history search (cliphist) |
| `Super + R` | **Reload Config** | Hot-reloads MangoWC configuration |
| `Super + F` | **Fullscreen** | Toggles fullscreen mode |
| `Super + C` | **Float Window** | Toggles window floating mode |
| `Super + O` | **Overlay** | Toggles overlay mode |
| `Super + Tab` | **Overview** | Toggles window overview |
| `Super + [1-9]` | **View Tag** | Switch to workspace/tag 1 through 9 |
| `Super + Shift + [1-9]` | **Move to Tag**| Moves active window to workspace 1 through 9 |
| `Super + Left/Right/Up/Down` | **Focus** | Move focus in directional layout |
| `Super + H/J/K/L` | **Focus** | Vim directional navigation |
| `Super + Shift + H/J/K/L` | **Move Window** | Swap window position in tiling tree |
| `Alt + Print` | **Window Snip** | Copies screenshot of focused window to clipboard |
| `XF86AudioRaiseVolume` | **Volume Up** | Increases volume (+5%) with OSD |
| `XF86AudioLowerVolume` | **Volume Down**| Decreases volume (-5%) with OSD |
| `XF86AudioMute` | **Mute Audio** | Toggles audio sink mute |
| `XF86AudioMicMute` | **Mute Mic** | Toggles microphone mute |
| `XF86MonBrightnessUp` | **Bright Up** | Increases backlight (+5%) with OSD |
| `XF86MonBrightnessDown` | **Bright Down**| Decreases backlight (-5%) with OSD |

---

## 6. Subsystem Details

### Wi-Fi (`Super + N`)
- Interactive NetworkManager frontend powered by `nmcli`.
- Discovers networks, visualizes signal strength bars, and prompts for WPA/WPA2 passwords cleanly without opening a terminal.
- Supports manual rescanning, disconnecting, and toggling Wi-Fi radio on/off.

### Bluetooth (`Super + B`)
- Interactive BlueZ frontend powered by `bluetoothctl`.
- Lists paired devices with connection state indicators.
- One-click device connection, pairing, removal, and 5-second device discovery scans.

### Audio (`Super + A`)
- Powered by native **PipeWire** and **WirePlumber** via `wpctl`.
- Switch output targets on the fly between Laptop Speakers, Headphones, Bluetooth headsets, and HDMI monitors.
- Inspect your audio configuration at any time using:
  ```bash
  ~/wm/scripts/audio-check
  ```

### Wallpapers (`Super + W`)
- Ultra-lightweight rendering via `swaybg`.
- Automatically extracts a matching color palette from the selected wallpaper and hot-reloads Waybar without flickering.
- Remembers your chosen wallpaper across reboots in `~/.cache/current_wallpaper`.
- Add your own `.jpg` or `.png` wallpapers to `~/wm/wallpapers/` or `~/Pictures/Wallpapers/`.
- Quickly randomize wallpapers using `wallpaper-manager random`.

### Screenshots (`Super + S`)
- Powered by `grim`, `slurp`, and `wl-clipboard`.
- Supports selecting a bounding box, full-screen capture, or capturing the focused client geometry reported by MangoWC's `mmsg`.
- Automatically saves images to `~/Pictures/Screenshots/` and copies the buffer directly to your clipboard.

---

## 7. Troubleshooting & Diagnostics

### System Health Check (`wm-doctor`)
Run the built-in diagnostic tool to test your environment:

```bash
wm-doctor
# or directly:
~/wm/scripts/wm-doctor
```

It validates:
- Void Linux distribution markers and XBPS availability.
- MangoWC binary, session script, and Wayland session entry (`mango.desktop`).
- Core UI tools (`waybar`, `rofi`, `foot`, `mako`, `libnotify`).
- PipeWire and WirePlumber daemons and sockets.
- NetworkManager and BlueZ services.
- `dbus`, `elogind`, and `polkitd` system services.
- Group permissions (`video`, `audio`, `input`).
- Typography and icon fonts.
- Login manager status (Ly) and detects conflicting multiple display managers.

### One-Click Subsystem Fixers

If you encounter issues with audio, DBus, or Bluetooth, dedicated fix modules are available directly or via `install.sh`:

```bash
# Audio: Install packages, configure ALSA PipeWire routing, add audio group, clean sockets, restart daemons:
./install.sh --fix-audio       # or directly: ~/wm/scripts/fix-audio

# DBus: Install dbus, ensure machine-id, enable & restart runit service, verify session bus:
./install.sh --fix-dbus        # or directly: ~/wm/scripts/fix-dbus

# Bluetooth: Install bluez, enable runit service, configure AutoEnable, add bluetooth group, unblock rfkill:
./install.sh --fix-bluetooth   # or directly: ~/wm/scripts/fix-bluetooth
```

### Audio Stack Troubleshooting
If you encounter no sound or missing devices:
```bash
~/wm/scripts/audio-check
```
Ensure user is in the `audio` group (`sudo usermod -aG audio $USER`) and PipeWire session daemons are active (`~/wm/services/pipewire-launcher.sh`).

### Backlight Control
If `brightnessctl` reports permission denied:
```bash
sudo usermod -aG video $USER
```
Log out and log back in to apply group changes.

---

## 8. Backup Restoration & Uninstall

If you ever wish to restore your previous configurations:
```bash
# Locate your backup folder
ls -d ~/.config/wm-backups-*

# Remove rice symlinks
rm -f ~/.config/mango ~/.config/eww ~/.config/fuzzel ~/.config/foot ~/.config/mako ~/.config/wm

# Restore backed-up directories
cp -r ~/.config/wm-backups-<timestamp>/* ~/.config/
```

---

## 9. Upstream Project References

- **MangoWC**: [https://github.com/DreamMaoMao/mangowc](https://github.com/DreamMaoMao/mangowc)
- **Eww**: [https://github.com/elkowar/eww](https://github.com/elkowar/eww)
- **Fuzzel**: [https://codeberg.org/dnkl/fuzzel](https://codeberg.org/dnkl/fuzzel)
- **Ly**: [https://github.com/fairyglade/ly](https://github.com/fairyglade/ly)
- **Foot**: [https://codeberg.org/dnkl/foot](https://codeberg.org/dnkl/foot)
- **PipeWire**: [https://pipewire.org](https://pipewire.org)
- **WirePlumber**: [https://pipewire.pages.freedesktop.org/wireplumber](https://pipewire.pages.freedesktop.org/wireplumber)
- **NetworkManager**: [https://networkmanager.dev](https://networkmanager.dev)
- **BlueZ**: [http://www.bluez.org](http://www.bluez.org)
- **Mako**: [https://github.com/emersion/mako](https://github.com/emersion/mako)
- **swaybg**: [https://github.com/swaywm/swaybg](https://github.com/swaywm/swaybg)
- **grim**: [https://git.sr.ht/~emersion/grim](https://git.sr.ht/~emersion/grim)
- **slurp**: [https://git.sr.ht/~emersion/slurp](https://git.sr.ht/~emersion/slurp)
- **Void Linux**: [https://voidlinux.org](https://voidlinux.org)
