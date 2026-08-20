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

## How it works

OmaGestures is an Omarchy `service` plugin. Its tiny, nonvisual QML adapter starts one activation script after Omarchy supplies the plugin directory. That script installs four native gesture callbacks in Hyprland's Lua runtime. Hyprland holds the selected window and 30-second sequence state in memory and performs the window operations directly.

There is no Python helper, state file, persistent subprocess, Hyprland config edit/reload, Quickshell restart, or plugin IPC target.

Disabling or removing the plugin unregisters its four gestures and clears its in-memory state.

## Remove

```sh
omarchy plugin remove io.github.dgoran.omagestures
```

## Requirements

- Omarchy Quattro plugin system
- Hyprland 0.56+ with Lua configuration support
