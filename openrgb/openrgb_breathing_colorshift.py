#!/usr/bin/env python3
"""
Custom OpenRGB Effect (OpenRGB v1.0 / SDK Protocol v6):
1. Breathing: 4.75-second period (2.375s 0% -> 100%, 2.375s 100% -> 0%) with perceptual gamma (2.0)
2. Color Shift: 60-second full 360-degree hue cycle (6 degrees/sec)
"""

import colorsys
import socket
import struct
import subprocess
import threading
import time

HOST = "127.0.0.1"
PORT = 6742

HALF_BREATH_SEC = 2.375
BREATH_PERIOD_SEC = HALF_BREATH_SEC * 2.0  # 4.75s total (2.375s fade-in, 2.375s fade-out)
BREATH_GAMMA = 2.0
COLOR_CYCLE_SEC = 60.0
KEYBOARD_BREATH_SPEED = 3  # EVision speed step (0=fastest .. 5=slowest)

NET_PACKET_ID_REQUEST_CONTROLLER_COUNT = 0
NET_PACKET_ID_REQUEST_CONTROLLER_DATA = 1
NET_PACKET_ID_REQUEST_PROTOCOL_VERSION = 40
NET_PACKET_ID_SET_CLIENT_NAME = 50
NET_PACKET_ID_RGBCONTROLLER_UPDATELEDS = 1050
NET_PACKET_ID_RGBCONTROLLER_UPDATEMODE = 1101


class OpenRGBClient:
    def __init__(self, host=HOST, port=PORT):
        self.sock = socket.create_connection((host, port), timeout=5.0)
        self.proto = 6
        self.send_pkt(0, NET_PACKET_ID_SET_CLIENT_NAME, b"CustomBreathShift\x00")
        self.send_pkt(0, NET_PACKET_ID_REQUEST_PROTOCOL_VERSION, struct.pack("<I", self.proto))
        _, _, data = self.recv_expected(NET_PACKET_ID_REQUEST_PROTOCOL_VERSION)
        self.proto = min(self.proto, struct.unpack("<I", data)[0])

    def send_pkt(self, dev_idx, pkt_id, data=b""):
        hdr = b"ORGB" + struct.pack("<III", dev_idx, pkt_id, len(data))
        self.sock.sendall(hdr + data)

    def recv_pkt(self):
        hdr = b""
        while len(hdr) < 16:
            chunk = self.sock.recv(16 - len(hdr))
            if not chunk:
                raise ConnectionError("Server closed connection")
            hdr += chunk
        magic, dev_idx, pkt_id, length = struct.unpack("<4sIII", hdr)
        data = b""
        while len(data) < length:
            chunk = self.sock.recv(length - len(data))
            if not chunk:
                raise ConnectionError("Server closed connection")
            data += chunk
        return dev_idx, pkt_id, data

    def recv_expected(self, exp_pkt):
        while True:
            dev_idx, pkt_id, data = self.recv_pkt()
            if pkt_id == exp_pkt:
                return dev_idx, pkt_id, data

    def start_background_drainer(self):
        def _drain():
            self.sock.settimeout(None)
            try:
                while True:
                    if not self.sock.recv(4096):
                        break
            except Exception:
                pass

        t = threading.Thread(target=_drain, daemon=True)
        t.start()

    @staticmethod
    def _read_str(buf, off):
        slen = struct.unpack_from("<H", buf, off)[0]
        off += 2
        val = buf[off : off + slen - 1].decode("utf-8", errors="replace")
        off += slen
        return val, off

    def get_devices(self):
        # First use a short-lived protocol v3 connection to get exact zone/LED counts cleanly
        s3 = socket.create_connection((HOST, PORT), timeout=5.0)
        s3.sendall(b"ORGB" + struct.pack("<III", 0, NET_PACKET_ID_SET_CLIENT_NAME, 7) + b"InitV3\x00")
        s3.sendall(b"ORGB" + struct.pack("<III", 0, NET_PACKET_ID_REQUEST_PROTOCOL_VERSION, 4) + struct.pack("<I", 3))
        s3.sendall(b"ORGB" + struct.pack("<III", 0, NET_PACKET_ID_REQUEST_CONTROLLER_COUNT, 0))

        def recv_s3(exp_pkt):
            while True:
                h = b""
                while len(h) < 16:
                    h += s3.recv(16 - len(h))
                _, _, pid, plen = struct.unpack("<4sIII", h)
                d = b""
                while len(d) < plen:
                    d += s3.recv(plen - len(d))
                if pid == exp_pkt:
                    return d

        recv_s3(NET_PACKET_ID_REQUEST_PROTOCOL_VERSION)
        count = struct.unpack("<I", recv_s3(NET_PACKET_ID_REQUEST_CONTROLLER_COUNT))[0]
        led_counts = {}
        for idx in range(count):
            s3.sendall(
                b"ORGB" + struct.pack("<III", idx, NET_PACKET_ID_REQUEST_CONTROLLER_DATA, 4) + struct.pack("<I", 3)
            )
            d3 = recv_s3(NET_PACKET_ID_REQUEST_CONTROLLER_DATA)
            off = 8
            name3, off = self._read_str(d3, off)
            for _ in range(5):
                _, off = self._read_str(d3, off)
            num_modes, _ = struct.unpack_from("<Hi", d3, off)
            off += 6
            for _ in range(num_modes):
                _, off = self._read_str(d3, off)
                vals = struct.unpack_from("<iIIIIIIIIIIIH", d3, off)
                off += 50 + 4 * vals[12]
            num_zones = struct.unpack_from("<H", d3, off)[0]
            off += 2
            jrainbow_zero = False
            for _ in range(num_zones):
                z_name, off = self._read_str(d3, off)
                _, _, _, l_cnt, m_len = struct.unpack_from("<iIIIH", d3, off)
                off += 18 + m_len
                if z_name.startswith("JRAINBOW") and l_cnt == 0:
                    jrainbow_zero = True
            num_leds = struct.unpack_from("<H", d3, off)[0]
            if jrainbow_zero:
                # Ensure MSI ARGB fan headers are sized to 20 LEDs via raw socket packet (ID 1000)
                # Packet: dev_idx, pkt_id=1000 (ResizeZone), len=8, data=(int32 zone_idx, int32 new_size)
                s3.sendall(b"ORGB" + struct.pack("<III", idx, 1000, 8) + struct.pack("<ii", 2, 20))
                s3.sendall(b"ORGB" + struct.pack("<III", idx, 1000, 8) + struct.pack("<ii", 3, 20))
                num_leds = max(num_leds, 48)
            led_counts[idx] = num_leds
        s3.close()

        # Now query on our main protocol v6 connection to get exact Mode chunks for UPDATEMODE (1101)
        devices = []
        for idx in range(count):
            self.send_pkt(idx, NET_PACKET_ID_REQUEST_CONTROLLER_DATA, struct.pack("<I", self.proto))
            _, _, d6 = self.recv_expected(NET_PACKET_ID_REQUEST_CONTROLLER_DATA)
            off = 8
            name, off = self._read_str(d6, off)
            for _ in range(5):
                _, off = self._read_str(d6, off)
            num_modes, active_mode = struct.unpack_from("<Hi", d6, off)
            off += 6
            modes = {}
            for m in range(num_modes):
                start = off
                m_name, off = self._read_str(d6, off)
                # In OpenRGB v1.0 (proto v6), mode struct after name is 11 uint32s (44B) + 1 uint16 num_colors (2B) + 4*num_colors:
                # 0:flags, 1:s_min, 2:s_max, 3:b_min, 4:b_max, 5:c_min, 6:c_max, 7:speed, 8:b_val, 9:direction, 10:c_mode, 11:num_c
                vals = struct.unpack_from("<IIIIIIIIIIIH", d6, off)
                num_c = vals[11]
                off += 46 + 4 * num_c
                modes[m_name] = {
                    "idx": m,
                    "chunk": bytearray(d6[start:off]),
                    "name_raw_len": len(m_name.encode("utf-8")) + 3,
                    "s_min": vals[1],
                    "s_max": vals[2],
                    "b_max": vals[4],
                    "num_c": num_c,
                }
            devices.append({"idx": idx, "name": name, "modes": modes, "num_leds": led_counts[idx]})
        return devices


def compute_rgb(t):
    # 1. Breathing: 0 -> 100% over 2.375s, 100% -> 0% over next 2.375s (4.75s cycle)
    phase_breath = (t % BREATH_PERIOD_SEC) / HALF_BREATH_SEC
    if phase_breath <= 1.0:
        linear_b = phase_breath
    else:
        linear_b = 2.0 - phase_breath

    # Apply perceptual gamma correction so LEDs visibly fade without a long dark pause at 0%
    brightness = linear_b ** BREATH_GAMMA

    # 2. Color shift: full 360 deg color wheel in 60 seconds
    hue = (t % COLOR_CYCLE_SEC) / COLOR_CYCLE_SEC

    r, g, b = colorsys.hsv_to_rgb(hue, 1.0, brightness)
    return int(round(r * 255)), int(round(g * 255)), int(round(b * 255)), hue, brightness


def run_effect_loop():
    last_count = 0
    while True:
        client = OpenRGBClient()
        devices = client.get_devices()
        if len(devices) >= 5 or (len(devices) > 0 and len(devices) == last_count):
            break
        last_count = len(devices)
        client.sock.close()
        time.sleep(3.0)

    client.start_background_drainer()
    print(f"Connected to OpenRGB Server (proto v{client.proto}). Found {len(devices)} devices:")

    direct_devs = []
    breath_devs = []

    for dev in devices:
        idx = dev["idx"]
        name = dev["name"]
        modes = dev["modes"]
        if "Direct" in modes:
            m = modes["Direct"]
            payload = struct.pack("<Ii", len(m["chunk"]) + 8, m["idx"]) + bytes(m["chunk"])
            client.send_pkt(idx, NET_PACKET_ID_RGBCONTROLLER_UPDATEMODE, payload)
            direct_devs.append(dev)
            print(
                f"  [{idx}] {name} -> Using Direct mode ({dev['num_leds']} LEDs, {HALF_BREATH_SEC}s in / {HALF_BREATH_SEC}s out)"
            )
        elif "Breathing" in modes and modes["Breathing"]["num_c"] >= 1:
            m = modes["Breathing"]
            # In proto v6: +28 is speed, +32 is brightness (b_val), +36 is direction
            s_off = m["name_raw_len"] + 28
            b_off = m["name_raw_len"] + 32
            dir_off = m["name_raw_len"] + 36
            struct.pack_into("<I", m["chunk"], s_off, KEYBOARD_BREATH_SPEED)
            struct.pack_into("<I", m["chunk"], b_off, m["b_max"])  # 4 = 100% max brightness
            struct.pack_into("<I", m["chunk"], dir_off, 0)
            breath_devs.append((dev, m))
            print(
                f"  [{idx}] {name} -> Using hardware Breathing mode (speed={KEYBOARD_BREATH_SPEED}) synced every {BREATH_PERIOD_SEC}s"
            )

    start_t = time.monotonic()
    last_breath_cycle = -1

    while True:
        now = time.monotonic()
        t = now - start_t
        r, g, b, hue, brightness = compute_rgb(t)
        color_bytes = struct.pack("<BBBB", r, g, b, 0)

        # Update Direct mode devices (RAM, Mouse, Motherboard + Fans) at ~30 FPS
        for dev in direct_devs:
            n = dev["num_leds"]
            leds_payload = struct.pack("<H", n) + (color_bytes * n)
            pkt_data = struct.pack("<I", len(leds_payload) + 4) + leds_payload
            client.send_pkt(dev["idx"], NET_PACKET_ID_RGBCONTROLLER_UPDATELEDS, pkt_data)

        # Update hardware Breathing devices (EVision Keyboard) ONCE per 4.75s breath cycle
        breath_cycle = int(t // BREATH_PERIOD_SEC)
        if breath_cycle != last_breath_cycle:
            peak_hue = ((breath_cycle * BREATH_PERIOD_SEC + HALF_BREATH_SEC) % COLOR_CYCLE_SEC) / COLOR_CYCLE_SEC
            kr, kg, kb = colorsys.hsv_to_rgb(peak_hue, 1.0, 1.0)
            kr, kg, kb = int(round(kr * 255)), int(round(kg * 255)), int(round(kb * 255))
            for dev, m in breath_devs:
                c_off = m["name_raw_len"] + 46
                struct.pack_into("<BBBB", m["chunk"], c_off, kr, kg, kb, 0)
                payload = struct.pack("<Ii", len(m["chunk"]) + 8, m["idx"]) + bytes(m["chunk"])
                client.send_pkt(dev["idx"], NET_PACKET_ID_RGBCONTROLLER_UPDATEMODE, payload)
            last_breath_cycle = breath_cycle

        time.sleep(0.033)


def main():
    while True:
        try:
            run_effect_loop()
        except (ConnectionError, OSError) as exc:
            print(f"OpenRGB connection not ready or lost ({exc}), retrying in 2s...")
            time.sleep(2.0)


if __name__ == "__main__":
    main()
