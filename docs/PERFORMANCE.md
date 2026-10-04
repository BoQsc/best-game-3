# Performance notes

Measured on Windows, NVIDIA GTX 1060 Max-Q, Godot 4.7, renderer
**Compatibility**, vsync disabled.

## How to reproduce

```bash
# frame rate
godot --path . --print-fps --disable-vsync --quit-after 1800 res://node_3d.tscn

# per-pass GPU cost
godot --path . --gpu-profile --disable-vsync --quit-after 1800 res://node_3d.tscn
```

A lightweight in-game log is available too: set
`bestgame/debug/perf_log=true` in `project.godot` and a `[perf]` line is printed
every 2 s with fps, draw calls, node count, physics/process time and memory.

## Headline numbers (this machine)

| State | Steady FPS after `Terrain Ready!` | Streaming |
|---|---|---|
| Initial (Forward+) | ~27-37, dips to 8 | 25-86 |
| After Compatibility + perf pass | **~55-66** | 36-62 |

Steady `[perf]` readings: ~457 draw calls, ~5,000 nodes, physics ~3 ms,
memory ~540 MB.

## What was done (engine-native)

Renderer / settings

- Strict **Compatibility** renderer on desktop, mobile and web
  (`renderer/rendering_method*`), so one build runs everywhere.
- `canvas_items` + `expand` stretch for arbitrary aspect ratios.
- Mobile/web: directional shadow `size` 1024 and `max_distance` 60,
  anisotropic filtering capped at 2x, 3D render scale 0.75, physics 30 Hz,
  `max_fps` 60.
- ETC2/ASTC texture import enabled; 1024 px size cap on oversized textures.

CPU / streaming

- Chunk meshes are generated on worker threads; **collision shape built on the
  worker thread** and the collision body inserted **one per frame**.
- Chunk generation starts are capped at **2 per frame**.
- Vegetation placement is queued and spread over frames (4 per frame).
- Reused raycast query per chunk; cached node lookups (player, wall detector).
- Adaptive render distance: steps down under 30 FPS, back up above 55 FPS.

GPU

- One **shared water plane** instead of one transparent plane per chunk; it
  casts no shadow; cheaper water shader (single normal sample, no metallic).
- Terrain shader: no anisotropic sampling, side triplanar fetches skipped when
  their weight is ~0, textures sampled only when their blend weight is non-zero.
- Terrain chunks receive shadows but do not cast them.
- HUD item previews render once instead of every frame.

## Known remaining costs

- HUD (CanvasItems) is ~1.5-2 ms: the toolbelt (9 slots + 3 previews) plus the
  compass (12 labels). Reducing it means changing the HUD layout.
- ~457 draw calls, mostly per-tree meshes (each tree is a glTF scene).
- Trees are placed by raycast and are individual instances; batching them would
  require a single-mesh tree model.
