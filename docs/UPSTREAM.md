# Upstream candidates & PR log

The project is **upstream-first** (see [VISION.md](VISION.md)): anything in
`engine/` (the `worldcore` GDExtension) that is *generically* useful — not
specific to this game — should be offered back to Godot rather than hoarded. This
file is the catalogue of candidates and the log of what's actually been
submitted. It is the named M-track deliverable: *"Upstream PR log in
`docs/UPSTREAM.md`"*.

A module is a good upstream candidate when it solves a problem **any** Godot
project of this kind hits, has a small clean API, and carries no game-specific
assumptions. Pure-core modules (`*_core.h`) are the strongest candidates because
the math is already isolated from this game's types.

## Candidates

| Module | Upstream value | Notes |
| --- | --- | --- |
| `SpatialHash` | **High** | A uniform 2D spatial hash for radius/neighbour queries is a near-universal need (crowds, AoE queries, proximity). Tiny API, zero game assumptions. Closest to a drop-in `Godot` utility. |
| `Impostor` (octahedral encode + screen-size LOD) | **High** | Octahedral direction→atlas mapping and projected-screen-radius LOD selection are generic rendering utilities; useful to anyone doing impostor/billboard LOD. |
| `CrowdSteering` (boids + arrive + avoid) | **Medium** | Classic steering behaviours are broadly useful, but Godot has `NavigationAgent`; upstream value is the lightweight non-nav flocking core. |
| `TileStreamer` | **Medium** | Velocity-prioritized tile selection + load/unload hysteresis is reusable by any streaming-world game, but "what a tile *is*" varies per project — upstream the *selection math*, not a node. |
| `TrafficModel` (IDM) | **Low–Medium** | The Intelligent Driver Model is standard and generic, but narrower in audience (traffic/vehicle sims). Good as an example/community asset. |
| `WorldCore`, `NativeBench` | **None** | Internal scaffolding (version probe, benchmark baseline) — not upstream material. |

## How to propose upstream

1. Open a **proposal** at `godotengine/godot-proposals` describing the generic
   need (not "for our GTA-like"), with the small API surface.
2. If accepted in principle, port the `*_core.h` logic into a Godot module / core
   util PR against `godotengine/godot`, with its own tests in Godot's style.
3. Log the PR in the table below and link it from the module's header comment.

## Submitted PRs

_None yet._ The native modules are new (M3/M4 engine track); this catalogue is
the pre-work so the first generically-useful piece (most likely `SpatialHash`)
can be offered upstream once it has soaked in-game. Add a row here with the first
submission:

| Module | Proposal | PR | Status |
| --- | --- | --- | --- |
| — | — | — | — |

See [`engine/src/worldcore/MODULES.md`](../engine/src/worldcore/MODULES.md) for
the full module reference.
