# OmaGestures

Three-finger trackpad window snapping for Omarchy / Hyprland.

## Install

```sh
omarchy plugin add https://github.com/dgoran/omagestures.git --enable
```

## Gestures

Snapping applies to the active window only while it is floating (for example a
window toggled with SUPER + V). A tiled window keeps its layout and a fullscreen
window is left alone, so the swipe does nothing in those cases.

- 3-finger left → active floating window to left half
- 3-finger right → active floating window to right half
- then up within 30 seconds → same window to matching top corner
- then down within 30 seconds → same window to matching bottom corner

The follow-up gesture targets the same window moved by the initial left/right swipe.

## How it works

OmaGestures is an Omarchy `service` plugin. Its tiny, nonvisual QML adapter resolves its own plugin directory and starts one activation script from it. That script installs four native gesture callbacks in Hyprland's Lua runtime. Hyprland holds the selected window and 30-second sequence state in memory and performs the window operations directly.

A Hyprland config reload rebuilds that Lua runtime and drops the callbacks, so the adapter watches for `configreloaded` and reinstalls them.

There is no Python helper, state file, persistent subprocess, Hyprland config edit/reload, Quickshell restart, or plugin IPC target.

Disabling or removing the plugin unregisters its four gestures and clears its in-memory state.

## Remove

```sh
omarchy plugin remove io.github.dgoran.omagestures
```

## Requirements

- Omarchy Quattro plugin system
- Hyprland 0.56+ with Lua configuration support
- No other 3-finger `horizontal` gesture. Hyprland lets a `horizontal` gesture
  shadow the discrete `left`/`right` ones, which it then refuses to register
  ("Gesture will be overshadowed by a previous gesture"). Omarchy's stock
  `input.lua` registers `{ fingers = 3, direction = "horizontal", action =
  "scroll_move" }`; comment it out, or give these gestures a `mods` modifier.
