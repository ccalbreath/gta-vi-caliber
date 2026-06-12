# PLAN — From here to a complete GTA-VI-caliber game

This is the single end-to-end plan: the path from the current build to a
finished, shippable open-world game in the spirit of GTA VI (original IP, Vice
City / Miami setting). It sits **above** [`docs/ROADMAP.md`](docs/ROADMAP.md) —
the roadmap is the live task board (M0–M6); this file is the multi-phase
strategy, the honest scope, and the cut line.

> Steering rule: when this plan and `docs/ROADMAP.md` disagree, fix one of them
> in the same PR. Agents read both. Keep tasks small, concrete, verifiable.

---

## 0. Honest scope — read this first

A *literal* "complete GTA 6" is a ~1000-person, multi-year, nine-figure
production: ~50 hours of bespoke narrative, full voice cast, motion-capture,
licensed radio, online services. We are not pretending to match that headcount.

**What we are actually building**, and what "complete" means here:

- A **finished, coherent, shippable game** — title screen to credits — not a
  tech demo. It has a beginning, a playable middle, and an end.
- **One living coastal city** (Miami / Vice City) streamed seamlessly, dense
  with traffic and crowds, that holds 60 FPS on a mid-range GPU.
- A **6–10 hour critical path**: a story campaign of hand-built missions, plus
  systemic open-world play (heat/police, side jobs, economy, properties) that
  makes the city replayable for far longer.
- **Trailer-grade fidelity within the engine's honest ceiling** (~6–7/10 vs
  the real GTA VI trailer — see [[godot-fidelity-ceiling]]). The gap that
  remains is content volume and hardware ray-tracing, not a missing system.

The acceptance test is unchanged from [`docs/VISION.md`](docs/VISION.md): **a
90-second in-engine trailer captured from a release build that looks like the
game it claims to be**, plus a player completing the campaign start to finish
without falling out of the world.

If a feature does not move us toward that acceptance test, it is out of scope
for v1.0 and goes to the Post-launch section.

---

## 1. Where we are now (state snapshot — 2026-06)

What exists and works (verified by the repo, not aspiration):

- **Playable trunk.** `miami.tscn` is a fully wired playable game loop, each
  step CI-guarded by a runtime probe (`miami_*_probe.gd`): player
  health/stats/wanted/mission/bark, crowd + traffic + police directors, crime →
  wanted → police dispatch, a 5-mission campaign paying money/respect/stats,
  pay-n-spray wanted-clear, busted/arrest fail-loop. See [[miami-playable-and-systems]].
- **A deep systems library** — 40+ pure, unit-tested simulation models (314
  unit tests) catalogued in [`docs/SYSTEMS.md`](docs/SYSTEMS.md): ballistics,
  pursuit, witness, handling, explosions, crowd panic, economy, heists,
  progression, weather, radio. Many are **built and tested but not yet wired**
  into the live scene — see [[sim-systems-library]].
- **Character & traversal.** Third-person locomotion (accel/decel, coyote time,
  jump buffering), collision-probe camera, footstep audio, partial gamepad. A
  premium rigged player (Mara) with a pixel-level capture-gate workflow
  ([[mara-character-capture-and-gating]]).
- **Atmosphere.** Procedural sky + day/night cycle ([[sky-daynight-system]]),
  cinematic environment, facade/window night-lighting, Ocean v1, procedural
  terrain ([[terrain-system]]).
- **World geography.** Causeways + Biscayne Bay islands + palms stitching the
  districts into one continuous Florida map ([[bay-geography-subsystems]]).
- **Engine track.** `engine/` GDExtension (`worldcore`) compiles on all 3
  platforms with C++ tests in CI; godot-cpp vendored as a submodule.
- **The gate.** `tools/check.sh` = CI (format, lint, import, smoke, unit,
  runtime probes). `main` always runs.

What is **deliberately mid-flight on this branch** (`feat/fidelity-engine-sprints`):
the LA → Miami pivot ([[vice-city-pivot]]) — legacy `los_angeles_*` and demo
scenes are being retired; `miami.tscn` is the one canonical world scene.

**Honest gap to "complete":** we have a *vertical slice* of a game (one wired
loop, one district's worth of systems) and a deep parts bin. We do **not** yet
have: streaming at city scale, content *volume* (one district vs a full map; 5
missions vs a campaign), narrative spine, full UI/UX shell, audio/radio
content, save/load durability, and a ship/packaging pipeline.

---

## 2. The shape of the plan

Eight phases. Phases A–C harden and scale what exists; D–F add the content and
play that make it a *game*; G–H polish and ship. They overlap — the engine
track and content track run in parallel with gameplay — but the **exit
criteria** are sequential gates: don't start a phase's polish before its
predecessor's gate is green.

```
A. Stabilize & consolidate ──┐
B. Streaming world at scale ─┼─→ D. Content volume ──→ F. Narrative & play loop ──┐
C. Wire the parts bin ───────┘    E. Life & atmosphere ─┘                          ├─→ G. Polish ──→ H. Ship 1.0
                                                                                    │
   Engine track (worldcore) ───────────── runs throughout ──────────────────────────┘
```

Each phase below lists: **Goal**, **Tasks**, **Exit criteria** (the gate). Map
tasks back to roadmap milestones (M0–M6) where they correspond.

---

## Phase A — Stabilize & consolidate the pivot

*Goal: one clean canonical game, no legacy debt, a green gate on a clean clone.*

The Vice City pivot is half-applied on a feature branch. Finish it so every
later phase builds on solid ground.

- [ ] Land the pivot: retire all `los_angeles_*` / demo scenes, confirm
      `miami.tscn` is the only world entry point, update `docs/PIVOT_TO_MIAMI.md`.
- [ ] `main_menu` Play → `miami.tscn` (not the old sandbox) end to end.
- [ ] Resolve the open `LOOP_HANDOFF.md` items: gamepad **button** bindings in
      `project.godot`; rebindable-input persistence layer; route premium
      lighting (`CinematicEnvironment.enhance`) into the gameplay scene **gated
      behind a quality setting** (it was reverted on a 120→54 FPS perf hit — ship
      it for the dense district only, with a measured budget).
- [ ] Vendor gdUnit4 and port the unit runner (open M0 box) — or formally
      decide the current `run_tests.gd` harness is the standard and close it.
- [ ] CI builds + uploads Linux/Win/macOS artifacts on tag (confirm M0 box).

**Exit gate:** fresh clone → `tools/check.sh` green → `main_menu` → play the
full miami loop → quit, with zero references to retired scenes.

---

## Phase B — Streaming world at city scale  *(roadmap M3, engine track)*

*Goal: walk or drive ≥4 km in any direction with no loading screen, 60 FPS.*

This is the single biggest engineering risk and the thing that separates "a
level" from "an open world." It is the engine track's main event.

- [ ] World partitioned into tiles with seam-free LOD terrain.
- [ ] `engine/worldcore`: **async tile streamer** — load/unload around the
      camera, priority by velocity vector. Profile first; this is the proven
      case for native code.
- [ ] `engine/worldcore`: **runtime impostor baker** for distant buildings.
- [ ] Floating-origin shift at distance (confirm the existing implementation
      holds across the full map).
- [ ] Streaming debug HUD: tiles resident, VRAM, frame budget.
- [ ] Benchmark scene + captured profile checked into `docs/profiles/`,
      regression-gated.

**Exit gate:** a benchmark run drives a fixed 4 km transect of the full map
holding ≥60 FPS @ 1080p mid-range, no hitch > one frame budget on tile loads,
profile committed.

---

## Phase C — Wire the parts bin  *(roadmap M5, content of SYSTEMS.md)*

*Goal: every built-and-tested system is reachable in play, not just unit-tested.*

We have 40+ tested models; most are dark. This phase is mostly **integration,
not invention** — follow the self-wiring-coordinator pattern in
[`docs/SYSTEMS.md`](docs/SYSTEMS.md) (copy `MissionReward` / `PaySprayShop`).

- [ ] Combat wired live: `WeaponBallistics`, `ExplosionModel`, `MeleeCombat`,
      `CombatCover`, `StealthDetection`, `FirePropagation`.
- [ ] Vehicles: `VehicleHandling` drift, `VehicleHealth` → wreck → explosion,
      `VehicleModShop`, `Carjacking`, `GarageStorage`, `Parachute`.
- [ ] World-alive: `TrafficSignal` at junctions, `PedestrianTraffic` dodging,
      `EmergencyServices` dispatch, `WeatherEffects` feeding handling + AI sight.
- [ ] Economy/progression: `ShopModel`, `PropertyOwnership`, `ContrabandMarket`,
      `CasinoGames`, `PlayerProgression`, `StatTracker` (some already live).
- [ ] Police depth: `PoliceEscalation` tiers → SWAT/heli/military spawns,
      `PursuitTactics`, `GangTerritory` turf.
- [ ] Each newly wired system gets a runtime probe in `check.sh` like the
      existing `miami_*_probe` set — wiring without a probe doesn't count.

**Exit gate:** every system in `docs/SYSTEMS.md` is either wired-with-a-probe or
explicitly marked "v1.0 cut" with a reason. No silent dead systems.

---

## Phase D — Content volume  *(the long pole; roadmap M4 scaled up)*

*Goal: a full map, not one block; enough hand-built places to fill 6–10 hours.*

This is where a vertical slice becomes a game, and it is the **largest sustained
effort** in the plan. It is content production, parallelizable across agents.

- [ ] **The full Miami map**: 4–6 districts (downtown / South Beach / Little
      Havana / port / suburbs / keys), each with distinct silhouette, road
      layout, landmarks. Blockout → greybox → art pass per district.
- [ ] A **true road-graph** (OSM-style) replacing the baked walkability grid for
      traffic routing (the known M4 TODO).
- [ ] Interiors that matter: safehouses, shops, mission interiors, garages.
- [ ] Asset library scaled: building kit-of-parts, props, vehicle roster
      (currently a tuned mix — expand variety), pedestrian wardrobe.
- [ ] Original-asset provenance tracked in [`docs/ASSETS.md`](docs/ASSETS.md)
      for every file (hard rule — see [[codex-asset-generation]] for the
      texture pipeline).
- [ ] Map UI: minimap + full pause-map with streamed POIs (M5 box).

**Exit gate:** the whole map is drivable district-to-district seamlessly; a
fixed "grand tour" capture shows distinct, populated, lit districts with no
placeholder geometry on the critical path.

---

## Phase E — Life & atmosphere  *(roadmap M4/M6)*

*Goal: the city feels inhabited and worth screenshotting at any hour.*

Runs in parallel with D (different agents, different files).

- [ ] Crowds route *through* `NavGrid.find_path` (not straight wander) now that
      buildings are solid; add the gawk reaction (flee already exists).
- [ ] Traffic on the real road-graph; signals, intersections, jams.
- [ ] Weather fronts: clear → overcast → rain with wet-surface materials,
      feeding `WeatherEffects` into gameplay.
- [ ] Ocean v2: foam, wakes, buoyancy (engine candidate).
- [ ] Night-lighting pass per district; volumetrics tuned (the soup bug is
      fixed — keep it gated by time-of-day and quality setting).
- [ ] GPU-driven crowd density pass (engine track) once profiled.

**Exit gate:** day/night + weather capture set across all districts reads as
"alive" — reactive crowds, flowing traffic, screenshot-worthy night.

---

## Phase F — Narrative & the complete play loop  *(roadmap M5)*

*Goal: it has a story, a start, and an ending — a player can finish it.*

Systems give replayability; a **spine** gives it a reason to exist.

- [ ] **Mission framework hardened**: triggers, objectives, fail/retry,
      checkpoints, cutscene hooks (the 5-mission campaign is the seed —
      `MissionChain`/`MissionCampaign`).
- [ ] **The campaign**: a 15–30 mission story arc with a protagonist, a small
      cast, an opening and a finale (a heist, wiring `HeistCrew`). Scripted
      barks/dialogue; mocap is out of scope — use procedural + keyframe.
- [ ] Side content: taxi/delivery/vigilante (`SideJob`), street races
      (`StreetRace`), properties, collectibles — the open-world filler.
- [ ] **Radio**: streaming music channels in vehicles (`RadioScheduler` +
      CC-licensed tracks), DJ/ad/news programming.
- [ ] **Save/load** of world + player + mission state, durable across versions.
- [ ] Full UI/UX shell: title, settings, pause, map, phone
      ([[phone-system]]), HUD ([[game-hud-system]]) — coherent and complete.

**Exit gate:** a fresh player starts a new game, plays the campaign to the
credits, saves/reloads mid-way without corruption, and the wanted/economy
systems work throughout.

---

## Phase G — Trailer-grade polish  *(roadmap M6)*

*Goal: pass the acceptance test; lock performance.*

- [ ] Lighting master pass: GI (SDFGI/HDDAGI or an `engine/` solution)
      **gated by quality tier**, volumetrics, contact AO where it bites —
      respecting the measured perf budget from the M6 60-FPS target.
- [ ] Audio mix pass: spatialization, occlusion, music ducking, impact punch.
- [ ] Performance lockdown: 60 FPS @ 1080p mid-range, committed profiles,
      CI perf regression gate.
- [ ] Camera, animation, and transition polish; loading/streaming hidden.
- [ ] Accessibility + options: rebindable controls, subtitles, scalable UI.
- [ ] **Cut the 90-second in-engine trailer from a release build** — the final
      acceptance test from `docs/VISION.md`.

**Exit gate:** the trailer is captured from a tagged release build and looks
like the game; the perf profile is green and locked.

---

## Phase H — Ship 1.0

*Goal: a stranger can download it and play it to the end.*

- [ ] Packaging & signing for Linux/Win/macOS; one-click run.
- [ ] First-run onboarding, crash reporting, telemetry-free analytics opt-in.
- [ ] Bug-bash, soak test, save-compat freeze.
- [ ] Release notes, store/landing page, provenance/licensing audit
      (`LICENSE`, `LICENSE-ASSETS`, `docs/ASSETS.md` complete).
- [ ] Tag `v1.0`, publish builds, publish the trailer.

**Exit gate:** `v1.0` tagged; downloadable builds; a clean machine installs and
completes the campaign.

---

## 3. Engine track (`engine/worldcore`) — parallel, evidence-driven

Native code must justify itself with a **captured profile** before it's written
(rule in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)). Likely modules, in
priority order, gated by Phase B/D/E needs:

1. Async tile streamer (Phase B — the critical one).
2. Runtime impostor baker (Phase B).
3. Traffic/crowd simulation core (Phase C/E, only with profile evidence).
4. Ocean simulation (Phase E).
5. GPU-driven crowd rendering (Phase E/G).

Anything generically useful gets a Godot upstream PR the same week, logged in
[`docs/UPSTREAM.md`](docs/UPSTREAM.md). A permanent fork is a failure state.

---

## 4. How we work (the operating contract)

- **Playable trunk.** `main` always runs; `tools/check.sh` is the gate and = CI.
  Need gdtoolkit on `$HOME/Library/Python/3.9/bin` for the lint step.
- **Vertical slices over horizontal layers.** One drivable lit block beats ten
  systems at 40%.
- **GDScript first, C++ when profiled.**
- **Original assets only**, provenance for every file.
- **Every wired feature ships with a runtime probe.** No probe → doesn't count.
- **Multi-agent.** Several agents build this at once on lane discipline
  ([[multi-agent-swarm-setup]]); route shared-file changes
  (`project.godot`, `player.gd`, shared scenes) through the integrator — never
  path-commit a shared file holding someone else's uncommitted work
  (the `LOOP_HANDOFF.md` rule).
- **The roadmap is the steering wheel.** Humans edit `docs/ROADMAP.md` and this
  file to point the loops.

---

## 5. Reality check / known limits

- **Fidelity ceiling ~6–7/10 vs the real GTA VI trailer** without hardware RT
  ([[godot-fidelity-ceiling]]). Plan for art direction and density to close the
  *perceived* gap, not a renderer miracle.
- **Content volume is the true long pole**, not systems. Phase D will take
  longer than B, C, E combined. Parallelize it hard.
- **Scope discipline:** online/multiplayer, character creator, a second city,
  and a 50-hour narrative are **Post-launch**, not v1.0. Say no on the record.

---

## 6. Post-launch (explicitly out of v1.0)

Multiplayer/online · second city/map expansion · character creator ·
deeper RPG progression · mod/SDK support · console ports · licensed radio ·
mocap cutscene upgrade.

---

*Living document. Amend it in the same PR that makes it stale. Boxes check only
when the work is on `main`, passing CI, and playable.*
