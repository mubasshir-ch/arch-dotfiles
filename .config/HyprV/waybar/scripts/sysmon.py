#!/usr/bin/env python3
import json
import os
import glob
import subprocess

def get_cpu_temp():
    # 1. Direct AMD k10temp PCI path (works on Ryzen desktop & laptop)
    for p in glob.glob("/sys/devices/pci0000:00/0000:00:18.3/hwmon/hwmon*/temp1_input"):
        try:
            with open(p, "r") as f:
                return int(f.read().strip()) // 1000
        except Exception:
            pass

    # 2. General hwmon search by label
    for h in glob.glob("/sys/class/hwmon/hwmon*"):
        try:
            name_file = os.path.join(h, "name")
            if os.path.exists(name_file):
                with open(name_file, "r") as f:
                    name = f.read().strip()
                if name in ("k10temp", "coretemp"):
                    temp_file = os.path.join(h, "temp1_input")
                    if os.path.exists(temp_file):
                        with open(temp_file, "r") as f:
                            return int(f.read().strip()) // 1000
        except Exception:
            pass

    # 3. Fallback to thermal_zone
    for tz in glob.glob("/sys/class/thermal/thermal_zone*/temp"):
        try:
            with open(tz, "r") as f:
                val = int(f.read().strip())
                if val > 1000:
                    val //= 1000
                if 10 < val < 115:
                    return val
        except Exception:
            pass

    return None

def get_gpu_info():
    # 1. NVIDIA check via nvidia-smi
    try:
        out = subprocess.check_output(
            ["nvidia-smi", "--query-gpu=temperature.gpu,name", "--format=csv,noheader,nounits"],
            stderr=subprocess.DEVNULL,
            timeout=1
        ).decode().strip()
        if out:
            parts = [p.strip() for p in out.split(",")]
            temp = int(parts[0])
            name = parts[1] if len(parts) > 1 else "NVIDIA GPU"
            # Simplify name for clean display
            name = name.replace("NVIDIA GeForce ", "").replace("NVIDIA ", "")
            return temp, name
    except Exception:
        pass

    # 2. AMD / Intel DRM hwmon check
    for p in glob.glob("/sys/class/drm/card*/device/hwmon/hwmon*/temp1_input"):
        try:
            with open(p, "r") as f:
                temp = int(f.read().strip()) // 1000
                return temp, "Radeon Graphics"
        except Exception:
            pass

    return None, None

def get_ram_info():
    mem = {}
    try:
        with open("/proc/meminfo", "r") as f:
            for line in f:
                parts = line.split(":")
                if parts[0] in ("MemTotal", "MemAvailable"):
                    mem[parts[0]] = int(parts[1].split()[0])
        total = mem["MemTotal"] / (1024 * 1024)
        available = mem["MemAvailable"] / (1024 * 1024)
        used = total - available
        return used, total
    except Exception:
        return None, None

def main():
    cpu_temp = get_cpu_temp()
    gpu_temp, gpu_name = get_gpu_info()
    ram_used, ram_total = get_ram_info()

    # Determine status class
    status_class = "normal"
    max_temp = max(filter(None, [cpu_temp, gpu_temp]), default=0)
    if max_temp >= 80:
        status_class = "critical"
    elif max_temp >= 70:
        status_class = "warning"

    # Default icon: Thermometer (changes to warning/critical icon if hot)
    icon = "󰔏"
    if status_class == "critical":
        icon = "󱃂"

    # Alt text (inline dual pill)
    parts_alt = []
    if cpu_temp is not None:
        parts_alt.append(f"󰻠 {cpu_temp}°C")
    if gpu_temp is not None:
        parts_alt.append(f"󰢮 {gpu_temp}°C")
    alt_text = "  ".join(parts_alt) if parts_alt else icon

    # Tooltip card
    tooltip_lines = [
        "<b>Hardware Monitor</b>",
        ""
    ]
    if cpu_temp is not None:
        tooltip_lines.append(f"󰻠 CPU (Ryzen):     <b>{cpu_temp}°C</b>")
    if gpu_temp is not None:
        g_name = gpu_name or "GPU"
        tooltip_lines.append(f"󰢮 GPU ({g_name}): <b>{gpu_temp}°C</b>")
    if ram_used is not None and ram_total is not None:
        tooltip_lines.append(f"󰍛 Memory:          <b>{ram_used:.1f} / {ram_total:.1f} GB</b>")

    tooltip_lines.extend([
        "",
        "󰈈 <i>Left-click:</i>  Launch btop",
        "󰍽 <i>Right-click:</i> Toggle inline view"
    ])

    output = {
        "text": icon,
        "alt": alt_text,
        "tooltip": "\n".join(tooltip_lines),
        "class": status_class
    }

    print(json.dumps(output))

if __name__ == "__main__":
    main()
