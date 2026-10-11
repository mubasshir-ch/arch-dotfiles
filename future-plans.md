# Future Plans & Desktop Adjustments

This document outlines hardware-specific modifications and optimizations to apply to the dotfiles for your desktop setup when you are ready to adjust them.

> [!NOTE]
> All original configuration files have been kept untouched. These notes serve as a guide for tailoring the laptop/desktop shared setup to your current desktop environment.

---

## 1. Monitor Configuration (`.config/hypr/hyprland.conf`)

In `~/.config/hypr/hyprland.conf` (lines 12–20):
- **Current Laptop Setup:**
  ```ini
  monitor = eDP-1, 1920x1080@60, 0x0, 1.25
  monitor=HDMI-A-1,1920x1080@74.97,auto-right,1
  ```
- **Action for Desktop:**
  - `eDP-1` is an embedded DisplayPort (internal laptop screen) and does not exist on a desktop.
  - Run `hyprctl monitors` to get the names of your desktop display outputs (e.g., `DP-1`, `DP-2`, `HDMI-A-1`).
  - Comment out `monitor = eDP-1,...` and specify your desktop monitor(s), or keep `monitor=,preferred,auto,1` as a dynamic fallback.

---

## 2. GPU & Video Acceleration (`.config/hypr/hyprland.conf` & `env_var_nvidia.conf`)

In `~/.config/hypr/hyprland.conf` (line 5):
```ini
source = ~/.config/hypr/env_var_nvidia.conf
```
- **If your Desktop has an AMD or Intel GPU:**
  - Comment out this line (`# source = ~/.config/hypr/env_var_nvidia.conf`).
  - Leaving `LIBVA_DRIVER_NAME,nvidia` active on AMD/Intel breaks VA-API hardware video acceleration across browsers and media players.
- **If your Desktop has an NVIDIA GPU:**
  - Keep this line active.
  - Note: On Hyprland 0.40+, `env = WLR_NO_HARDWARE_CURSORS,1` in `env_var_nvidia.conf` is deprecated in favor of adding `cursor { no_hardware_cursors = true }` inside `hyprland.conf`.
  - Ensure DRM modesetting is enabled in your bootloader (`nvidia_drm.modeset=1`).

---

## 3. Laptop & 2-in-1 Tablet Background Daemons

In `~/.config/hypr/hyprland.conf` (lines 48–52):
```ini
exec-once = rot8
exec-once = ~/.config/hypr/tablet-mode.sh
exec = lan-mouse daemon
```
- **Screen Rotation (`rot8`):** Sensor-based screen rotation daemon for 2-in-1 convertibles. Not needed on a desktop.
- **Tablet Mode Listener (`tablet-mode.sh`):** Listens to `libinput debug-events` for laptop switch events using hardcoded IDs (`at-translated-set-2-keyboard` and `elan1301:00-04f3:3115-touchpad`). On desktop, this process runs endlessly with no matching hardware.
- **LAN Mouse (`lan-mouse daemon`):** Software KVM for sharing cursor/keyboard across machines over the local network. Comment out if you only use one computer at your desk.

---

## 4. ROG Laptop Keybinds & Power Profiles

- **`~/.config/hypr/rog-g15-strix-2021-binds.conf`:**
  - Uses `asusctl` and `rog-control-center` for fan/power profiles and RGB keyboard control.
  - Standard desktop motherboards do not support `asusctl`. If sourced, these binds will do nothing or error.
- **Waybar Power Profile Script (`~/.config/HyprV/waybar/scripts/power_profile`):**
  - Calls `asusctl profile -p`. On a desktop, Waybar may show an empty or errored power profile module. Replace with a desktop governor/power-profiles-daemon or remove the module from Waybar.

---

## 5. Fingerprint Authentication (`.config/hypr/hyprlock.conf`)

In `~/.config/hypr/hyprlock.conf` (lines 66–73):
```ini
auth {
    fingerprint {
        enabled = true
        ready_message = (Scan fingerprint to unlock)
        ...
    }
}
```
- If your desktop does not have a fingerprint reader, set `enabled = false` to avoid PAM/fprintd timeout delays or warnings during unlock.

---

## 6. Personal Paths & Aliases (`.zshrc`)

In `~/.zshrc`:
- **Dual Boot Alias (line 116):**
  ```bash
  alias boot-windows='sudo grub-reboot "osprober-efi-3E25-0E62" && sudo reboot'
  ```
  - The EFI identifier `osprober-efi-3E25-0E62` was specific to the laptop's Windows partition. If dual-booting Windows on the desktop, update this UUID by inspecting `/boot/grub/grub.cfg`.
- **Ollama Storage Path (line 122):**
  ```bash
  export OLLAMA_MODELS="/mnt/ssd/ollama/models"
  ```
  - Ensure `/mnt/ssd` is mounted on your desktop via `/etc/fstab`, or adjust the path to your desktop's storage layout.
- **Development Toolchains (lines 130–144):**
  - Verify paths for Java 17 (`/usr/lib/jvm/java-17-openjdk`), Flutter (`~/.development/flutter`), and Android SDK (`~/.development/android-sdk`).

---

## 7. Kitty Window Behavior (Tiling vs. Floating vs. Fullscreen)

In `~/.config/hypr/hyprland.conf`:
- **Default Tiling Behavior:** Hyprland uses a dynamic tiling layout (`layout = dwindle`). If Kitty is the only open window on a workspace, it will automatically expand to fill the entire workspace area (minus gaps and Waybar). Opening a second window (`SUPER + RETURN`) will tile them side-by-side.
- **Toggling Modes via Keybindings:**
  - `SUPER + SHIFT + T`: Toggle floating mode on the active window.
  - `SUPER + F`: Toggle true fullscreen (hides Waybar and gaps).
- **Opening Kitty as a Floating Window by Default:**
  If you want Kitty to always open as a centered floating window instead of tiling across the workspace, uncomment and configure in `hyprland.conf`:
  ```ini
  windowrule = float 1, match:class ^(kitty)$
  windowrule = size 1000 650, match:class ^(kitty)$
  windowrule = center 1, match:class ^(kitty)$
  ```

