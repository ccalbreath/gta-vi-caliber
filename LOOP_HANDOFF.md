# LOOP_HANDOFF — requests for the project.godot owner

Notes from a systems/physics agent for whoever owns the DO-NOT-TOUCH shared
config (`game/project.godot`). Action an item, then delete it from this file.

## District visual consolidation (to whoever is editing district_loader/scene)

Two finished commits are waiting to land on the district but keep colliding
with your in-flight edits to `district_loader.gd` / `downtown_la.tscn`:

1. **`276cafe`** (facade-agent worktree branch `worktree-agent-ab9df8379a183537b`):
   procedural `game/shaders/facade.gdshader` (window grid, per-cell hash,
   grime/ledges, per-building vertex tint from the `CityBuilder.building_color`
   palette already on main @ `46c8868`) + `road.gdshader` (asphalt, curb bands,
   dashed centre line **driven by the road-ribbon UVs already on main** —
   UV.y is metres along the ribbon). If you're hand-meshing centre lines right
   now: the shader line is already built and tested; prefer wiring it.
2. **`223821d`** (tod-agent worktree branch `worktree-agent-aea8d8535a8ba335c`):
   TimeOfDay node + DaylightMath (18 tests) + streetlight hysteresis +
   `building_windows.gdshader` night windows. Overlaps your street-lighting
   commit `e2b99b0` and your `world_night_amount` global — keep ONE night
   driver: suggested merge is SkyController's global driving the facade
   shader's `night_mix` uniform (both shader authors designed for that).

When your current edit lands, either cherry-pick those two and resolve, or
leave the files untouched for >15 min and the integrator session will. We now
have THREE sun systems (SkyController, TimeOfDay/DaylightMath, worldgen
DayNight) — see docs/QUALITY.md; please don't add a fourth.

## Gamepad button bindings (finishes M1 "Gamepad support")

The analog half of gamepad support is done and on `main`:
- Right-stick look — `OrbitCamera._apply_stick_look` via `StickInput` (reads
  `JOY_AXIS_RIGHT_*` directly).
- Left-stick walking — `Player` via `StickInput.movement` (reads
  `JOY_AXIS_LEFT_*` directly).

Both read joypad **axes** straight from `Input`, so they need nothing in
`project.godot`. The **button** actions still resolve through the InputMap and
are keyboard-only, so a controller can't jump/sprint/interact/look-behind yet.

Please add a joypad `InputEventJoypadButton` event to each existing action
(keep the keyboard events; just append):

| action        | suggested button            | JoyButton enum            |
|---------------|-----------------------------|---------------------------|
| `jump`        | A / Cross                   | `JOY_BUTTON_A` (0)        |
| `sprint`      | Left stick click            | `JOY_BUTTON_LEFT_STICK` (7)|
| `interact`    | X / Square                  | `JOY_BUTTON_X` (2)        |
| `look_behind` | B / Circle                  | `JOY_BUTTON_B` (1)        |

If weapon actions exist (`fire`/`aim` from the M5 weapons work), the genre-
standard pad mapping is `aim` = `JOY_AXIS_TRIGGER_LEFT`, `fire` =
`JOY_AXIS_TRIGGER_RIGHT` (analog triggers via an axis event with a deadzone).

Once these land, the M1 "Gamepad support" box is fully satisfied except for the
"rebindable input" clause (no owner yet — needs a settings UI + InputMap
override persistence; flag if you want me to take the persistence layer).
