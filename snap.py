#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import time
from pathlib import Path

TIMEOUT = 30.0
STATE = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / f"omagestures-{os.getuid()}.json"


def hypr_json(*args):
    p = subprocess.run(["hyprctl", "-j", *args], capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(p.stderr.strip() or "hyprctl failed")
    return json.loads(p.stdout)


def hypr_eval(code):
    p = subprocess.run(["hyprctl", "eval", code], capture_output=True, text=True)
    if p.returncode != 0 or p.stdout.strip().startswith("error:"):
        raise RuntimeError((p.stderr or p.stdout).strip() or "hyprctl eval failed")


def monitor_geometry(monitor_id):
    mon = next((m for m in hypr_json("monitors") if m.get("id") == monitor_id), None)
    if mon is None:
        raise RuntimeError("monitor not found")

    scale = float(mon.get("scale") or 1.0)
    full_w = round(float(mon["width"]) / scale)
    full_h = round(float(mon["height"]) / scale)
    left, top, right, bottom = [round(float(v)) for v in (mon.get("reserved") or [0, 0, 0, 0])]

    return (
        round(float(mon["x"])) + left,
        round(float(mon["y"])) + top,
        max(2, full_w - left - right),
        max(2, full_h - top - bottom),
    )


def client_exists(address):
    return any(c.get("address") == address for c in hypr_json("clients"))


def snap(address, monitor_id, side, vertical=None):
    if not client_exists(address):
        return False

    x, y, width, height = monitor_geometry(monitor_id)
    left_width = width // 2
    right_width = width - left_width

    if side == "left":
        target_x, target_w = x, left_width
    else:
        target_x, target_w = x + left_width, right_width

    if vertical is None:
        target_y, target_h = y, height
    else:
        top_height = height // 2
        bottom_height = height - top_height
        if vertical == "up":
            target_y, target_h = y, top_height
        else:
            target_y, target_h = y + top_height, bottom_height

    window = json.dumps(f"address:{address}")
    code = f'''\
hl.dispatch(hl.dsp.window.float({{ action = "set", window = {window} }}))
hl.dispatch(hl.dsp.window.resize({{ x = {target_w}, y = {target_h}, relative = false, window = {window} }}))
hl.dispatch(hl.dsp.window.move({{ x = {target_x}, y = {target_y}, relative = false, window = {window} }}))
'''
    hypr_eval(code)
    return True


def save_state(side, address, monitor_id):
    STATE.write_text(json.dumps({
        "side": side,
        "address": address,
        "monitor": monitor_id,
        "time": time.monotonic(),
    }))


def load_state():
    try:
        state = json.loads(STATE.read_text())
    except Exception:
        return None

    if time.monotonic() - float(state.get("time", 0)) > TIMEOUT:
        STATE.unlink(missing_ok=True)
        return None
    return state


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in {"left", "right", "up", "down"}:
        return 2

    direction = sys.argv[1]

    if direction in {"left", "right"}:
        active = hypr_json("activewindow")
        address = active.get("address")
        monitor_id = active.get("monitor")
        if address and monitor_id is not None and snap(address, monitor_id, direction):
            save_state(direction, address, monitor_id)
        return 0

    state = load_state()
    if not state:
        return 0

    snap(state["address"], state["monitor"], state["side"], direction)
    STATE.unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception:
        raise SystemExit(0)
