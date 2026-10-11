# Waybar Enhancement & Refinement Plan

This document outlines suggested enhancements, visual polish, and desktop-tailored features for the Waybar configuration in `~/dotfiles/.config/HyprV/waybar/`.

---

## 1. Visual Polish & Module Pill Alignment

### Current Status
Modules are visually grouped into floating "pills" styled with Catppuccin Mocha colors:
- **Left Pill 1:** `[ Clock | Weather ]` (`#clock`, `#custom-weather`)
- **Left Pill 2:** `[ Workspaces ]` (`#workspaces`)
- **Center Pill:** `[ Window Title ]` (`#window`)
- **Right Pill 1:** `[ Network | Bluetooth ]` (`#network`, `#custom-bluetooth`)
- **Right Pill 2:** `[ Temperature | Power Profile | Battery ]`
- **Right Gap:** `Backlight` (`#backlight` has left-rounded border `10px 0 0 10px`, but its right side is cut off)
- **Right Pill 3:** `[ Volume | Microphone ]` (`#pulseaudio`, `#pulseaudio.microphone`)
- **Right Pill 4:** `[ Tray ]` (`#tray`)

### Suggested Improvements
1. **Fix Backlight Border Discontinuity:**
   - Either make `#backlight` a standalone rounded pill (`border-radius: 10px; margin-right: 10px;`) or connect it directly with the audio pill.
2. **Smooth Hover & State Transitions:**
   - Add `transition: all 0.2s ease-in-out;` to buttons and module selectors in `style.css` for fluid workspace switching and hover effects.

---

## 2. Desktop vs. Laptop Hardware Cleanup

### Motivation
The host machine is a desktop (`mubarchDesktop`):
- `/sys/class/power_supply` has no battery devices.
- `/sys/class/backlight` has no display backlight controls (desktop monitors adjust via hardware buttons or DDC/CI).

### Suggested Replacements
Replace the inactive `battery` and `backlight` modules with rich desktop hardware telemetry:
1. **`cpu` Module:**
   - Icon: ` {usage}%`
   - Accent: Catppuccin Flamingo (`#f2cdcd`) or Peach (`#fab387`)
   - Click action: Launches `btop` (`kitty -e btop`)
2. **`memory` Module:**
   - Icon: ` {used:0.1f}G` / `{percentage}%`
   - Accent: Catppuccin Mauve (`#cba6f7`)
   - Tooltip: Total RAM, Swap usage, buffer/cached memory details.
3. **`disk` Module (Optional):**
   - Icon: `󰋊 {percentage_used}%`
   - Displays available storage on root (`/`) or `/home`.

---

## 3. Media Player (MPRIS) Integration

### Overview
Integrate Waybar's built-in `mpris` module into `modules-center` (or `modules-left` next to workspaces):
- **Display:** ` {artist} - {title}` (styled in Catppuccin Pink `#f5c2e7` or Sapphire `#74c7ec`).
- **Controls:**
  - Left click: Play / Pause
  - Scroll up: Next track
  - Scroll down: Previous track
- **Dynamic Visibility:** Automatically disappears when no media player (Spotify, Zen Browser, MPV) is active.

---

## 4. System Updates Module

### Overview
Add an update counter module using the existing `~/.config/HyprV/waybar/scripts/update-sys` helper or `checkupdates`:
- **Display:** `󰏔 {count}` in Catppuccin Peach (`#fab387`).
- **Behavior:**
  - Displays count only when pacman / AUR updates are pending.
  - Automatically hides when the system is fully up to date (`0` updates).
  - Left click: Launches terminal upgrade session (`kitty -e yay -Syu`).

---

## 5. Idle Inhibitor ("Caffeine") Module

### Overview
Add the built-in `idle_inhibitor` module to keep the display awake during video playback, presentations, or long compiles:
- **Display:**
  - Active: `󰅶` in Catppuccin Yellow (`#f9e2af`)
  - Inactive: `󰾪` in Surface / Subtext (`#6c7086`)
- **Behavior:** Toggles hypridle / screen locker inhibition on left click.

---

## Quick Reference: Catppuccin Mocha Palette

| Color Name | Hex Code | Purpose in Waybar |
| :--- | :--- | :--- |
| **Base** | `#1e1e2e` | Module backgrounds, Tooltip body |
| **Mantle** | `#181825` | Module borders |
| **Crust** | `#11111b` | Workspace hover background |
| **Surface0** | `#313244` | Tooltip border, subtle divider lines |
| **Text** | `#cdd6f4` | Primary text and icons |
| **Peach** | `#fab387` | Clock, Weather, Today's date highlight |
| **Mauve** | `#cba6f7` | Microphone, Memory, Month title header |
| **Blue** | `#89b4fa` | Bluetooth, Pulseaudio, UTC time |
| **Yellow** | `#f9e2af` | Network, Weekday headers, Idle active |
| **Green** | `#a6e3a1` | Power profile, Battery, System good state |
| **Red** | `#f38ba8` | Max temperature, Critical battery/temp |

---

## 6. Upcoming Feature Backlog & Refinements

### 1. Unified Battery & Display Brightness Pill
- **Concept:** Merge Battery (`#battery`) and Display Brightness (`#backlight`) into a single 2-part pill on laptops:
  `[ 󰂄 Battery | 󰃠 Brightness ]`
- **Styling Requirements:**
  - Left element (`#battery`): `border-radius: 10px 0 0 10px; border-right: 0px;`
  - Right element (`#backlight`): `border-radius: 0 10px 10px 0; border-left: 0px; margin-right: 10px;`
  - Cross-device resilience: ensure desktop layout remains clean and symmetrical when both hardware devices are absent.

### 2. Audio & Microphone Device Tooltip Details
- **Output Device Tooltip:** Hovering over the volume module (`#pulseaudio`) should display the active playback sink/device name (e.g., `󰓃 Output: Speakers / Arctis Nova 7` or HDMI audio) and volume level.
- **Input Device Tooltip:** Hovering over the microphone module (`#pulseaudio.microphone`) should display the active input source/microphone name (e.g., `󰍬 Input: Blue Yeti / USB Audio Device`) and mute state.
- **Implementation:** Utilize Waybar's native `tooltip-format` fields (`{desc}`, `{volume}%`) or `wpctl` / `pactl` inspection.

### 3. Audio Playback Controls in Sound Pill
- **Concept:** Enhance the sound pill with media playback controls (play/pause, next/previous, track info).
- **Behavior:**
  - Opens on click (or via a dedicated mini media icon in the pill).
  - Can integrate with MPRIS / `playerctl` to control active players (Spotify, Zen Browser, MPV).
  - Collapses cleanly when no media is active or when toggled closed.

### 4. Notification Center & Quick Settings Panel (Action Center)
- **Concept:** A dropdown / slide-out panel that manages undismissed notifications and houses all quick system controls in one place — similar to the Windows Notification & Action Center, but modern, lightweight, and tailored for Hyprland.
- **Features to Include:**
  - **Notification History:** Scrollable log of unread/undismissed notifications with per-item dismissal and "Clear All".
  - **Quick Control Toggles:** Wi-Fi toggle/network selection, Bluetooth toggle/device connect, Do Not Disturb (DND), Night Light.
  - **Quick Sliders:** Master volume slider, microphone input slider, display brightness slider.
  - **Media Widget:** Mini player with album art and playback scrub controls.
- **Candidates & Architecture for Research:**
  - **[SwayNotificationCenter (`swaync`)](https://github.com/ErikReider/SwayNotificationCenter):** The most popular and feature-complete solution for Hyprland/Wayland. Includes a full notification tray + customizable control center widgets, CSS theming (Catppuccin Mocha supported), and a dedicated Waybar tray/bell widget.
  - **[AGS (Aylur's GTK Shell)](https://github.com/Aylur/ags):** Highly customizable TypeScript + GTK3/4 shell capable of building complete custom control centers and notification flyouts.
  - **Current Daemon Audit:** Review existing notification daemon (`mako` in `hyprland.conf:41`) and evaluate migration to `swaync` for seamless Action Center integration.

