# Asset policy & provenance ledger

One illegitimate asset can poison the entire project. These rules are strict
because they have to be.

## The rules

1. **Original work, CC0, or CC-BY only.** No exceptions, no "temporary"
   rips, no AI generations prompted to imitate a specific copyrighted work.
   Content from any Grand Theft Auto product (or any other commercial game)
   is banned outright — models, textures, audio, fonts, logos, map layouts.
2. **Every asset has a ledger row** (below) added in the same PR that adds
   the file. PRs with unledgered binaries are closed.
3. **CC-BY attribution** is collected in this file and shipped in the game's
   credits screen.
4. **Size:** nothing over 50 MB per file. Source files (.blend, .psd) stay
   out of the repo unless they are the canonical editable original and under
   the cap; prefer linking a source archive in the ledger.
5. Binary formats route through **Git LFS** automatically via
   `.gitattributes` — verify with `git lfs status` before pushing.
6. Use the **Asset submission** issue template before producing large work,
   so style direction is agreed first (see style notes below).

## Style direction (short version)

Sun-bleached contemporary coastal city: saturated daylight, neon-wet nights,
worn concrete + stucco + palms. Realistic proportions; the stylization budget
is spent on lighting and color rather than shapes. Study reference goes in
`reference/` (gitignored — **never** commit study footage; see
`reference/README.md`).

## AI-generated assets

Allowed only if: the generator's terms permit redistribution under CC BY 4.0,
the prompt did not target a specific artist/game/franchise, and the ledger
row marks it `AI (<tool>)`. Maintainers may reject anything that looks too
close to existing commercial work regardless of provenance.

### PBR material sets (the texture → game-ready pipeline)

A generated *image* is not yet a material. The drop-in convention that turns an
AI texture set into a correctly-wired `StandardMaterial3D` is:

```
game/assets/materials/<name>/
  albedo.png      # base color (sRGB)
  normal.png      # tangent-space normal map (optional)
  roughness.png   # grayscale, red channel (optional)
  metallic.png    # grayscale, red channel (optional)
  ao.png          # grayscale ambient occlusion (optional)
  emission.png    # emissive mask (optional)
```

Build it in code with `PbrMaterial.from_set("res://assets/materials/<name>")`
(`scripts/world/pbr_material.gd`) — missing maps are skipped, and `triplanar`
is available for large surfaces (ground/terrain). This is what a contributor or
agent should call after a GPT-image → texture-set step, so generated assets
render consistently instead of each one being hand-configured. Every map still
needs a ledger row and must be original (not an imitation of a specific work).

## Provenance ledger

| Path | Description | Author | Source | License |
| --- | --- | --- | --- | --- |
| `game/icon.svg` | Project icon (sun over road) | project contributors | original | CC BY 4.0 |
| `game/assets/textures/skin_albedo.png` | Tileable photoreal human-skin albedo for the character skin material (close-up pores/tone; no face, no franchise) | AI (OpenAI Codex image gen) | original — generic prompt | CC BY 4.0 |
| `game/assets/textures/denim.png` | Tileable indigo denim fabric albedo (character trousers) | AI (OpenAI Codex image gen) | original — generic prompt | CC BY 4.0 |
| `game/assets/textures/cotton.png` | Tileable heather-grey cotton-jersey albedo (character shirts; tinted per character) | AI (OpenAI Codex image gen) | original — generic prompt | CC BY 4.0 |
| `game/assets/textures/leather.png` | Tileable worn leather-hide albedo (jackets) | AI (OpenAI Codex image gen) | original — generic prompt | CC BY 4.0 |
| `game/assets/textures/asphalt_albedo.png` | Tileable weathered dark-asphalt road albedo (aggregate + faint cracks/oil; no markings) — modulates the procedural road shader | AI (OpenAI Codex imagegen) | original — generic prompt | CC BY 4.0 |
| `game/assets/characters/char_hunyuan.glb` | **EVALUATION ONLY — license review pending.** 3D character mesh image-to-3D'd from the Codex/GPT character reference via the Hunyuan3D-2 HF space. Untextured/unrigged proof-of-concept for the GPT-image→3D pipeline. Do NOT ship until re-generated under a permissive model (e.g. TRELLIS, MIT) or relicensed. | AI (Hunyuan3D-2, from OpenAI Codex image) | tencent/Hunyuan3D-2 (Hugging Face) | ⚠️ Tencent Hunyuan license — NOT yet CC-BY-4.0-cleared |
| `game/assets/characters/char_textured.glb` | **EVALUATION ONLY — license review pending.** The Hunyuan3D mesh with the Codex/GPT photoreal character reference projected on as albedo (Blender front-projection + rembg edge-extend). Drives the preview scene `scenes/world/char3d_preview.tscn`. Unrigged. | AI (Hunyuan3D-2 mesh + OpenAI Codex image texture) | tencent/Hunyuan3D-2 + OpenAI Codex | ⚠️ Hunyuan license — NOT yet CC-BY-4.0-cleared |
| `game/assets/characters/mara_three_proxy.glb` | Original Three.js-authored Mara playable proxy mesh with named PBR materials, used as the current Godot main-character imported visual while production retopo/rigging is pending. | project contributors | original — `tools/three_mara_modeler/export_mara_proxy.mjs` | CC BY 4.0 |
| `game/assets/characters/mara_three_rigged_proxy.glb` | Original Three.js-authored Mara rigged prototype with named skeleton bones and skinned proxy meshes, used to validate the production rigging path before replacing the playable visual. | project contributors | original — `tools/three_mara_modeler/export_mara_rigged_proxy.mjs` | CC BY 4.0 |
| `game/assets/buildings/florida_landmark_pack.glb` | Original Three.js-authored Florida-inspired landmark and coastal building prop pack with modular hotel, condo, route sign, palms, and promenade lights for the playable state backdrop. | project contributors | original — `tools/three_mara_modeler/export_florida_landmark_pack.mjs` | CC BY 4.0 |
| `game/assets/buildings/florida_city_block_pack.glb` | Original Three.js-authored premium Florida city-block prop pack with glass towers, balcony condo, deco retail hotel, rooftop machinery, street lights, palms, road plate, and storefront lighting. | project contributors | original — `tools/three_mara_modeler/export_florida_city_block_pack.mjs` | CC BY 4.0 |
| `game/assets/buildings/florida_neon_detail_pack.glb` | Original Three.js-authored Florida neon detail pack with wet-street reflection strips, boutique hotel canopy, rooftop sign, storefront row, art light poles, and glowing pool deck. | project contributors | original — `tools/three_mara_modeler/export_florida_neon_detail_pack.mjs` | CC BY 4.0 |
| `game/assets/buildings/florida_regional_pack.glb` | Original Three.js-authored regional Florida destination pack with container port, airport apron, wetland boardwalk, keys resort pier, and space-coast launch pad modules. | project contributors | original — `tools/three_mara_modeler/export_florida_regional_pack.mjs` | CC BY 4.0 |
| `game/assets/buildings/florida_infrastructure_pack.glb` | Original Three.js-authored Florida infrastructure prop pack with toll plaza, coastal fuel stop, lifeguard beach access, wetland airboat dock, route gantry, utility poles, and roadside palms. | project contributors | original — `tools/three_mara_modeler/export_florida_infrastructure_pack.mjs` | CC BY 4.0 |
| `game/assets/buildings/florida_environment_pack.glb` | Original Three.js-authored Florida environmental detail prop pack with beach dunes, sea oats, mangrove clusters, roadside planters, market kiosks, benches, bins, cones, and trail wayfinding signs. | project contributors | original — `tools/three_mara_modeler/export_florida_environment_pack.mjs` | CC BY 4.0 |
| `game/assets/buildings/florida_traffic_marine_pack.glb` | Original Three.js-authored Florida traffic and marine set dressing pack with parked cars, scooters, box truck, trailer boat, speedboats, jet skis, patrol boat, buoys, and dock bollards. | project contributors | original — `tools/three_mara_modeler/export_florida_traffic_marine_pack.mjs` | CC BY 4.0 |
| `game/assets/buildings/florida_vista_pack.glb` | Original Three.js-authored Florida signature vista and atmosphere pack with overlook decks, boardwalk pergolas, viewfinders, route monument, launch beacon, Gulf art pier, and premium micro-lighting. | project contributors | original — `tools/three_mara_modeler/export_florida_vista_pack.mjs` | CC BY 4.0 |
| `game/assets/buildings/florida_streetlife_pack.glb` | Original Three.js-authored Florida streetlife and nightlife prop pack with boutique storefronts, rooftop lounge, outdoor dining, club entry, market stalls, planters, benches, and premium micro-lighting. | project contributors | original — `tools/three_mara_modeler/export_florida_streetlife_pack.mjs` | CC BY 4.0 |
| `game/assets/map/florida_full_map.png` | 3840x2160 full-screen Florida state map render, including the Florida Keys, generated from official state boundary geometry without non-uniform stretch | project contributors, derived from U.S. Census Bureau data | https://www2.census.gov/geo/tiger/GENZ2024/shp/cb_2024_us_state_500k.zip | CC0-compatible public domain (U.S. Census Bureau) |
| `game/assets/map/florida_full_map.svg` | Editable SVG source for the full-screen Florida state map render | project contributors, derived from U.S. Census Bureau data | https://www2.census.gov/geo/tiger/GENZ2024/shp/cb_2024_us_state_500k.zip | CC0-compatible public domain (U.S. Census Bureau) |
| `game/assets/world/downtown_la.json` | Building footprints/heights + road centerlines for the downtown district, extracted via `tools/osm/fetch_district.py` | © OpenStreetMap contributors | https://www.openstreetmap.org/copyright | ODbL 1.0 (data only; attribution embedded in file and credits) |
| `game/assets/world/*.json` (18 districts + `districts.json` index) | Building footprints/heights + road centerlines for the LA-region districts (venice_beach, santa_monica, hollywood, …), same extractor | © OpenStreetMap contributors | https://www.openstreetmap.org/copyright | ODbL 1.0 (data only; attribution embedded in each file and credits) |
| `game/assets/characters/player_male_01/` | Player character: Universal Base Characters (Standard) "Superhero Male" glTF base mesh + "Simple Parted" rigged hairstyle + PBR textures, ~15.6k tris total, 65-joint humanoid rig. Two broken texture URIs in the upstream body .gltf fixed (`*_png.png` → `*.png`) | Quaternius | https://quaternius.com/packs/universalbasecharacters.html | CC0 1.0 |
| `game/assets/characters/universal_animations/` | Universal Animation Library (Standard) GLB: 45 humanoid clips (idle/walk/jog/sprint/jump/land + extras), same rig as the base characters, shared by player & future NPCs | Quaternius | https://quaternius.com/packs/universalanimationlibrary.html | CC0 1.0 |
| `game/addons/gdUnit4/src/core/assets/touch-button.png` | Vendored gdUnit4 editor-plugin UI icon | godot-gdunit-labs | https://github.com/godot-gdunit-labs/gdUnit4/tree/v6.1.3/addons/gdUnit4 | MIT |
| `game/addons/gdUnit4/src/reporters/html/template/css/logo.png` | Vendored gdUnit4 report logo | godot-gdunit-labs | https://github.com/godot-gdunit-labs/gdUnit4/tree/v6.1.3/addons/gdUnit4 | MIT |
| `game/addons/gdUnit4/src/ui/settings/logo.png` | Vendored gdUnit4 editor-plugin logo | godot-gdunit-labs | https://github.com/godot-gdunit-labs/gdUnit4/tree/v6.1.3/addons/gdUnit4 | MIT |
| `game/addons/gdUnit4/src/update/assets/border_bottom.png` | Vendored gdUnit4 editor-plugin UI image | godot-gdunit-labs | https://github.com/godot-gdunit-labs/gdUnit4/tree/v6.1.3/addons/gdUnit4 | MIT |
| `game/addons/gdUnit4/src/update/assets/border_top.png` | Vendored gdUnit4 editor-plugin UI image | godot-gdunit-labs | https://github.com/godot-gdunit-labs/gdUnit4/tree/v6.1.3/addons/gdUnit4 | MIT |
| `game/addons/gdUnit4/src/update/assets/dot1.png` | Vendored gdUnit4 editor-plugin UI image | godot-gdunit-labs | https://github.com/godot-gdunit-labs/gdUnit4/tree/v6.1.3/addons/gdUnit4 | MIT |
| `game/addons/gdUnit4/src/update/assets/dot2.png` | Vendored gdUnit4 editor-plugin UI image | godot-gdunit-labs | https://github.com/godot-gdunit-labs/gdUnit4/tree/v6.1.3/addons/gdUnit4 | MIT |
| `game/addons/gdUnit4/src/update/assets/embedded.png` | Vendored gdUnit4 editor-plugin UI image | godot-gdunit-labs | https://github.com/godot-gdunit-labs/gdUnit4/tree/v6.1.3/addons/gdUnit4 | MIT |
| `game/addons/gdUnit4/src/update/assets/horizontal-line2.png` | Vendored gdUnit4 editor-plugin UI image | godot-gdunit-labs | https://github.com/godot-gdunit-labs/gdUnit4/tree/v6.1.3/addons/gdUnit4 | MIT |

*(Append one row per asset. Path relative to repo root. "Source" is `original`
or a URL. License must be CC0, CC-BY-4.0, or CC-BY-4.0-compatible. Exception:
**geodata** — factual map data such as OpenStreetMap extracts is accepted under
ODbL 1.0; it must keep its attribution embedded in the file, get a credits-screen
entry, and stay in `game/assets/world/`. ODbL share-alike applies to the data
files themselves, not to the game's code or rendered output. Vendored
`game/addons/**` plugin UI assets may use the upstream plugin license.)*
