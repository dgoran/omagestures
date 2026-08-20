# OmaGestures

Three-finger trackpad window snapping for Omarchy / Hyprland.

## Install

```sh
omarchy plugin add https://github.com/dgoran/omagestures.git --enable
```

## Gestures

- 3-finger left → active window to left half
- 3-finger right → active window to right half
- then up within 30 seconds → same window to matching top corner
- then down within 30 seconds → same window to matching bottom corner

The follow-up gesture targets the same window moved by the initial left/right swipe.

## Remove

```sh
omarchy plugin remove io.github.dgoran.omagestures
```

## Requirements

- Omarchy Quattro plugin system
- Hyprland with Lua gesture callback support
- Python 3

The plugin only manages its own marked block in `~/.config/hypr/input.lua`.
