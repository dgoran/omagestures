# Native Hyprland Gestures Design

## Goal

Install and activate OmaGestures with one Omarchy command while keeping the runtime minimal and avoiding Quickshell lifecycle instability.

## Requirements

- `omarchy plugin add https://github.com/dgoran/omagestures.git --enable` activates the gestures.
- Three-finger left or right snaps the active window to that half of its monitor's usable area.
- A three-finger up or down gesture within 30 seconds moves the same window to the matching corner.
- Up or down without a valid preceding horizontal gesture does nothing.
- Disabling or removing the plugin unregisters only its four gestures.
- The plugin does not edit Hyprland configuration, reload Hyprland, restart Omarchy Shell, or run a persistent helper process.

## Architecture

Omarchy 4 only activates manifest-backed plugins through Omarchy Shell and does not run install hooks. The plugin therefore retains one headless `service` entry point. Its QML component contains no windows, timers, IPC objects, or child processes that stay alive. Once Omarchy injects the plugin manifest, it invokes a small activation script. Destruction invokes the same script in disable mode.

The activation script sends one Lua program to the running Hyprland instance. That program registers four native gestures and stores sequence state in Hyprland's Lua context. There is no Python helper and no state file.

## Gesture State and Data Flow

The Lua program owns a single state table containing the selected side, the exact `HL.Window` object, its monitor, and an expiration timestamp.

On left or right:

1. Obtain `hl.get_active_window()`.
2. Obtain the window's monitor and usable geometry.
3. Float, resize, and move the window to the selected half.
4. Store the window, side, monitor, and a deadline 30 seconds in the future.

On up or down:

1. Reject missing or expired state.
2. Confirm the stored window and monitor are still usable.
3. Resize and move that stored window to the matching corner.
4. Clear the state so the vertical follow-up is single-use.

Geometry uses the monitor's logical position, size, scale, and reserved edges. Odd dimensions assign the remainder to the right or bottom region so the usable area is fully covered.

## Lifecycle and Failure Handling

Enable first removes matching prior registrations, then registers the four gestures. This makes repeated enable calls safe. Disable removes those same registrations and clears the plugin's Lua state. Failures are contained: a gesture with no active window, monitor, or valid stored window becomes a no-op.

The QML service starts activation once per component instance after `manifest.__sourceDir` is available. Its destruction path requests cleanup. The QML object has no visual surface and does not register Omarchy IPC.

## Files

- `manifest.json`: Omarchy service declaration and updated release version.
- `Service.qml`: minimal Omarchy lifecycle adapter.
- `activate.sh`: enable/disable entry point and embedded Hyprland Lua.
- `README.md`: installation, behavior, requirements, and removal documentation.
- `tests/`: static and mocked runtime tests for the manifest, lifecycle adapter, generated Lua, state behavior, geometry, and idempotent cleanup.
- Remove `snap.py` because Hyprland owns gesture logic and state.

## Verification

- Run Omarchy's `omarchy-plugin-validate` against the repository.
- Run automated tests with a mocked `hyprctl` to inspect enable and disable payloads.
- Parse-check shell code and verify no Python dependency or persistent-state path remains.
- Where a graphical Hyprland session is available, enable twice, exercise all four gesture paths, disable, and confirm the four registrations are gone without shell errors or crashes.

## Compatibility

The implementation targets Omarchy 4 and Hyprland 0.55 or newer, where Lua configuration, runtime evaluation, native gestures, window objects, and Lua dispatchers are available.
