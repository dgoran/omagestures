#!/usr/bin/env bash
set -u

ID="io.github.dgoran.omagestures"
DIR="$HOME/.config/omarchy/plugins/$ID"
INPUT="$HOME/.config/hypr/input.lua"

echo "=== OmaGestures diagnostics ==="
echo

echo "[1] Omarchy plugin list"
omarchy plugin list --json 2>/dev/null | grep -C 3 -F "$ID" || omarchy plugin list 2>/dev/null | grep -F "$ID" || true

echo

echo "[2] Plugin files"
ls -la "$DIR" 2>/dev/null || echo "Plugin directory missing: $DIR"

echo

echo "[3] shell.json enabled state"
grep -n -F "$ID" "$HOME/.config/omarchy/shell.json" 2>/dev/null || echo "Plugin id not found in shell.json"

echo

echo "[4] Gesture block in input.lua"
grep -n -A45 -B2 'BEGIN IO.GITHUB.DGORAN.OMAG' "$INPUT" 2>/dev/null || echo "Gesture block not present"

echo

echo "[5] Hyprland config errors"
hyprctl configerrors 2>&1 || true

echo

echo "[6] Active Hyprland / helper smoke test"
Hyprland --version 2>/dev/null | head -n 4 || true
python3 "$DIR/snap.py" left; echo "snap.py left exit=$?"

echo

echo "[7] Shell status"
omarchy-shell shell ping 2>&1 || true
