class_name ParoleTerms
extends RefCounted
## Pure bookkeeping for the player's parole — Lucia's opening hook (she starts the game
## on parole). Two pressures pull against each other: VIOLATIONS (getting wanted breaks
## the terms) push toward REVOCATION, while CLEAN DAYS push toward COMPLETION. Enough
## violations revokes parole; enough consecutive clean days completes it. Deterministic,
## no engine deps — the wiring/clock/feedback lives in ParoleController. Each mutator
## returns a result dict {event, violations, clean_streak, active, outcome}.
## Verified in tests/unit/test_parole_terms.gd.

const DEFAULT_CLEAN_DAYS: int = 5
const DEFAULT_MAX_VIOLATIONS: int = 3

## In-a-row clean days needed to finish parole, and violations that revoke it.
var clean_days_required: int
var max_violations: int

var violations: int = 0
var clean_streak: int = 0
## Still serving (true) vs. finished one way or the other (false).
var active: bool = true
## "" while serving, then "revoked" or "completed".
var outcome: String = ""

var _violation_today: bool = false


func _init(clean_days: int = DEFAULT_CLEAN_DAYS, max_viol: int = DEFAULT_MAX_VIOLATIONS) -> void:
	clean_days_required = maxi(clean_days, 1)
	max_violations = maxi(max_viol, 1)


## Record a parole violation (got wanted / broke the terms). Resets the clean streak and
## marks today dirty; enough violations revoke parole. No-op once parole has ended.
func record_violation() -> Dictionary:
	if not active:
		return _state("ignored")
	violations += 1
	clean_streak = 0
	_violation_today = true
	if violations >= max_violations:
		active = false
		outcome = "revoked"
		return _state("revoked")
	return _state("violation")


## Advance one in-game day. A day with no violation extends the clean streak; reaching
## the required streak completes parole. The day a violation happened does NOT count
## clean. No-op once parole has ended.
func advance_day() -> Dictionary:
	if not active:
		return _state("ignored")
	if _violation_today:
		_violation_today = false
		return _state("day")
	clean_streak += 1
	if clean_streak >= clean_days_required:
		active = false
		outcome = "completed"
		return _state("completed")
	return _state("day")


func _state(event: String) -> Dictionary:
	return {
		"event": event,
		"violations": violations,
		"clean_streak": clean_streak,
		"active": active,
		"outcome": outcome,
	}


## Snapshot for SaveManager.
func to_dict() -> Dictionary:
	return {
		"clean_days_required": clean_days_required,
		"max_violations": max_violations,
		"violations": violations,
		"clean_streak": clean_streak,
		"active": active,
		"outcome": outcome,
		"violation_today": _violation_today,
	}


func from_dict(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = data
	clean_days_required = maxi(int(d.get("clean_days_required", clean_days_required)), 1)
	max_violations = maxi(int(d.get("max_violations", max_violations)), 1)
	violations = clampi(int(d.get("violations", 0)), 0, max_violations)
	clean_streak = clampi(int(d.get("clean_streak", 0)), 0, clean_days_required)
	active = bool(d.get("active", true))
	outcome = String(d.get("outcome", ""))
	_violation_today = bool(d.get("violation_today", false))
	_reconcile()


## Keep `active`/`outcome` consistent with the loaded counts, so a hand-edited or
## corrupted save can't load a "zombie" that already hit a threshold yet still serves.
func _reconcile() -> void:
	if not active:
		return
	if violations >= max_violations:
		active = false
		outcome = "revoked"
	elif clean_streak >= clean_days_required:
		active = false
		outcome = "completed"
