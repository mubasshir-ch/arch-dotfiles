#!/usr/bin/env python3
import os
import re
import json
import html

def parse_hyprland_config():
    conf_path = os.path.expanduser("~/.config/hypr/hyprland.lua")
    if not os.path.exists(conf_path):
        return None

    try:
        with open(conf_path, "r", encoding="utf-8") as f:
            lines = f.readlines()
    except Exception:
        return None

    # Detect local mainMod
    main_mod = "SUPER"
    for line in lines:
        raw = line.strip()
        m_mod = re.match(r"^(?:local\s+)?mainMod\s*=\s*[\"']([^\"']+)[\"']", raw)
        if m_mod:
            main_mod = m_mod.group(1).strip() or "SUPER"
            break

    apps = []
    windows = []
    session = []

    # Helper to clean and format key combos
    def format_combo(mod_str, key_str):
        mod_clean = mod_str.replace("$mainMod", main_mod).replace("mainMod", main_mod).strip()
        parts = [p.capitalize() for p in mod_clean.split() if p]
        key_clean = key_str.strip()
        if key_clean.lower() == "return":
            key_clean = "Enter"
        elif key_clean.lower() == "semicolon":
            key_clean = ";"
        elif key_clean.lower() == "space":
            key_clean = "Space"
        elif len(key_clean) == 1:
            key_clean = key_clean.upper()
        if parts:
            return " + ".join(parts + [key_clean])
        return key_clean

    seen_combos = set()

    for line in lines:
        raw = line.strip()
        if not raw or raw.startswith("--"):
            continue
        if not raw.startswith("hl.bind("):
            continue

        comment = ""
        if " --" in raw:
            code_part, comment = raw.rsplit(" --", 1)
            comment = comment.strip()
        else:
            code_part = raw

        m = re.match(r"^hl\.bind\((.+?),\s*(hl\.dsp\.[a-zA-Z0-9_.]+)\((.*)\)\s*(?:,\s*\{.*\})?\)$", code_part.strip())
        if not m:
            continue

        keys_expr, dsp_fn, dsp_args_raw = m.groups()
        dsp_args_raw = dsp_args_raw.strip()

        # Parse keys_expr like: mainMod .. " + SHIFT + R" or "SUPER + Q"
        tokens = [
            t.strip().strip('"').strip("'")
            for t in re.split(r"\.\.|\+", keys_expr)
            if t.strip().strip('"').strip("'")
        ]
        if not tokens:
            continue

        key_raw = tokens[-1]
        mod_raw = " ".join(tokens[:-1])

        # Map Lua dispatcher back to legacy dispatcher names & args
        disp = ""
        args = ""
        if dsp_fn == "hl.dsp.exec_cmd":
            disp = "exec"
            args = dsp_args_raw
            if (args.startswith("[[") and args.endswith("]]")):
                args = args[2:-2]
            elif (args.startswith('"') and args.endswith('"')) or (args.startswith("'") and args.endswith("'")):
                args = args[1:-1]
        elif dsp_fn == "hl.dsp.window.close" or dsp_fn == "hl.dsp.window.kill":
            disp = "killactive"
        elif dsp_fn == "hl.dsp.window.fullscreen":
            disp = "fullscreen"
        elif dsp_fn == "hl.dsp.exit":
            disp = "exit"
        elif dsp_fn == "hl.dsp.window.float":
            disp = "togglefloating"
        elif dsp_fn == "hl.dsp.window.pseudo":
            disp = "pseudo"
        elif dsp_fn == "hl.dsp.layout":
            disp = "layoutmsg"
            args = dsp_args_raw.strip('"').strip("'")
        elif dsp_fn == "hl.dsp.focus":
            if "workspace" in dsp_args_raw:
                disp = "workspace"
            else:
                disp = "movefocus"
        elif dsp_fn == "hl.dsp.window.move":
            if "workspace" in dsp_args_raw:
                disp = "movetoworkspace"
            else:
                disp = "movewindow"
        elif dsp_fn == "hl.dsp.window.resize":
            disp = "resizeactive"
        elif dsp_fn == "hl.dsp.window.drag":
            disp = "movewindow"
        else:
            continue

        combo = format_combo(mod_raw, key_raw)
        if combo in seen_combos:
            continue

        # Skip repetitive 1..0 workspace binds from individual listing
        if disp in ("workspace", "movetoworkspace") and key_raw in "1234567890":
            continue
        # Skip repetitive hjkl or arrow movefocus from individual listing
        if disp == "movefocus" and key_raw.lower() in ("h", "j", "k", "l", "left", "right", "up", "down"):
            continue
        if disp == "movewindow" and key_raw.lower() in ("h", "j", "k", "l"):
            continue
        if disp == "resizeactive" and key_raw.lower() in ("comma", "period", "u", "i"):
            continue
        if "mouse:" in key_raw or key_raw.startswith("mouse_"):
            continue

        # Clean description
        desc = comment
        if desc:
            # Shorten overly verbose comments to prevent tooltip wrapping
            if len(desc) > 36 and "(" in desc:
                desc = desc.split("(")[0].strip()
            if len(desc) > 36:
                desc = desc[:33] + "..."
            # Capitalize first letter of comment
            desc = desc[0].upper() + desc[1:]

        # Categorize
        if disp == "exec":
            cmd = args.split()[0] if args else ""
            cmd_base = os.path.basename(cmd)

            # System/session execs
            if "hyprlock" in args:
                session.append((combo, desc or "Lock Screen (Hyprlock)"))
            elif "wlogout" in args:
                session.append((combo, desc or "Power / Logout Menu"))
            elif "hyprctl reload" in args:
                session.append((combo, desc or "Reload Hyprland"))
            else:
                if not desc:
                    desc = f"Launch {cmd_base.capitalize()}"
                apps.append((combo, desc))
            seen_combos.add(combo)
        elif disp in ("killactive", "fullscreen", "togglefloating", "pseudo", "layoutmsg"):
            if not desc:
                if disp == "killactive": desc = "Close Window"
                elif disp == "fullscreen": desc = "Toggle Fullscreen"
                elif disp == "togglefloating": desc = "Toggle Floating"
                elif disp == "pseudo": desc = "Pseudotile (Dwindle)"
                elif disp == "layoutmsg": desc = "Toggle Split"
            windows.append((combo, desc))
            seen_combos.add(combo)
        elif disp == "exit":
            session.append((combo, desc or "Exit Hyprland"))
            seen_combos.add(combo)

    # Add clean summarized navigation blocks
    windows.append((f"{main_mod} + H/J/K/L", "Focus Window (Vim-style / Arrows)"))
    windows.append((f"{main_mod} + Shift + HJKL", "Move Active Window"))
    windows.append((f"{main_mod} + , / . / U / I", "Resize Window Active"))

    session.append((f"{main_mod} + 1..0", "Switch Workspace (1-10)"))
    session.append((f"{main_mod} + Shift + 1..0", "Move Window to Workspace"))

    # Build Pango Markup Tooltip
    tooltip_lines = [
        "<span font_family='JetBrainsMono Nerd Font'><b>󰌌  Hyprland Keybindings</b>"
    ]

    if apps:
        tooltip_lines.extend(["", "<b><span color='#fab387'>APPLICATIONS &amp; LAUNCH</span></b>"])
        for c, d in apps:
            c_esc = html.escape(c)
            d_esc = html.escape(d)
            tooltip_lines.append(f"  <span color='#cdd6f4'>{c_esc:<22}</span> <span color='#a6adc8'>{d_esc}</span>")

    if windows:
        tooltip_lines.extend(["", "<b><span color='#89b4fa'>WINDOW MANAGEMENT</span></b>"])
        for c, d in windows:
            c_esc = html.escape(c)
            d_esc = html.escape(d)
            tooltip_lines.append(f"  <span color='#cdd6f4'>{c_esc:<22}</span> <span color='#a6adc8'>{d_esc}</span>")

    if session:
        tooltip_lines.extend(["", "<b><span color='#a6e3a1'>SESSION &amp; WORKSPACES</span></b>"])
        for c, d in session:
            c_esc = html.escape(c)
            d_esc = html.escape(d)
            tooltip_lines.append(f"  <span color='#cdd6f4'>{c_esc:<22}</span> <span color='#a6adc8'>{d_esc}</span>")

    tooltip_lines.extend([
        "",
        "──────────────────────────────────────────",
        "󰈈 <i>Click to edit hyprland.lua in Neovim</i></span>"
    ])

    return "\n".join(tooltip_lines)

def main():
    tooltip = parse_hyprland_config()
    output = {
        "text": "",
        "tooltip": tooltip
    }
    print(json.dumps(output))

if __name__ == "__main__":
    main()
