# LOOP_AGENT — read this first, every session

You are the **autonomous side agent** running in a git worktree, parallel to a
human-driven interactive Claude Code session. Two agents share one repo. Stay in
your lane or you create merge conflicts that cost the other agent time.

## Your location & branch
- Worktree: `/Users/ziwenxu/Desktop/Code/GTA6-loop`
- Branch: `loop/auto`  (NEVER `git checkout main` here — main is the other agent's)
- Commit freely to `loop/auto`. It gets merged into `main` periodically.

## YOUR LANE — world & content (own it, build it big)
You own and may freely create/edit:
- `game/scenes/world/**`        (world layout, districts, props, lighting)
- `game/scenes/vehicles/**`     (new vehicles beyond car/bike)
- `game/scenes/**` for new content scenes you add
- `game/scripts/vehicles/*` ONLY for brand-new vehicle scripts you create
- new assets, missions, world-content scripts under clearly new paths

## SHARED CONFIG — you own these too (the other agent will NOT touch them)
- `game/project.godot`
- `game/scenes/world/sandbox.tscn`
- `memory/MEMORY.md`  and the `memory/` index

## DO NOT TOUCH — the interactive agent owns these (systems/physics)
- `game/scripts/player/**`
- `game/scripts/camera/**`
- `game/scripts/vehicles/vehicle_motion.gd`, `vehicle_damage.gd`, `car.gd`, `bike.gd`
  (read them, extend via NEW files, but don't edit these in-place)
- `game/tests/unit/test_vehicle_motion.gd`, `test_vehicle_damage.gd`,
  `test_player_motion.gd`, `test_camera_feel.gd`
If you genuinely need a change in a DO-NOT-TOUCH file, leave a note in
`LOOP_HANDOFF.md` at the repo root instead of editing it — the human will action it.

## Gate before every commit
- Run `check.sh` (the project gate). Do not commit on red.
- Write tests for new systems under `game/tests/` (new files only).

## Merge etiquette
- Keep commits small and scoped to content so merges into `main` stay clean.
- Don't rebase/force-push. The human merges `loop/auto` → `main`.
