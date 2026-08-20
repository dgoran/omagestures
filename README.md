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

OmaGestures is an Omarchy `service` plugin. Omarchy creates the service first and injects its manifest afterward, so activation waits for `manifest.__sourceDir` to become available. The service then launches a detached activation script that registers the four gestures directly in Hyprland with `hyprctl eval`.

It does not modify `~/.config/hypr/input.lua`, does not reload Hyprland, does not restart Quickshell, and does not register any Quickshell IPC target.

Disabling/removing the plugin unregisters the four gestures.

## Remove

```sh
omarchy plugin remove io.github.dgoran.omagestures
```

## Requirements

- Omarchy Quattro plugin system
- Hyprland 0.55+ with Lua configuration support
- Python 3
