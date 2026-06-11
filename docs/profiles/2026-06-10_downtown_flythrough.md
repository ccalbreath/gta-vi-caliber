# Profile: downtown district flythrough — 2026-06-10

Baseline capture for the M3 streaming work, taken before any tiling/LOD/
impostor systems exist, so later changes have an honest "before".

- **Scene:** `res://scenes/world/districts/downtown_la.tscn` (199 extruded
  OSM buildings, 901 road ribbons, untextured greybox materials)
- **Harness:** `godot --path game --resolution 1280x720 --script res://tests/benchmark.gd`
  — 120 warmup frames, then a 900-frame deterministic two-lap camera path
  (350 m-radius high orbit at 150 m, then 120 m-radius street pass at 12 m).
- **Hardware:** Apple M5 Pro, 64 GB, macOS 25.4, Godot 4.6.3 stable (Metal)

| Metric | Value |
| --- | --- |
| Frames measured | 900 |
| Average | 8.33 ms (120 FPS) |
| Median | 8.33 ms (120 FPS) |
| 95th percentile | 8.33 ms (120 FPS) |
| 99th percentile | 8.33 ms (120 FPS) |
| Worst frame | 8.33 ms (120 FPS) |
| Render CPU p50 / p95 / worst | 0.13 / 0.18 / 0.44 ms |
| Render GPU p50 / p95 / worst | 0.00 / 0.00 / 0.00 ms |
| Peak draw calls/frame | 121 |
| Video memory | 296 MB |
| Objects in frame (last) | 188 |

## Reading

- Wall-clock frame times sit exactly on the 120 Hz refresh: **macOS Metal
  presents vsynced even with `VSYNC_DISABLED`**, so wall deltas measure the
  display, not the engine. Trust the render-server times for cost.
- Render CPU p50 of **0.13 ms** with **121 draw calls** means the current
  district costs ~1.5 % of a 120 FPS frame budget. The district mesher
  already batches well (one mesh per building, ribbons merged).
- GPU timestamps read 0.00 ms — Metal timestamp queries aren't returning
  data in this configuration; treat GPU cost as unmeasured, not free.
- Conclusion for M3: there is no per-district rendering bottleneck yet.
  The streaming work should optimize for **many districts resident at
  once** (memory + load hitches), not per-frame draw cost. The 84.76 ms
  hitch seen in an earlier vsynced run when the district builds points at
  build-time stalls being the first real enemy — measure tile *load*
  hitches, not steady-state FPS.
