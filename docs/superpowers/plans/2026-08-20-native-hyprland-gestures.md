# Native Hyprland Gestures Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the per-gesture Python helper with one native Hyprland Lua runtime while preserving one-command Omarchy activation and clean removal.

**Architecture:** A minimal headless QML service calls `activate.sh` on load and destruction. The script evaluates a namespaced Lua runtime in Hyprland; that runtime registers four gestures, holds one 30-second state record, and performs window dispatches directly.

**Tech Stack:** Omarchy 4 plugin manifest, QML, Bash, Hyprland 0.56 Lua API, Lua test harness

**Spec:** `docs/superpowers/specs/2026-08-20-native-hyprland-gestures-design.md`

## Global Constraints

- One-command activation must remain `omarchy plugin add https://github.com/dgoran/omagestures.git --enable`.
- No Python, persistent state file, Hyprland config edit/reload, extra daemon, visual QML, or plugin IPC target.
- A vertical follow-up is single-use, targets the stored window, and expires after 30 seconds.
- Disable removes only the four exact gestures owned by this plugin.

---

### Task 1: Native gesture runtime

**Files:**
- Create: `tests/run.sh`
- Modify: `activate.sh`
- Delete: `snap.py`

**Interfaces:**
- Consumes: `activate.sh enable|disable`
- Produces: `_G.omagestures` Lua runtime and four three-finger gesture registrations

- [ ] **Step 1: Write failing integration tests**

Create a fake `hyprctl` that captures evaluated Lua, execute the captured code under Lua with a complete fake `hl` boundary, then assert half snapping, same-window corner snapping, expiration, single use, and disable registration.

- [ ] **Step 2: Run tests and verify RED**

Run: `bash tests/run.sh`
Expected: failure because `activate.sh` still invokes Python and does not provide the native runtime.

- [ ] **Step 3: Implement the minimal runtime**

Replace Python invocation with embedded Lua that registers/unsets the four gestures, computes usable monitor quadrants, stores one state record, and dispatches float/resize/move operations.

- [ ] **Step 4: Run tests and verify GREEN**

Run: `bash tests/run.sh`
Expected: all native-runtime behavior tests pass.

- [ ] **Step 5: Remove the obsolete helper**

Delete `snap.py`, rerun `bash tests/run.sh`, and confirm no tracked runtime references Python.

### Task 2: Lifecycle and package contract

**Files:**
- Modify: `Service.qml`
- Modify: `manifest.json`
- Modify: `tests/run.sh`

**Interfaces:**
- Consumes: Omarchy's injected `manifest.__sourceDir`
- Produces: one enable call per QML instance and one best-effort disable call on destruction

- [ ] **Step 1: Add failing package tests**

Test the plugin with `omarchy-plugin-validate`, validate JSON, syntax-check shell, and lint QML when the installed tool supports it.

- [ ] **Step 2: Run tests and verify RED where lifecycle changes are required**

Run: `bash tests/run.sh`
Expected: version or lifecycle expectations fail before their implementation.

- [ ] **Step 3: Minimize the lifecycle adapter**

Keep only required injected properties, a guarded activation function, and best-effort cleanup; bump the manifest version for the rebuilt runtime.

- [ ] **Step 4: Run tests and verify GREEN**

Run: `bash tests/run.sh`
Expected: all tests and Omarchy validation pass.

### Task 3: User documentation and final verification

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: implemented install, gesture, and removal behavior
- Produces: accurate user-facing instructions and compatibility statement

- [ ] **Step 1: Update documentation**

Document the one-command install, gestures, native Lua architecture, requirements, disable behavior, and removal command without mentioning Python.

- [ ] **Step 2: Run full verification**

Run: `bash tests/run.sh && git diff --check && omarchy-plugin-validate .`
Expected: exit 0 with every behavior and packaging check passing.

- [ ] **Step 3: Review scope**

Run: `git status --short` and `git diff --stat`; confirm changes are limited to the approved plugin rebuild and its design/plan/tests.
