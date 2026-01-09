#!/bin/sh
set -eu

ROM_NAME="${ROM_NAME:-game_hud}"
CFG_FILE="nes.cfg"
OUTDIR="build"

ENTRY="${ENTRY:-src/main.s}"
HUD="src/hud.s"

# Optional module (currently empty): only include if file exists AND non-empty
PPU="src/ppu.s"

echo "=== Clean build (modules) ==="
mkdir -p "$OUTDIR"
rm -f "$OUTDIR"/*.o "$OUTDIR"/*.nes

echo "=== Checking inputs ==="
[ -f "$CFG_FILE" ] || { echo "ERROR: missing $CFG_FILE"; exit 1; }
[ -f "$ENTRY" ] || { echo "ERROR: missing ENTRY file: $ENTRY"; exit 1; }
[ -f "$HUD" ] || { echo "ERROR: missing $HUD"; exit 1; }

echo "=== Assembling ==="
ca65 "$ENTRY" -o "$OUTDIR/main.o"
ca65 "$HUD"   -o "$OUTDIR/hud.o"

OBJLIST="$OUTDIR/main.o $OUTDIR/hud.o"

# Only build/link ppu.o if ppu.s exists and is not empty
if [ -s "$PPU" ]; then
  ca65 "$PPU" -o "$OUTDIR/ppu.o"
  OBJLIST="$OBJLIST $OUTDIR/ppu.o"
fi

echo "=== Linking ==="
# shellcheck disable=SC2086
ld65 -C "$CFG_FILE" $OBJLIST -o "$OUTDIR/$ROM_NAME.nes"

echo "=== Success ==="
ls -lh "$OUTDIR/$ROM_NAME.nes"
