#!/usr/bin/env python3
import json, os, subprocess, sys, time
from pathlib import Path
TIMEOUT = 30.0
STATE = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / f"omarchy-window-snap-{os.getuid()}.json"

def hj(*args):
    p = subprocess.run(["hyprctl", "-j", *args], capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(p.stderr.strip() or "hyprctl failed")
    return json.loads(p.stdout)

def dispatch(name, params=""):
    cmd = ["hyprctl", "dispatch", name]
    if params: cmd.append(params)
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)

def monitor_geometry(mid):
    mon = next((m for m in hj("monitors") if m.get("id") == mid), None)
    if mon is None: raise RuntimeError("monitor not found")
    scale = float(mon.get("scale") or 1.0)
    fw = round(float(mon["width"]) / scale)
    fh = round(float(mon["height"]) / scale)
    l, t, r, b = [round(float(v)) for v in (mon.get("reserved") or [0,0,0,0])]
    return round(float(mon["x"])) + l, round(float(mon["y"])) + t, max(2, fw-l-r), max(2, fh-t-b)

def exists(addr):
    return any(c.get("address") == addr for c in hj("clients"))

def snap(addr, mid, side, vertical=None):
    if not exists(addr): return False
    dispatch("focuswindow", f"address:{addr}")
    dispatch("setfloating", f"address:{addr}")
    x, y, w, h = monitor_geometry(mid)
    lw, rw = w // 2, w - (w // 2)
    tx, tw = (x, lw) if side == "left" else (x + lw, rw)
    if vertical is None:
        ty, th = y, h
    else:
        th_top, th_bottom = h // 2, h - (h // 2)
        ty, th = (y, th_top) if vertical == "up" else (y + th_top, th_bottom)
    sel = f"address:{addr}"
    dispatch("resizewindowpixel", f"exact {tw} {th},{sel}")
    dispatch("movewindowpixel", f"exact {tx} {ty},{sel}")
    return True

def save(side, addr, mid):
    STATE.write_text(json.dumps({"side": side, "address": addr, "monitor": mid, "time": time.monotonic()}))

def load():
    try: d = json.loads(STATE.read_text())
    except Exception: return None
    if time.monotonic() - float(d.get("time", 0)) > TIMEOUT:
        STATE.unlink(missing_ok=True)
        return None
    return d

def main():
    if len(sys.argv) != 2 or sys.argv[1] not in {"left","right","up","down"}: return 2
    d = sys.argv[1]
    if d in {"left","right"}:
        a = hj("activewindow")
        addr, mid = a.get("address"), a.get("monitor")
        if addr and mid is not None and snap(addr, mid, d): save(d, addr, mid)
        return 0
    st = load()
    if not st: return 0
    snap(st["address"], st["monitor"], st["side"], d)
    STATE.unlink(missing_ok=True)
    return 0

if __name__ == "__main__":
    try: raise SystemExit(main())
    except Exception: raise SystemExit(0)
