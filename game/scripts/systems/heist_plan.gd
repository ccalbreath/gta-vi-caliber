class_name HeistPlan
extends RefCounted
## The APPROACH + PREP layer of a heist — the planning board that sits on top of
## `HeistCrew` (which assembles the crew + cuts). Pick how you hit the score:
## LOUD (guns blazing — standard take, highest base risk, least prep), STEALTH
## (quieter, a little more take since nothing gets wrecked, more prep), or SMART
## (an insider/clever job — lowest risk, biggest take, the most prep). Then run
## prep tasks (case the joint, grab a getaway vehicle, source gear): each finished
## prep shaves the risk and pads the take. The crew's skill folds in at the end.
##
## Pure + deterministic — unit-tested headless (tests/unit/test_heist_plan.gd). A
## planning UI calls set_approach()/add_prep()/complete_prep(); the mission resolver
## reads success_chance(HeistCrew skill) and expected_take(base) at go-time, and
## gates the launch on is_ready(). Persisted via to_dict/from_dict.

## Approaches: base_risk (0..1), take multiplier, and prep tasks required to launch.
const APPROACHES := {
	"loud": {"base_risk": 0.5, "take_mult": 1.0, "min_prep": 1},
	"stealth": {"base_risk": 0.35, "take_mult": 1.1, "min_prep": 2},
	"smart": {"base_risk": 0.25, "take_mult": 1.25, "min_prep": 3},
}
## Risk shaved and take padded per completed prep task.
const PREP_RISK_CUT: float = 0.08
const PREP_TAKE_BONUS: float = 0.05
## Risk a fully-skilled crew shaves off.
const CREW_RISK_CUT: float = 0.3
## Risk never drops below this — a heist is never a sure thing.
const RISK_FLOOR: float = 0.05

var _approach: String = ""
var _preps: Dictionary = {}  # prep id -> done (bool)

# --- Approach ----------------------------------------------------------------


func set_approach(name: String) -> bool:
	if not APPROACHES.has(name):
		return false
	_approach = name
	return true


func approach() -> String:
	return _approach


# --- Prep --------------------------------------------------------------------


func add_prep(id: String) -> bool:
	var clean := id.strip_edges()
	if clean.is_empty() or _preps.has(clean):
		return false
	_preps[clean] = false
	return true


func complete_prep(id: String) -> bool:
	if not _preps.has(id):
		return false
	_preps[id] = true
	return true


func preps_total() -> int:
	return _preps.size()


func preps_done() -> int:
	var done := 0
	for id in _preps:
		if _preps[id]:
			done += 1
	return done


func prep_progress() -> float:
	if _preps.is_empty():
		return 0.0
	return float(preps_done()) / float(_preps.size())


# --- Outcome -----------------------------------------------------------------


## Final 0..1 risk: the approach's base, minus prep work, minus crew skill.
func risk(crew_skill01: float) -> float:
	if _approach.is_empty():
		return 1.0
	var base: float = APPROACHES[_approach]["base_risk"]
	var r := (
		base - float(preps_done()) * PREP_RISK_CUT - clampf(crew_skill01, 0.0, 1.0) * CREW_RISK_CUT
	)
	return clampf(r, RISK_FLOOR, 1.0)


func success_chance(crew_skill01: float) -> float:
	return clampf(1.0 - risk(crew_skill01), 0.0, 1.0)


## The take for a [param base_take] score: approach multiplier, padded by prep.
func expected_take(base_take: int) -> int:
	if _approach.is_empty():
		return base_take
	var mult: float = APPROACHES[_approach]["take_mult"]
	return int(round(float(base_take) * mult * (1.0 + float(preps_done()) * PREP_TAKE_BONUS)))


## Launch-ready once an approach is chosen and its required prep is done.
func is_ready() -> bool:
	if _approach.is_empty():
		return false
	return preps_done() >= int(APPROACHES[_approach]["min_prep"])


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	return {"approach": _approach, "preps": _preps.duplicate()}


func from_dict(data: Dictionary) -> void:
	var name: String = str(data.get("approach", ""))
	_approach = name if APPROACHES.has(name) else ""
	_preps.clear()
	var saved: Dictionary = data.get("preps", {})
	for id in saved:
		_preps[str(id)] = bool(saved[id])
