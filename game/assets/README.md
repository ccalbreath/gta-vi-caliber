# game/assets/

| Folder | What goes here |
| --- | --- |
| `models/` | 3D models (.glb preferred) |
| `textures/` | Textures (.png/.webp/.exr — auto-routed through Git LFS) |
| `materials/` | Shared `.tres` materials and shaders |
| `audio/` | Music and SFX (.ogg preferred) |

Before adding anything, read [docs/ASSETS.md](../../docs/ASSETS.md):
**every asset needs a provenance ledger row in the same PR**, and only
original / CC0 / CC-BY work is accepted. Keep files under 50 MB.

Naming: `snake_case`, prefixed by category when helpful
(`veh_sedan_body.glb`, `amb_shore_waves_loop.ogg`).
