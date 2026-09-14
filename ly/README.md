# Ly Login Manager for Void Linux × MangoWC

This directory provides a cohesive, lightweight [Ly](https://github.com/fairyglade/ly) configuration styled to match the Nord desktop rice.

Ly is a lightweight, ncurses-style terminal user interface (TUI) display manager. It consumes approximately 2–4 MB of RAM, requires zero heavy browser or GUI dependencies (such as Qt or WebKit), and integrates directly with Void Linux's `runit` init system.

---

## Boot Flow

Once Ly is enabled, the system boots directly to the login screen without requiring manual terminal commands:

```text
Boot
 └── runit initializes services (dbus, elogind, NetworkManager)
      └── Ly launches on TTY2
           └── Select "MangoWC" session (auto-remembered after first login)
                └── Ly executes /usr/share/wayland-sessions/mango.desktop
                     └── scripts/start-mango sets Wayland environment
                          ├── MangoWC Compositor
                          ├── Waybar (Status Bar)
                          ├── Mako (Notifications)
                          ├── Swaybg (Nord Wallpaper)
                          └── PipeWire + WirePlumber (Audio stack)
```

---

## Installation on Void Linux

Ly is an **optional** component and is not bundled in `packages.void` to ensure the core rice remains self-contained and runnable from a pure TTY.

### Method 1: Check Pre-built Binary Repository
Check if `ly` is available in your active XBPS mirrors:
```bash
xbps-query -Rs ly
```
If available, install it directly:
```bash
sudo xbps-install -Sy ly
```

### Method 2: Build via `void-packages` (Recommended)
If using the Void source packages collection:
```bash
git clone --depth=1 https://github.com/void-linux/void-packages.git
cd void-packages
./xbps-src binary-bootstrap
./xbps-src pkg ly
sudo xbps-install --repository hostdir/binpkgs ly
```

### Method 3: Build from Source
To build the modern Zig-based or C-based version of Ly directly:
```bash
# Install build prerequisites
sudo xbps-install -Sy git zig libxcb-devel pam-devel

# Clone and compile
git clone --recurse-submodules https://github.com/fairyglade/ly.git
cd ly
zig build
sudo zig build install
```

---

## Automated Setup via Installer

The repository installer provides a dedicated flag to deploy the Ly configuration and session entry:

```bash
cd ~/wm
./install.sh --login-manager ly
```

This automated step:
1. Verifies that `ly` is installed on your system.
2. Creates a timestamped backup of any existing `/etc/ly/config.ini` (e.g., `/etc/ly/config.ini.bak.<timestamp>`).
3. Installs `ly/config.ini` to `/etc/ly/config.ini`.
4. Verifies `/usr/share/wayland-sessions/mango.desktop` is present (created automatically when installing `mangowc`, or deployed from `services/mango.desktop` as fallback).
5. Verifies that no competing display managers (SDDM, LightDM, GDM, Greetd) are active in `/var/service/`.
6. Safely enables `/etc/sv/ly` in `/var/service/`.

---

## Manual Setup & Service Enablement

If you prefer to configure Ly manually without running `install.sh`:

### 1. Wayland Session File (Automatic via MangoWC)
When `mangowc` is installed on Void Linux (via XBPS or `ninja install`), it automatically installs `/usr/share/wayland-sessions/mango.desktop`.

If this file is missing (e.g. standalone binary installation), install the provided fallback template:
```bash
if [ ! -f /usr/share/wayland-sessions/mango.desktop ]; then
    sudo mkdir -p /usr/share/wayland-sessions
    sudo cp ~/wm/services/mango.desktop /usr/share/wayland-sessions/mango.desktop
fi
```

### 2. Backup & Install Ly Configuration
```bash
sudo mkdir -p /etc/ly
if [ -f /etc/ly/config.ini ]; then
    sudo cp /etc/ly/config.ini /etc/ly/config.ini.bak.$(date +%Y%m%d_%H%M%S)
fi
sudo cp ~/wm/ly/config.ini /etc/ly/config.ini
```

### 3. Handle Conflicting Display Managers
Under Void Linux `runit`, only **one** display manager may run at a time. Disable any active graphical login managers:
```bash
sudo rm -f /var/service/sddm
sudo rm -f /var/service/lightdm
sudo rm -f /var/service/gdm
sudo rm -f /var/service/greetd
```

### 4. Prevent TTY2 Getty Collision
Because Ly runs on `tty2` by default:
```bash
if [ -e /var/service/agetty-tty2 ]; then
    sudo rm /var/service/agetty-tty2
fi
```

### 5. Enable the Ly Runit Service
```bash
sudo ln -s /etc/sv/ly /var/service/
```

---

## Theming & Aesthetics

The bundled `config.ini` is styled to harmonize with the rice:

| Element | Color Code | Palette Token | Description |
| :--- | :--- | :--- | :--- |
| **Background** | `0x002E3440` | `Nord0 (Polar Night)` | Deep dark slate background |
| **Foreground** | `0x00D8DEE9` | `Nord4 (Snow Storm)` | Clean off-white text |
| **Borders** | `0x0088C0D0` | `Nord8 (Frost Cyan)` | Subtle cyan border matching active Waybar accents |
| **Error FG** | `0x01BF616A` | `Nord11 (Aurora Red)` | Bold red text on incorrect password |
| **Header** | `MangoWC (Nord)` | Custom | Clean title header |
| **Animations**| `none` | N/A | Zero distractions; immediate prompt response |

---

## Safe Rollback & Emergency Recovery

If Ly fails to start, displays a blank screen, or locks you out:

### 1. Switch to an Alternate TTY
Press `Ctrl + Alt + F3` (or `F4` / `F5`) to switch to a functional console login prompt. Log in with your regular username and password.

### 2. Disable the Ly Service
Immediately deactivate the Ly service in runit:
```bash
sudo rm -f /var/service/ly
```

### 3. Restore the Default Getty on TTY2 (Optional)
```bash
sudo ln -s /etc/sv/agetty-tty2 /var/service/
```

### 4. Launch the Desktop Directly from TTY
You can always launch MangoWC manually from the shell:
```bash
start-mango
# or directly:
~/wm/scripts/start-mango
```

### 5. Restore Configuration Backup
If you need to restore your previous configuration:
```bash
sudo cp /etc/ly/config.ini.bak.* /etc/ly/config.ini
```

### 6. Inspect Diagnostic Logs
- Session launch logs: `cat ~/.local/state/ly-session.log`
- System Ly logs: `sudo cat /var/log/ly.log`
- Run the environment doctor: `~/wm/scripts/wm-doctor`
