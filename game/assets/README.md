# game/assets/

Assets are organized by **what they are in the game**, not by file type —
when 50 artists contribute, "where does a palm tree go?" must have one
obvious answer.

| Folder | What goes here |
| --- | --- |
| `characters/` | Character models, rigs, animations (player, pedestrians, police) |
| `buildings/` | Architecture: building models, facades, interiors |
| `vehicles/` | Cars, bikes, boats — bodies, wheels, interiors |
| `props/` | Street furniture, crates, signs, vegetation pots, small objects |
| `environment/` | Terrain, foliage, water, sky, roads, shoreline |
| `ui/` | HUD icons, fonts, menu art |
| `audio/` | Music and SFX (.ogg preferred), mirrored by category subfolders |
| `materials/` | Shared `.tres` materials and shaders used across categories |
| `textures/` | Shared/tiling textures (concrete, asphalt…); one-off textures live next to their model |

Inside each category, group per asset: `characters/cop_female_01/` holds the
.glb, its textures, and animation files together.

Before adding anything, read [docs/ASSETS.md](../../docs/ASSETS.md):
**every asset needs a provenance ledger row in the same PR**, and only
original / CC0 / CC-BY work is accepted. Keep files under 50 MB —
binaries route through Git LFS automatically.

Naming: `snake_case`, prefixed by category when helpful
(`veh_sedan_body.glb`, `amb_shore_waves_loop.ogg`).
