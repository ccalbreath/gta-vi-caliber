class_name Stakeout
extends RefCounted
## Pure casing-then-strike model — the heist PREP loop. Mark a target and your crew CASES it,
## building RECON over time; when you move in, the take SCALES with how well you cased it, and a
## rushed (low-recon) hit trips the silent ALARM (heat). So a patient job nets the full score
## clean, while a smash-and-grab nets a fraction and brings the cops. Distinct from HeistBoard
## (an RNG roll) by its deterministic recon-prep curve. No nodes, no wallet coupling (the caller
## banks the take and reports the heat). Unit-tested headless (tests/unit/test_stakeout.gd).

const DEFAULT_BASE_TAKE: int = 30000
## A fully blind (recon 0) hit still nets this fraction of the take.
const DEFAULT_MIN_FRACTION: float = 0.3
## Recon below this trips the alarm.
const DEFAULT_ALARM_BELOW: float = 0.6
## Recon the crew builds per in-game day of casing.
const DEFAULT_RECON_PER_DAY: float = 0.25

var base_take: int
var min_fraction: float
var alarm_below: float
var recon_per_day: float

var _recon: float = 0.0
var _marked: bool = false
var _done: bool = false


func _init(
	take: int = DEFAULT_BASE_TAKE,
	min_frac: float = DEFAULT_MIN_FRACTION,
	alarm: float = DEFAULT_ALARM_BELOW,
	per_day: float = DEFAULT_RECON_PER_DAY
) -> void:
	base_take = maxi(take, 0)
	min_fraction = clampf(min_frac, 0.0, 1.0)
	alarm_below = clampf(alarm, 0.0, 1.0)
	recon_per_day = maxf(per_day, 0.0)


# --- Queries -----------------------------------------------------------------


func recon() -> float:
	return _recon


func is_marked() -> bool:
	return _marked


func is_done() -> bool:
	return _done


## The take you'd walk with if you moved in at the current recon (min_fraction blind → full when
## perfectly cased).
func projected_take() -> int:
	return int(round(float(base_take) * (min_fraction + _recon * (1.0 - min_fraction))))


# --- Mutations ---------------------------------------------------------------


## Begin casing the target (the crew starts watching). No-op once the job is done.
func mark() -> void:
	if not _done:
		_marked = true


## Case the joint over `days`, building recon (capped at 1.0) — only while marked and not yet
## hit. Non-positive spans are ignored.
func case_for(days: float) -> void:
	if not _marked or _done or days <= 0.0:
		return
	_recon = clampf(_recon + recon_per_day * days, 0.0, 1.0)


## Move in and rob the cased target: the take scales with recon, and a low-recon hit trips the
## alarm. One-shot; fails (no payout) if unmarked or already done. Returns
## {success, take, alarm, recon}.
func move_in() -> Dictionary:
	if not _marked or _done:
		return {"success": false, "take": 0, "alarm": false, "recon": _recon}
	_done = true
	return {
		"success": true, "take": projected_take(), "alarm": _recon < alarm_below, "recon": _recon
	}


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	# base_take rides along so a restored recon is valued against the SAME score (a one-shot
	# stakeout can't re-case if the config drifts under it).
	return {"base_take": base_take, "recon": _recon, "marked": _marked, "done": _done}


func from_dict(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = data
	base_take = maxi(int(d.get("base_take", base_take)), 0)
	_recon = clampf(float(d.get("recon", 0.0)), 0.0, 1.0)
	_marked = bool(d.get("marked", false))
	_done = bool(d.get("done", false))
