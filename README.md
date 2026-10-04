# Best Game 3

Horror FPS built in Godot 4.7 on GPU marching-cubes terrain.

## Features

- Marching-cubes terrain with chunked streaming
- First-person controller (WASD)
- Zombies, digging/mining, props and prefabs
- Intro sequence with custom UI

## Run

Open the project in Godot 4.7. Main scene: `Intro.tscn`.

Renderer: **Compatibility** (OpenGL 3.3 / WebGL 2) on every platform, so the
same build runs on desktop, mobile, web and low-end hardware.

## Controls

- **Desktop:** WASD to move, mouse to look, `Space` to jump/swim up,
  `Esc` to release/recapture the mouse, `1`-`9` or mouse wheel to switch slots.
- **Touch (mobile / touch web):** hold the **left half** of the screen to walk,
  hold the **right half** to jump/swim up, drag anywhere to look around.

## Platforms

Export presets are included (`export_presets.cfg`): **Web**, **Windows
Desktop** and **Android**. Exporting needs the matching Godot export templates
installed (`Editor > Manage Export Templates`).

Cross-platform notes:

- Textures are imported with VRAM compression (SCTE/BPTC for desktop,
  ETC2/ASTC for mobile and web).
- Chunk generation runs on worker threads on desktop, and inline on web
  (single-threaded export).
- Shadow size, anisotropic filtering and HUD preview passes are kept cheap for
  low-end and mobile GPUs.

## Checks

`.github/workflows/godot-checks.yml` imports the project and parses every
GDScript with Godot 4.7 headless on push/PR.

Locally the same can be run as:

```
godot --headless --path . --import
godot --headless --path . --check-only --script res://Zombie.gd
```

## Names & history

One and the same game, known by several names over time:

- **Best Game 3** - current canonical name (GitHub: `best-game-3`).
- **sonnet-4.5-marchingcubes** - original local project folder.
- **godot-marchingcubes-horror-fps** - earlier GitHub repository (still kept as git remote `old-origin`).
- **Horror Survival Game (HSG)** - recurring theme across the Best Game series.

## Notes

See `notes.txt` for terrain/tree physics decisions.
