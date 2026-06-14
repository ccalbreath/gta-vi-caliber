class_name StreetRace
extends RefCounted
## Pure model for GTA-style STREET RACES — the checkpoint-lap races (drag/circuit
## time-trials against rival drivers) that hand the player an ordered ring of
## gates to clock through. A race is an ordered Array of checkpoint Vector3s run
## over N laps; the model tracks which gate is current, lap count, overall
## progress, placement against rivals, and race/lap timing.
##
## Two halves, both scene-free: a STATEFUL race instance (checkpoint advance, lap
## wrap, finish, timing) that a node drives during play, and a bank of STATIC
## helpers (placement ordering, gap-to-rival, reward by placement) the HUD and
## tests call with no instance. All XZ-plane spatial (y is up), defensive
## throughout, deterministic — unit-tested headless
## (tests/unit/test_street_race.gd).

const EPS: float = 0.0001

# --- Stateful race instance state ---
var _checkpoints: Array = []
var _laps: int = 1
var _index: int = 0  # current checkpoint index within the current lap
var _lap: int = 0  # 0-based lap currently being driven
var _finished: bool = false
var _elapsed: float = 0.0
var _lap_start: float = 0.0  # race time at which the current lap began
var _lap_splits: Array = []  # completed lap durations, in order


## A race = ordered `checkpoints` (Array of Vector3) over `laps` laps. An empty
## checkpoint list is a degenerate race that starts already finished. `laps` is
## floored at 1.
func _init(checkpoints: Array, laps: int = 1) -> void:
	_checkpoints = checkpoints.duplicate()
	_laps = maxi(laps, 1)
	reset()


## Drop the vertical component — racing reasons on the ground plane.
static func ground(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Did the racer hit the current checkpoint? Returns true and advances to the
## next gate (wrapping into the next lap, recording the lap split) when `pos` is
## within `radius` (XZ) of the current checkpoint. No-op + false when already
## finished, when the race has no checkpoints, or when out of range.
func reached(pos: Vector3, radius: float) -> bool:
	if _finished or _checkpoints.is_empty():
		return false
	var target := _checkpoints[_index] as Vector3
	if ground(target - pos).length() > maxf(radius, 0.0):
		return false
	_advance()
	return true


## The checkpoint the racer is currently driving toward. Vector3.ZERO when the
## race has no checkpoints or is finished.
func current_checkpoint() -> Vector3:
	if _checkpoints.is_empty() or _finished:
		return Vector3.ZERO
	return _checkpoints[_index] as Vector3


## Index of the current checkpoint within the current lap (0-based).
func checkpoint_index() -> int:
	return _index


## 1-based lap the racer is currently on (1 == first lap). Reports total_laps()
## once finished.
func current_lap() -> int:
	if _finished:
		return _laps
	return _lap + 1


## Total laps in the race.
func total_laps() -> int:
	return _laps


## Whether the race is complete (last checkpoint of the last lap cleared, or a
## degenerate empty-checkpoint race).
func is_finished() -> bool:
	return _finished


## Overall progress across the whole race (checkpoints * laps), clamped 0..1.
## 0 at the start, 1 once finished.
func progress() -> float:
	if _finished:
		return 1.0
	var per_lap := _checkpoints.size()
	if per_lap == 0:
		return 1.0
	var total := per_lap * _laps
	var done := _lap * per_lap + _index
	return clampf(float(done) / float(total), 0.0, 1.0)


## Checkpoints left to clear before the race is finished (across all remaining
## laps). 0 once finished or when there are no checkpoints.
func checkpoints_remaining() -> int:
	if _finished or _checkpoints.is_empty():
		return 0
	var per_lap := _checkpoints.size()
	var total := per_lap * _laps
	var done := _lap * per_lap + _index
	return maxi(total - done, 0)


## Accrue race time by `delta` seconds. No-op once finished or for a non-positive
## delta. Drives elapsed() and the lap-split clock.
func tick(delta: float) -> void:
	if _finished or delta <= 0.0:
		return
	_elapsed += delta


## Total race time accrued so far (seconds).
func elapsed() -> float:
	return _elapsed


## Duration of the most recently completed lap, or 0.0 when no lap has finished.
func last_lap() -> float:
	if _lap_splits.is_empty():
		return 0.0
	return _lap_splits[_lap_splits.size() - 1] as float


## Fastest completed lap split, or 0.0 when no lap has finished.
func best_lap() -> float:
	if _lap_splits.is_empty():
		return 0.0
	var best: float = _lap_splits[0] as float
	for i in range(1, _lap_splits.size()):
		var split: float = _lap_splits[i] as float
		if split < best:
			best = split
	return best


## Recorded lap splits in completion order (copy).
func lap_splits() -> Array:
	return _lap_splits.duplicate()


## Reset the race to its start: first checkpoint, lap 1, clock and splits zeroed.
## A race with no checkpoints resets straight to finished.
func reset() -> void:
	_index = 0
	_lap = 0
	_elapsed = 0.0
	_lap_start = 0.0
	_lap_splits = []
	_finished = _checkpoints.is_empty()


## Race placement (1 = first) of `player_progress` among the field — count of
## rivals strictly further along, plus one. Ties keep the player ahead (stable).
## A DNF rival (negative progress) still places; pass values from progress().
static func placement(player_progress: float, rival_progresses: Array) -> int:
	var place := 1
	for r in rival_progresses:
		if (r as float) > player_progress + EPS:
			place += 1
	return place


## Distance the trailing racer is behind the one ahead, along a `track_length`
## loop: (ahead_progress - my_progress) * track_length, floored at 0. A
## non-positive track_length or a racer already ahead yields 0.
static func gap_to(ahead_progress: float, my_progress: float, track_length: float) -> float:
	if track_length <= 0.0:
		return 0.0
	return maxf((ahead_progress - my_progress) * track_length, 0.0)


## Cash reward for finishing in `placement` (1-based). 1st pays the full
## `base_reward`; each lower place scales down by a fixed step, floored at a
## quarter of base. 0 for a DNF (placement <= 0) or a non-positive base.
static func reward(placement: int, base_reward: int) -> int:
	if placement <= 0 or base_reward <= 0:
		return 0
	var factor := maxf(1.0 - 0.25 * float(placement - 1), 0.25)
	return int(round(float(base_reward) * factor))


# --- helpers -----------------------------------------------------------------


## Advance past the current checkpoint, wrapping into the next lap (and recording
## that lap's split) or finishing the race after the final gate.
func _advance() -> void:
	_index += 1
	if _index < _checkpoints.size():
		return
	# Crossed the last checkpoint of this lap.
	_index = 0
	_lap_splits.append(_elapsed - _lap_start)
	_lap_start = _elapsed
	_lap += 1
	if _lap >= _laps:
		_finished = true
