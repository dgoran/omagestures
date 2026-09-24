# OmaGestures

Trackpad window and workspace gestures for Omarchy / Hyprland.

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

Snapped windows are inset by a gap rather than sitting flush: 5px from the
usable screen edge and 10px between two halves, matching Omarchy's default
`gaps_out` and `gaps_in`.

Workspace gestures stay active while the plugin is installed, including when
the bar widget has snapping switched off:

- 4-finger left → previous workspace, stopping at 1
- 4-finger right → next workspace, stopping at 10
- Super + 4-finger horizontal → animated workspace swipe
- Super + 4-finger up → toggle Exposé

Left moves toward workspace 1 and right toward workspace 10, on purpose, so the
direction does not depend on `gestures.workspace_swipe_invert`. Workspaces
outside 1–10, including special and named ones, are left alone. Do not register
these same gestures again in `~/.config/hypr/input.lua`; a reload would install
them twice.

## Bar widget

OmaGestures puts a `◧` button on the Omarchy bar. Clicking it opens a small
panel that switches the gestures on or off and sets the two gaps with sliders;
the button dims while the gestures are off. Changes apply immediately.

Settings are stored twice on purpose. The bar entry in
`~/.config/omarchy/shell.json` is what the panel displays, and
`~/.local/state/omarchy/omagestures.conf` is what `activate.sh` reads, so a
Hyprland config reload can reinstall the gestures with the chosen gaps without
the shell being involved. The script reads that file key by key rather than
sourcing it, and refuses anything that is not an integer of at most 200.

Both can be driven from a terminal:

```sh
./activate.sh show             # print the current settings
./activate.sh apply 1 5 10     # <enabled> <outer gap> <inner gap>
```

## How it works

OmaGestures is an Omarchy `service` plugin. Its QML adapter resolves its own plugin directory and starts one activation script from it. That script installs the gesture callbacks in Hyprland's Lua runtime. Hyprland holds the selected window and 30-second sequence state in memory and performs the window operations directly.

A Hyprland config reload rebuilds that Lua runtime and drops the callbacks, so the adapter watches for `configreloaded` and reinstalls them.

There is no Python helper, persistent subprocess, Hyprland config edit/reload, Quickshell restart, or plugin IPC target. The snap gaps and the on/off switch are stored in `omagestures.conf` so a reload can reinstall without the shell.

Removing the plugin unregisters the three-finger snap and the four-finger workspace gestures and clears the in-memory snap state. Switching snapping off in the bar widget removes only the three-finger gestures.

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
- No second copy of the four-finger gestures above. The plugin registers those
  itself.
