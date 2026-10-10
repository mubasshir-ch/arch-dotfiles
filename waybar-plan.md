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
