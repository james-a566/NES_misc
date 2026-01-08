#!/bin/sh
set -eu

ROM_NAME="game"
CFG_FILE="nes.cfg"
SRC_FILE="template.s"   # <-- change this if your main file is named differently
OUTDIR="build"

echo "=== Clean build ==="
mkdir -p "$OUTDIR"
rm -f "$OUTDIR"/*.o "$OUTDIR"/*.nes

echo "=== Checking inputs ==="
[ -f "$CFG_FILE" ] || { echo "ERROR: missing $CFG_FILE"; exit 1; }
[ -f "$SRC_FILE" ] || { echo "ERROR: missing $SRC_FILE (edit SRC_FILE in build.sh)"; exit 1; }

echo "=== Assembling ==="
echo "ca65 $SRC_FILE -o $OUTDIR/main.o"
ca65 "$SRC_FILE" -o "$OUTDIR/main.o"

echo "=== Linking ==="
echo "ld65 -C $CFG_FILE $OUTDIR/main.o -o $OUTDIR/$ROM_NAME.nes"
ld65 -C "$CFG_FILE" "$OUTDIR/main.o" -o "$OUTDIR/$ROM_NAME.nes"

echo "=== Success ==="
ls -lh "$OUTDIR/$ROM_NAME.nes"
