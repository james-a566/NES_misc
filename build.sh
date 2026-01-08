#!/bin/sh
set -eu

ROM_NAME="game"
CFG_FILE="nes.cfg"
OUTDIR="build"

# pick which source to build:
SRC_FILE="${1:-src/template_bg.s}"   # default if not provided

echo "=== Clean build ==="
mkdir -p "$OUTDIR"
rm -f "$OUTDIR"/*.o "$OUTDIR"/*.nes

echo "=== Checking inputs ==="
[ -f "$CFG_FILE" ] || { echo "ERROR: missing $CFG_FILE"; exit 1; }
[ -f "$SRC_FILE" ] || { echo "ERROR: missing $SRC_FILE"; exit 1; }

echo "=== Assembling ==="
echo "ca65 $SRC_FILE -o $OUTDIR/main.o"
ca65 "$SRC_FILE" -o "$OUTDIR/main.o"

echo "=== Linking ==="
echo "ld65 -C $CFG_FILE $OUTDIR/main.o -o $OUTDIR/$ROM_NAME.nes"
rm -f "$OUTDIR/$ROM_NAME.nes"
ld65 -C "$CFG_FILE" "$OUTDIR/main.o" -o "$OUTDIR/$ROM_NAME.nes"

echo "=== Output ==="
echo "ROM: $(pwd)/$OUTDIR/$ROM_NAME.nes"
ls -lh "$OUTDIR/$ROM_NAME.nes"
md5 "$OUTDIR/$ROM_NAME.nes" || true
