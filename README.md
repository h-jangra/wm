# Minimalist Void Linux Desktop Rice (MangoWC)

A custom, minimal, keyboard-first Wayland desktop environment for **Void Linux** built around **MangoWC**.

Designed by fusing the clean visual polish of **Omarchy 3** with the lightweight, utilitarian Rofi workflows of **Archcraft**, built natively for Void Linux and Wayland.

---

## 1. Overview & Architecture

- **Operating System**: [Void Linux](https://voidlinux.org) (glibc or musl)
- **Init & Service Manager**: `runit`
- **Login Manager (Recommended)**: [Ly](https://github.com/fairyglade/ly) (Nord TUI display manager)
- **Wayland Compositor**: [MangoWC](https://github.com/DreamMaoMao/mangowc) (wlroots 0.19 + scenefx tiling compositor)
- **Status Bar**: [Waybar](https://github.com/Alexays/Waybar) (Noctalia-inspired pill/capsule aesthetics with dynamic wallpaper-driven palette)
- **Menu & Launcher**: [Rofi](https://github.com/davatorium/rofi) / [Rofi-Wayland](https://github.com/lbonn/rofi)
- **Primary Terminal**: [Foot](https://codeberg.org/dnkl/foot) (fast, Wayland-native)
- **Audio Stack**: [PipeWire](https://pipewire.org) + [WirePlumber](https://pipewire.pages.freedesktop.org/wireplumber/)
- **Networking**: [NetworkManager](https://networkmanager.dev) (`nmcli` + Rofi interface)
- **Bluetooth**: [BlueZ](http://www.bluez.org) (`bluetoothctl` + Rofi interface)
- **Notifications**: [Mako](https://github.com/emersion/mako)
- **Wallpapers**: [swaybg](https://github.com/swaywm/swaybg)
- **Colorway**: Restrained [Nord](https://www.nordtheme.com) palette & dynamic wallpaper-derived color harmony

---

## 2. Directory Structure

```text
~/wm/
├── install.sh                  # Automated installer & symlinker for Void Linux
├── packages.void               # 24 essential Void Linux XBPS packages
├── README.md                   # Documentation & keybindings cheatsheet
│
├── ly/                         # Optional Ly display manager configuration
│   ├── config.ini              # Minimal Nord theme (zero animations, saved session)
│   └── README.md               # Build, service setup, theming, and recovery docs
├── mango/                      # MangoWC configuration
│   └── config.conf             # Gaps, borders, animations, tags 1-9, window rules, bindings
├── waybar/                     # Noctalia-inspired Waybar layout
│   ├── config.jsonc            # Left (clock, ram, keyviz, recorder), Center (workspaces), Right (tray, bt, net, vol, bat, session)
│   └── style.css               # Borderless 4px capsules, 3px spacing, transparent background, dynamic palette tokens
├── rofi/                       # Polished keyboard-first Rofi menus
│   ├── config.rasi             # Base Rofi setup & shared typography
│   ├── theme.rasi              # Central Nord color tokens imported by all menus
│   ├── launcher.rasi           # Application launcher modal
│   ├── power.rasi              # Power options modal
│   ├── wifi.rasi               # Interactive NetworkManager Wi-Fi selector
│   ├── bluetooth.rasi          # Interactive BlueZ device manager
│   ├── audio.rasi              # PipeWire sink/source selector & volume controller
│   ├── wallpaper.rasi          # Interactive wallpaper picker
│   ├── screenshot.rasi         # Region, screen, and window screenshot actions
│   └── clipboard.rasi          # Clipboard history search modal
├── terminal/                   # Primary terminal setup
│   └── foot/
│       └── foot.ini            # Server-mode config, JetBrainsMono font, Nord palette
├── scripts/                    # Shared Void-native desktop utility scripts
│   ├── generate-palette        # Dynamic palette extractor from wallpaper
│   ├── start-mango             # Session launcher exporting Wayland, DBus, GTK/Qt env vars
│   ├── rofi-launcher           # App launcher execution wrapper
│   ├── rofi-powermenu          # Void power manager using elogind / zzz / shutdown fallbacks
│   ├── rofi-wifi               # NetworkManager nmcli frontend with password prompts
│   ├── rofi-bluetooth          # BlueZ bluetoothctl frontend with scan, pair, connect
│   ├── rofi-audio              # PipeWire / wpctl sink and source switching frontend
│   ├── rofi-wallpaper          # Interactive wallpaper selector with live apply
│   ├── rofi-screenshot         # Wayland screenshot utility (grim + slurp + wl-copy)
│   ├── rofi-clipboard          # Clipboard manager using cliphist + wl-paste
│   ├── volume                  # Hardware volume key handler with OSD notifications
│   ├── brightness              # Hardware brightness handler (brightnessctl) with OSD notifications
│   ├── wallpaper-manager       # Lightweight swaybg manager with auto palette update and Waybar reload
│   ├── audio-check             # PipeWire & WirePlumber verification and troubleshooting tool
│   ├── fix-audio               # One-click diagnostic & repair tool for PipeWire, ALSA, and user groups
│   ├── fix-dbus                # One-click diagnostic & repair tool for DBus system service & machine-id
│   ├── fix-bluetooth           # One-click diagnostic & repair tool for BlueZ daemon, group & rfkill
│   ├── mango-tags-waybar       # Waybar JSON tag stream from MangoWC mmsg (compact Noctalia pills)
│   ├── mango-window-waybar     # Waybar JSON active window title stream from mmsg
│   └── wm-doctor               # Full system diagnostic health checker
├── services/                   # Void Linux runit & session supervisors
│   ├── mango.desktop           # Freedesktop Wayland session entry
│   ├── runit-setup.sh          # Script to enable required Void runit services in /var/service
│   └── pipewire-launcher.sh    # Session-level supervisor for PipeWire, WirePlumber, PulseAudio
├── themes/                     # Theme tokens & dynamic wallpaper integration
│   ├── palette.css             # Dynamic wallpaper tokens for Waybar & GTK
│   ├── palette.json            # Dynamic workspace pill colors
│   ├── palette.env             # Dynamic shell environment variables
│   ├── palette.rasi            # Dynamic Rofi color tokens
│   ├── nord.env                # Base Nord environment tokens
│   ├── nord.css                # Base Nord CSS variables
│   └── nord.rasi               # Base Nord Rofi variables
├── wallpapers/                 # Curated high-definition minimal wallpapers
├── fonts/                      # Curated open-source icon fonts
└── assets/icons/               # Notification and action icons
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
   sudo cp ~/wm/ly/config.ini /etc/ly/config.ini
   # Deploy repository mango.desktop template (configured with dbus-run-session mangowc):
   sudo mkdir -p /usr/share/wayland-sessions
   sudo cp ~/wm/services/mango.desktop /usr/share/wayland-sessions/
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
See [ly/README.md](file:///home/hj/wm/ly/README.md) for full details and source compilation instructions.

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
| `Super + Return` | **Terminal** | Launches Foot terminal |
| `Super + E` | **File Manager** | Launches Thunar file manager |
| `Super + D` | **App Launcher** | Opens Rofi application launcher |
| `Super + Space`| **App Launcher** | Alternative launcher shortcut |
| `Super + Q` | **Close Window** | Closes the focused application (`killclient`) |
| `Super + X` | **Power Menu** | Lock, Logout, Suspend, Reboot, Shutdown |
| `Super + W` | **Wallpaper Menu**| Interactive wallpaper picker & randomizer |
| `Super + N` | **Wi-Fi Menu** | Interactive NetworkManager Wi-Fi manager |
| `Super + B` | **Bluetooth Menu**| Interactive BlueZ device pairing & manager |
| `Super + A` | **Audio Menu** | Switch audio outputs (speakers/headphones/HDMI) |
| `Super + S` | **Screenshot** | Region, full screen, or active window capture |
| `Super + V` | **Clipboard** | Clipboard history search & copy |
| `Super + R` | **Reload Config** | Hot-reloads MangoWC configuration |
| `Super + F` | **Fullscreen** | Toggles fullscreen mode |
| `Super + C` | **Float Window** | Toggles window floating mode |
| `Super + [1-9]` | **View Tag** | Switch to workspace/tag 1 through 9 |
| `Super + Shift + [1-9]` | **Move to Tag**| Moves active window to workspace 1 through 9 |
| `Super + Left/Right/Up/Down` | **Focus** | Move focus in directional layout |
| `Super + H/J/K/L` | **Focus** | Vim directional navigation |
| `Super + Shift + H/J/K/L` | **Move Window** | Swap window position in tiling tree |
| `Print` | **Screenshot** | Opens screenshot action menu |
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
rm ~/.config/mango ~/.config/waybar ~/.config/rofi ~/.config/foot ~/.config/mako ~/.config/wm

# Restore backed-up directories
cp -r ~/.config/wm-backups-<timestamp>/* ~/.config/
```

---

## 9. Upstream Project References

- **MangoWC**: [https://github.com/DreamMaoMao/mangowc](https://github.com/DreamMaoMao/mangowc)
- **Ly**: [https://github.com/fairyglade/ly](https://github.com/fairyglade/ly)
- **Omarchy**: [https://github.com/omacom/omarchy](https://github.com/omacom/omarchy)
- **Waybar**: [https://github.com/Alexays/Waybar](https://github.com/Alexays/Waybar)
- **Rofi**: [https://github.com/davatorium/rofi](https://github.com/davatorium/rofi)
- **Rofi-Wayland**: [https://github.com/lbonn/rofi](https://github.com/lbonn/rofi)
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
