# Profile: Miami district streaming Phase 2 - 2026-06-13

Comparison for the GDScript-first Phase 2 implementation from
[upstream issue #53](https://github.com/duolahypercho/gta-vi-caliber/issues/53).

- **Base:** `0c343fb` (`optimisation`)
- **Implementation:** `8d37f94`
- **Scene:** `res://scenes/world/miami.tscn`
- **Hardware:** Apple M3 Pro (12 CPU cores), 18 GB, macOS 26.2
  (25C56), Godot 4.6.3 stable (Metal)
- **Quality:** Medium, 1600x900, 0.85 render scale, FSR2
- **Benchmark command:**
  `GTA_QUALITY=medium godot --path game --resolution 1600x900 --script res://tests/benchmark.gd`
- **Streaming command:**
  `godot --headless --path game --script res://tests/streaming_route_probe.gd`

## Steady-state benchmark

Both captures use the benchmark harness's 120 warmup frames and 900 measured
frames.

| Metric | Base | Phase 2 |
| --- | ---: | ---: |
| Average | 25.25 ms (40 FPS) | 19.07 ms (52 FPS) |
| Median | 22.22 ms (45 FPS) | 19.05 ms (52 FPS) |
| 95th percentile | 41.67 ms (24 FPS) | 19.70 ms (51 FPS) |
| 99th percentile | 52.78 ms (19 FPS) | 19.82 ms (50 FPS) |
| Worst frame | 134.25 ms (7 FPS) | 21.48 ms (47 FPS) |
| Render CPU p50 / p95 / worst | 1.82 / 3.00 / 13.11 ms | 1.70 / 2.82 / 4.37 ms |
| Peak draw calls/frame | 7850 | 7885 |
| Video memory | 3094 MB | 1791 MB |
| Objects in frame (last) | 4011 | 1827 |

Average frame time improved by about 24%, p95 by about 53%, and video memory
fell by about 42%. Draw calls stayed effectively flat while the active object
and memory footprint dropped substantially.

Metal GPU timestamps returned `0.00 ms` in both captures, so GPU time is
unmeasured rather than free.

## Boundary route

The automated route moves downtown -> Wynwood -> downtown, forcing repeated
district unload/reload crossings. The `tools/check.sh` run recorded:

| Metric | Value |
| --- | ---: |
| First resident tile | 4753.8 ms |
| Worker preparation | 3993.8 ms |
| Maximum tile commit | 1.18 ms (`tile_collision`) |
| Maximum operation | 1.18 ms (`tile_collision`) |
| Peak operations in one frame | 1 |
| District loads / unloads | 5 / 3 |
| Final resident / total tiles | 8 / 179 |

Two standalone route repeats measured maximum tile commits of 0.30 ms and
0.39 ms. The 1.18 ms full-check result was captured while the complete test
suite was running and remains close to the approximate 1 ms target. No
streaming operation approached the 50 ms hitch ceiling.

## Reading

- District JSON parsing, projection, mesh arrays, collision batches,
  navigation polygons, facade transforms, and rooftop transforms are prepared
  on worker threads.
- Each physics frame performs at most one district load/unload or staged tile
  commit. Collision and navigation use fixed-size incremental batches.
- Detailed render, collision, navigation, facades, and props stay in the near
  ring. Distant tiles use simplified building HLOD plus occluders.
- District residency is restored to the measured 1600 m load / 2400 m unload
  radii, with velocity-aware load ordering.
