# NES Misc — ca65 Playground & Templates

This repository contains NES (6502 / ca65) boilerplate templates, experiments, and reusable modules built while learning NES homebrew development.

The guiding rule of this repo is:

    - Templates stay stable
    - Practice files can be messy
    - Reusable systems get modularized

## Directory Structure

```
.
├── build/                
├── src/
│   ├── main.s            
│   ├── main_no_hud.s     
│   ├── hud.s             
│   ├── template_bg.s     
│   ├── template_sprite.s
│   ├── practice_02.s     
│   └── ppu.s             
├── nes.cfg               
├── build.sh              
├── build_hud.sh          
└── README.md
```
### Notes

- `build/` — output ROMs and object files  
- `src/main.s` — HUD-enabled main entry  
- `src/main_no_hud.s` — baseline main without HUD  
- `src/hud.s` — HUD module (score, lives, labels)  
- `template_bg.s` — background + sprite boilerplate  
- `build.sh` — non-HUD build script  
- `build_hud.sh` — HUD-enabled build script  


## Build Scripts

### build.sh — Non-HUD Builds

Builds a single-file entry with no HUD dependencies.

Default entry file:
src/main_no_hud.s

Run:
./build.sh

Override the entry file:
ENTRY=src/practice_02.s ./build.sh

Use this script for:

- Templates

- Experiments

- Files that do not import HUD symbols

### build_hud.sh — HUD Builds
build_hud.sh — HUD Builds

Default entry file:
src/main.s

Run:
./build_hud.sh

Use this script only when HUD symbols are imported.

## HUD Module (hud.s)
The HUD is implemented as a self-contained module that provides:

- Static labels (SCORE, LIVES)

- 4-digit packed BCD score rendering

- Single-digit lives display

- Dirty-flag-based updates

- NMI-safe VRAM writes

### Integration Requirements

During initialization (rendering OFF or during vblank):

jsr HUD_DrawStatic


Inside NMI:

jsr HUD_NMI


When score changes:

jsr HUD_IncScore


The HUD handles all VRAM writes internally.

## Graphics / CHR Notes

- CHR-ROM is 8KB

- Tile indices are manually managed

- Digits and letters are stored as 1bpp tiles

- Background text uses nametable writes

- Sprites use OAM

- HR is padded explicitly to ensure predictable tile indices.


## Project Status
This repository is intentionally a learning playground:

- Boilerplate templates are kept stable

- Practice files are allowed to evolve freely

- Systems are extracted into modules once understood

- As understanding improves, experiments are promoted into reusable templates.
