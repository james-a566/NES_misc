# NES Boilerplate Templates (ca65)

A small collection of clean, known-good NES boilerplates for learning and reuse.

## Templates

- `template_bg.s`
  - Background + sprites enabled
  - Clears nametable 0 to tile 0
  - Bright background, high-contrast test sprite
  - D-pad moves sprite
  - Good for testing BG + VRAM logic

- `template_sprite.s`
  - Sprite-only rendering (BG off)
  - Minimal VRAM usage
  - D-pad moves sprite
  - Ideal starting point for arcade-style games (e.g. Dodgefall)

## Build

```sh
./build.sh                # build background template
./build.sh src/template_sprite.s
