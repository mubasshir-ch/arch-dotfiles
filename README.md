# Arch Linux & Hyprland Dotfiles (Catppuccin Mocha Lavender)

Unified **Arch Linux + Hyprland (HyprV4)** desktop environment, custom **Waybar** status bar architecture, **Catppuccin Mocha Lavender** toolkit synchronization, and hardware-guarded system daemons managed via **GNU Stow**.

---

## 1. Architecture & Highlights

| Layer | Component | Configuration & Highlights |
| :--- | :--- | :--- |
| **Compositor & Session** | `hyprland`, `hyprlock`, `hypridle`, `wlogout`, `sddm` | Multi-monitor layout, blur layer rules, desktop-friendly `hyprlock` (`fingerprint: enabled = false`), 4-profile `hypridle` controller |
| **Status Bar** | `waybar` | Custom modular pills: Active Window (runtime GTK icon discovery), MPRIS Media & Lyrics, Combined Hardware/Power Pill (`sysmon` + `battery` + `hypridle`), Network/Bluetooth, Weather/Clock/Updates, SwayNC |
| **Notifications** | `swaync` | Catppuccin Mocha control center (`Super + A`) with MPRIS widget, DND toggle, and action buttons |
| **Unified Theming** | GTK 2/3/4, Qt5/Qt6 (`qt5ct`/`qt6ct`), `kdeglobals`, `btop`, `Papirus-Dark` | Unified `catppuccin-mocha-lavender-standard+default`, `Papirus-Dark` (`cat-mocha-lavender` folders), and `catppuccin-mocha-dark-cursors` (size 24) |
| **File Management** | `thunar` (GUI) & `yazi` (TUI) | Thunar custom actions (`Kitty`, `Neovim`, `wl-copy`), `file-roller` & `xarchiver` archive integration, `swayimg` image viewer, `tumbler` thumbnails, and rich `yazi` previews |
| **Terminal & Editor** | `kitty`, `zsh` (Oh My Zsh + `starship`), `tmux`, `neovim` | Git submodule at `.config/nvim` (`lazy.nvim` + lazy-loaded `copilot.lua`), Tmux session auto-restore |
| **Local AI Coding** | `opencode` + `llama-server` | Pre-configured `Qwen3.5-9B` (`Q5_K_M`, 32K context) on-demand systemd user service (`llama-qwen35.service`) |

---

## 2. Custom Waybar Pill Architecture

All custom Waybar modules live in `.config/HyprV/waybar/scripts/` and are styled in `.config/HyprV/waybar/style/style.css`:

1. **Active Window Pill (`waybar-window`)**
   - Displays the focused application's native GTK icon (`-gtk-icontheme(...)`).
   - **Dynamic Icon Discovery:** Resolves unknown window classes against GTK icon themes and `.desktop` entries, caches mappings in `/tmp/waybar_resolved_icons.json`, and auto-registers missing CSS rules in `style.css`.
   - **Rich Tooltip & Compact/Full Toggle:** Hover shows full wrapped window title, class, PID, per-process CPU/RAM usage, and GPU utilization. Left-click toggles between icon-only (`compact`) and title (`full`) modes.
2. **MPRIS Media & Lyrics Pill (`waybar-media`)**
   - Displays current track metadata with live LRCLIB synced lyrics in the hover tooltip.
3. **Combined 3-Part Hardware & Power Pill (`waybar-sysmon` + `battery` + `hypridle-ctl`)**
   - **`custom/sysmon`:** Real-time CPU %, RAM %, and GPU % in the bar; hover tooltip renders top CPU/RAM processes, per-core temperatures, and NVIDIA VRAM/power stats.
   - **`custom/hypridle` (`hypridle-ctl`):** Interactive 4-profile idle manager with static syntax validation:
     - `performance` (`󰓅`): Lock `10m` | DPMS `25m` | Suspend `disabled`
     - `server` (`󰒋`): Lock `5m` | DPMS `5.5m` | Suspend `disabled` (keeps SSH/downloads/background tasks alive)
     - `balanced` (`󰾅`): Lock `5m` | DPMS `5.5m` | Suspend `15m`
     - `power-saver` (`󰌪`): Lock `2m` | DPMS `2.5m` | Suspend `5m`
4. **System Update Notifier (`sysupdate-notify` + `waybar-Update`)**
   - Background systemd user timer (`sysupdate-notify.timer`) + startup hook checks official (`checkupdates`) and AUR (`yay -Qua`) updates, sending deduplicated desktop notifications via `notify-send`.

---

## 3. Hardware & System Daemons (Desktop Auto-Detection)

`install.sh`, `hyprland.conf`, and the `systemd` user units automatically distinguish **Desktop** vs. **Laptop** via `/sys/class/dmi/id/chassis_type` (`3–7` = Desktop) and `/sys/class/power_supply/BAT*` (`ConditionPathExistsGlob=!/sys/class/power_supply/BAT*`). On a laptop, desktop-only packages (`lact`, `openrgb`, `i2c-tools`, `nvtop`) and hardware daemons are automatically skipped, while laptop utilities (`rot8`, `tablet-mode.sh`) are started instead:

- **OpenRGB Breathing + Color-Shift Daemon (`openrgb/openrgb_breathing_colorshift.py`)**
  - Uses OpenRGB SDK Protocol v6 to auto-resize `JRAINBOW1`/`JRAINBOW2` ARGB headers to 20 LEDs and synchronize a smooth 4.75s cosine breathing + 60s 360° HSV color wheel across motherboard fans, RAM, mouse, and EVision keyboard.
  - Managed by user services `openrgb-server.service` and `openrgb-breathing-colorshift.service`.
- **NVIDIA RTX 3060 Ti Undervolt (`etc/lact/config.yaml`)**
  - Deployed when PCI ID `10DE:2489` is detected. Flattens the VF curve at **1890 MHz @ 900 mV** (`+136`/`+137` MHz offset) via `lactd.service` for lower temperatures and power draw at above-stock boost clocks.
- **NVIDIA Suspend/Wake Video Memory Preservation (`etc/modprobe.d/nvidia-power-management.conf`)**
  - Sets `NVreg_PreserveVideoMemoryAllocations=1` and enables `nvidia-suspend.service`, `nvidia-hibernate.service`, and `nvidia-resume.service` so Wayland/Hyprland wakes cleanly from suspend.
- **T-Wolf AIO Cooler Display Driver (`.local/bin/twolf-aio` & `etc/udev/rules.d/99-twolf.rules`)**
  - Deployed when USB HID `5131:2017` is detected. Pure-Python `hidraw` daemon (`twolf-aio.service`) that streams live CPU/GPU temperatures and utilization to the AIO LCD every second using Windows `hid.dll`-compatible framing.
- **Dual-Boot Bluetooth LinkKey Sync (`.local/bin/bt-dualboot-sync`)**
  - Extracts Bluetooth pairing `LinkKey`s directly from a mounted Windows `SYSTEM` registry hive and syncs them into `/var/lib/bluetooth/<Adapter>/<Device>/info`:
    ```bash
    sudo ~/.local/bin/bt-dualboot-sync /mnt/win/Windows/System32/config/SYSTEM --apply
    ```
- **On-Demand Local Qwen3.5-9B Server (`llama-qwen35.service`)**
  - Configured for `opencode` (`.config/opencode/opencode.json`) on `http://127.0.0.1:8080/v1`. Kept disabled on boot to save VRAM; start on demand with:
    ```bash
    systemctl --user start llama-qwen35.service
    ```

---

## 4. Keybindings Quick Reference

| Keybind | Action |
| :--- | :--- |
| `Super + Return` | Open Kitty terminal |
| `Super + Q` / `Super + Shift + Q` | Switch HyprV theme / Close active window |
| `Super + E` | Open Thunar file manager |
| `Super + B` | Open Zen Browser |
| `Super + N` | Open Neovim in Kitty |
| `Super + Space` | Open Wofi application launcher |
| `Super + A` | Toggle SwayNC notification center |
| `Super + V` | Clipboard history (`cliphist` + `wofi`) |
| `Super + S` | Tmux session switcher |
| `Super + Shift + S` | Region screenshot (`grim` + `slurp` + `swappy`) |
| `Super + Shift + ;` | Lock screen (`hyprlock`) |
| `Super + Shift + P` | Power menu (`wlogout`) |

---

## 5. Automated Installation

Clone the repository with submodules and run `./install.sh`:

```bash
git clone --recurse-submodules https://github.com/mub/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

`install.sh` performs:
1. Official (`pacman`) and AUR (`yay`) package installation.
2. Submodule initialization (`.config/nvim`), Oh My Zsh + Catppuccin Zsh theme, and Tmux Plugin Manager (`tpm`).
3. Catppuccin Mocha Lavender folder icon theming (`papirus-folders`) and Telegram theme generation.
4. Automatic backup of any conflicting non-symlink files in `$HOME` to `~/.dotfiles_backup/<timestamp>/`, followed by `stow -v -t "$HOME" .`.
5. XDG MIME associations (`Thunar`, `FileRoller`, `swayimg`) and hardware-guarded system/user service activation.
