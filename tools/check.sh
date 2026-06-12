#!/usr/bin/env bash
# Local CI gate — runs exactly what .github/workflows/ci.yml runs.
# Usage:
#   tools/check.sh          # check everything
#   tools/check.sh --fix    # auto-format first, then check everything
set -euo pipefail
cd "$(dirname "$0")/.."

FIX=0
if [[ "${1:-}" == "--fix" ]]; then
    FIX=1
fi

# --- locate godot ------------------------------------------------------------
GODOT_BIN="${GODOT:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
    if [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
        GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
    else
        echo "error: Godot not found. Install Godot 4.6+ (docs/BUILDING.md) or set GODOT=/path/to/godot" >&2
        exit 1
    fi
fi

require() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "error: '$1' not found. Install gdtoolkit:  pipx install \"gdtoolkit==4.*\"" >&2
        exit 1
    fi
}

step() { printf '\n==> %s\n' "$1"; }

GD_DIRS=(game/scripts game/tests)

# --- 1. format ---------------------------------------------------------------
require gdformat
if [[ "$FIX" == 1 ]]; then
    step "gdformat (fixing)"
    gdformat "${GD_DIRS[@]}"
else
    step "gdformat --check"
    gdformat --check "${GD_DIRS[@]}"
fi

# --- 2. lint -----------------------------------------------------------------
require gdlint
step "gdlint"
gdlint "${GD_DIRS[@]}"

# --- 3. headless import (validates project.godot, scenes, resources) ---------
step "headless import"
"$GODOT_BIN" --headless --path game --import

# --- 4. smoke test (main scene boots, player rig present) --------------------
step "smoke test"
"$GODOT_BIN" --headless --path game --script res://tests/smoke_test.gd

# --- 5. gdUnit4 unit tests ----------------------------------------------------
step "gdUnit4 unit tests"
"$GODOT_BIN" --headless --path game --script res://tests/run_tests.gd

printf '\nAll checks passed ✔\n'
