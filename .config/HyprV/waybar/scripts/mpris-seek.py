#!/usr/bin/env python3
import sys
import subprocess
import time
import json
import os

try:
    from gi.repository import Gio, GLib
    HAS_GIO = True
except ImportError:
    HAS_GIO = False

def get_active_mpris():
    """Returns (proxy, bus, player_name) for the active/playing MPRIS player."""
    if not HAS_GIO:
        return None, None, None

    try:
        bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        names = bus.call_sync(
            'org.freedesktop.DBus', '/', 'org.freedesktop.DBus',
            'ListNames', None, None, Gio.DBusCallFlags.NONE, -1, None
        ).unpack()[0]

        mpris_names = [n for n in names if n.startswith('org.mpris.MediaPlayer2.')]
        if not mpris_names:
            return None, None, None

        first_match = None
        for name in mpris_names:
            proxy = Gio.DBusProxy.new_sync(
                bus, Gio.DBusProxyFlags.NONE, None,
                name, '/org/mpris/MediaPlayer2',
                'org.mpris.MediaPlayer2.Player', None
            )
            status_prop = proxy.get_cached_property('PlaybackStatus')
            status = status_prop.unpack() if status_prop else ""
            if status == 'Playing':
                return proxy, bus, name
            if first_match is None:
                first_match = (proxy, bus, name)

        return first_match if first_match else (None, None, None)
    except Exception:
        return None, None, None

def get_metadata():
    """Fetches (pos, length, status, has_position, player_name)"""
    proxy, bus, name = get_active_mpris()
    if proxy is not None:
        try:
            pos_prop = proxy.get_cached_property('Position')
            has_pos = (pos_prop is not None)
            pos = float(pos_prop.unpack()) / 1e6 if has_pos else 0.0

            meta_prop = proxy.get_cached_property('Metadata')
            meta = meta_prop.unpack() if meta_prop else {}
            len_val = meta.get('mpris:length')
            length = float(len_val) / 1e6 if len_val is not None else 0.0

            status_prop = proxy.get_cached_property('PlaybackStatus')
            status = status_prop.unpack() if status_prop else "Playing"

            return pos, length, status, has_pos, name, proxy
        except Exception:
            pass

    # Fallback to playerctl
    pos = 0.0
    has_pos = False
    try:
        pos_raw = subprocess.check_output(['playerctl', 'position'], stderr=subprocess.DEVNULL).decode().strip()
        pos = float(pos_raw)
        has_pos = (pos > 0.001)
    except Exception:
        pass

    length = 0.0
    try:
        len_raw = subprocess.check_output(['playerctl', 'metadata', 'mpris:length'], stderr=subprocess.DEVNULL).decode().strip()
        length = float(len_raw) / 1e6
    except Exception:
        pass

    status = "Playing"
    try:
        status = subprocess.check_output(['playerctl', 'status'], stderr=subprocess.DEVNULL).decode().strip()
    except Exception:
        pass

    return pos, length, status, has_pos, "", None

def parse_delta(delta_str):
    s = delta_str.strip()
    if s.endswith('+'):
        return float(s[:-1])
    elif s.endswith('-'):
        return -float(s[:-1])
    elif s.startswith('+'):
        return float(s[1:])
    elif s.startswith('-'):
        return -float(s[1:])
    return float(s)

def format_time(seconds):
    seconds = int(max(0, seconds))
    m, s = divmod(seconds, 60)
    h, m = divmod(m, 60)
    if h > 0:
        return f"{h}:{m:02d}:{s:02d}"
    return f"{m:02d}:{s:02d}"

def cmd_seek(delta_str):
    """Always performs purely relative seeking. Never depends on absolute Position."""
    try:
        delta = parse_delta(delta_str)
        _, _, _, _, player_name, proxy = get_metadata()

        is_browser = any(b in player_name.lower() for b in ('firefox', 'zen', 'chromium', 'chrome'))

        # Web players (YouTube, YouTube Music, etc.) clamp each MediaSession Seek call to 5s.
        # For deltas > 5s in browsers, we send multiple 5s Seek steps to get exact intervals (+30s = 6 steps).
        if is_browser and abs(delta) > 5.0:
            steps = int(round(abs(delta) / 5.0))
            direction = 1 if delta > 0 else -1
            if proxy is not None:
                for _ in range(steps):
                    proxy.call_sync(
                        'Seek',
                        GLib.Variant('(x)', (direction * 5000000,)),
                        Gio.DBusCallFlags.NONE, -1, None
                    )
                    time.sleep(0.02)
            else:
                arg = "5+" if direction > 0 else "5-"
                for _ in range(steps):
                    subprocess.run(['playerctl', 'position', arg], stderr=subprocess.DEVNULL)
                    time.sleep(0.02)
        else:
            # Single native relative seek (exact for desktop players and +-5s on browsers)
            if proxy is not None:
                proxy.call_sync(
                    'Seek',
                    GLib.Variant('(x)', (int(delta * 1000000),)),
                    Gio.DBusCallFlags.NONE, -1, None
                )
            else:
                arg = f"{abs(delta)}+" if delta > 0 else f"{abs(delta)}-"
                subprocess.run(['playerctl', 'position', arg], stderr=subprocess.DEVNULL)
    except Exception:
        pass

def cmd_time():
    try:
        pos, length, _, has_pos, _, _ = get_metadata()
        if has_pos and length > 0:
            print(f"{format_time(pos)} / {format_time(length)}")
        elif has_pos and pos > 0:
            print(f"{format_time(pos)}")
        else:
            print("Playing")
    except Exception:
        print("No media")

def cmd_waybar():
    try:
        pos, length, status, has_pos, _, _ = get_metadata()
        if has_pos and length > 0:
            time_str = f"{format_time(pos)} / {format_time(length)}"
            data = {
                "text": time_str,
                "tooltip": f"Media: {time_str} ({status})",
                "class": status.lower()
            }
            print(json.dumps(data))
        elif has_pos and pos > 0:
            time_str = format_time(pos)
            data = {
                "text": time_str,
                "tooltip": f"Media: {time_str} ({status})",
                "class": status.lower()
            }
            print(json.dumps(data))
        elif status == "Playing":
            data = {
                "text": "Media Playing",
                "tooltip": "Media playing (web player/stream)",
                "class": "playing"
            }
            print(json.dumps(data))
        else:
            print(json.dumps({"text": "", "class": "empty"}))
    except Exception:
        print(json.dumps({"text": "", "class": "empty"}))

def cmd_status():
    try:
        pos, length, status, has_pos, _, _ = get_metadata()
        if has_pos and length > 0:
            percent = max(0, min(100, int((pos / length) * 100)))
            bar_len = 12
            filled = int((percent / 100.0) * bar_len)
            bar = "━" * filled + "●" + "━" * (bar_len - filled)
            print(f"{format_time(pos)} {bar} {format_time(length)}")
        else:
            print(status)
    except Exception:
        print("No media playing")

def main():
    if len(sys.argv) < 2:
        cmd_status()
        return

    arg = sys.argv[1].lower()
    if arg == "seek" and len(sys.argv) >= 3:
        cmd_seek(sys.argv[2])
    elif arg == "time":
        cmd_time()
    elif arg == "waybar":
        cmd_waybar()
    elif arg == "status":
        cmd_status()
    else:
        cmd_status()

if __name__ == "__main__":
    main()
