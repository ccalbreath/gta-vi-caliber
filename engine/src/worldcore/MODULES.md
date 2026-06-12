# worldcore native modules

The `worldcore` GDExtension (C++ via godot-cpp) holds the systems where stock
Godot runs out of headroom for a GTA-scale world. Each module follows the same
shape: a **pure, header-only core** (`*_core.h`, free of godot-cpp types) that
unit-tests in the runtime-free C++ harness (`engine/tests/test_worldcore.cpp`),
wrapped by a thin **GDExtension class** (`*.h`/`*.cpp`) that bridges it to
GDScript. The game runs fully without the native build — every consumer
feature-detects with `ClassDB.class_exists(...)` and falls back to GDScript.

Build: `tools/build_engine.sh` (or `scons -C engine target=template_debug`).
Tests: `scons -C engine tests && ./engine/bin/test_worldcore` (61 assertions),
plus per-class GDScript smoke tests under `game/tests/unit/`.

## Modules

| Class | Roadmap | What it does | Key GDScript API |
| --- | --- | --- | --- |
| `WorldCore` | — | Toolchain proof / version probe | `version()` |
| `NativeBench` | — | GDScript-vs-native benchmark baseline | `ping()`, `sum_of_squares(n)` |
| `TileStreamer` | M3 | World tile selection — which tiles should be resident, prioritized by camera velocity, with load/unload **hysteresis** to stop boundary thrash | `desired_tiles(cam, vel)`, `tiles_to_unload(resident, cam)`, `world_to_tile(xz)` |
| `Impostor` | M3 | Distant-building LOD — octahedral view→atlas-cell mapping + screen-size mesh/impostor swap decision | `atlas_cell_for_view(dir)`, `projected_radius_px(r, d)`, `should_impostor(r, d)` |
| `SpatialHash` | M4 | Uniform grid for fast 2D radius/neighbour queries (turns O(n²) all-pairs into ~O(local density)) — the crowd/traffic lookup backbone | `insert(id, xz)`, `query_radius(xz, r)`, `clear()` |
| `CrowdSteering` | M4 | Boids (separation/alignment/cohesion) + goal-seeking (`arrive`) + obstacle avoidance (`avoid`) — pedestrian navigation | `steer(pos, vel, npos, nvel)`, `arrive(pos, vel, target, slow)`, `avoid(pos, obs_pos, obs_radii, margin)` |
| `TrafficModel` | M4 | Intelligent Driver Model car-following — cruise to desired speed, keep a safe time-headway gap, brake when it closes | `acceleration(speed, gap, leader_speed)` |
| `FlowField` | M4 | Dijkstra crowd flow-field — built once per goal over a cost grid (wall = cost < 0), then every agent samples a routing direction around obstacles (no per-agent A*; no diagonal corner-cutting) | `build(w, h, costs, goal)`, `direction_at(xz)`, `is_built()` |

## Runnable demos

- `game/scenes/world/crowd_native_demo.tscn` — a pedestrian crowd flocking toward
  a wandering goal while parting around obstacle pillars (`SpatialHash` +
  `CrowdSteering`). Headless probe: `game/tests/crowd_native_probe.gd`.
- `game/scenes/world/traffic_demo.tscn` — a single-lane ring road of cars
  following each other via `TrafficModel`. Headless probe:
  `game/tests/traffic_demo_probe.gd` (asserts no car ever overlaps).
- `game/scenes/world/flow_field_demo.tscn` — a crowd routing around wall barriers
  to a goal via `FlowField`. Headless probe: `game/tests/flow_field_demo_probe.gd`
  (asserts the crowd reaches the goal and never enters a wall).

## Benchmarks & CI

- `game/tests/native_bench_probe.gd` — `SpatialHash` vs naive GDScript neighbour
  search (~21× faster, fair exact-set comparison).
- `game/tests/crowd_capacity_probe.gd` — crowd capacity at realistic density
  (~4000 agents/step within a 16 ms / 60 FPS budget).
- All probes above run in CI on every engine change (3 platforms) via
  `.github/workflows/engine.yml`, alongside the C++ unit tests
  (`engine/tests/test_worldcore.cpp`).

## Adding a module

1. `src/worldcore/<name>_core.h` — pure logic, header-only, no godot-cpp types.
2. `src/worldcore/<name>.{h,cpp}` — `GDCLASS(... , RefCounted)` wrapper that calls
   the core and converts to/from Godot Variant types.
3. Register it: one `ClassDB::register_class<Name>()` line in `register_types.cpp`.
4. Tests: add `test_<name>_*` cases to `engine/tests/test_worldcore.cpp` (pure
   core) **and** a feature-detecting `game/tests/unit/test_<name>.gd` smoke test.
