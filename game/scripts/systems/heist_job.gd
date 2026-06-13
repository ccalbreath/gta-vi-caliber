class_name HeistJob
extends RefCounted
## A single heist, end to end — the facade that ties the heist trio together:
## a `HeistPlan` (approach + prep), a `HeistCrew` (who pulls it + their cuts), and
## `HeistComplication` (what goes wrong). Set the plan + crew, then resolve the
## score: the crew's average skill folds into the plan's risk, complications eat
## into the take as risk rises, and the crew takes their cut off the top.
##
## The success ROLL is kept separate from the deterministic resolution so the
## payout maths unit-tests cleanly: [method roll] does the rng gamble against
## [method success_chance]; [method resolve] then banks the outcome for a given
## success/fail. Pure (a caller-supplied rng for the roll, like `HeistCrew.attempt`).
## Unit-tested headless (tests/unit/test_heist_job.gd).

## Extra WantedSystem heat for getting caught on a blown job.
const CAUGHT_HEAT: int = 5

var _plan: HeistPlan
var _crew: HeistCrew
var _complications: HeistComplication


func _init() -> void:
	_plan = HeistPlan.new()
	_crew = HeistCrew.new()
	_complications = HeistComplication.new()


# Owned pieces, exposed for setup (set the approach + prep, hire the crew).
func plan() -> HeistPlan:
	return _plan


func crew() -> HeistCrew:
	return _crew


# --- Odds --------------------------------------------------------------------


## Combined success chance: the plan's odds with the crew's average skill folded
## in. Zero until the plan is launch-ready.
func success_chance() -> float:
	if not _plan.is_ready():
		return 0.0
	return _plan.success_chance(_crew.crew_skill())


## The rng gamble — true if the job comes off. Deterministic for a given seed.
func roll(rng: RandomNumberGenerator) -> bool:
	return rng.randf() < success_chance()


# --- Resolution (deterministic) ----------------------------------------------


## Bank the outcome of a [param success]/fail roll on a [param base_take] score.
## On success: the approach + prep pad the take, complications (scaled by the
## final risk) eat into it, then the crew takes their cut — the player gets the
## rest. On failure: nothing but extra heat. Returns
## {launched, success, take, gross, heat, casualties}.
func resolve(success: bool, base_take: int, base_heat: int) -> Dictionary:
	if not _plan.is_ready():
		return _result(false, false, 0, 0, base_heat, 0)
	if not success:
		return _result(true, false, 0, 0, base_heat + CAUGHT_HEAT, 0)

	var risk := _plan.risk(_crew.crew_skill())
	var padded := _plan.expected_take(base_take)
	var comp := _complications.apply(padded, base_heat, risk)
	var gross: int = comp["take"]
	var player_take: int = int(floor(float(gross) * _crew.player_share()))
	return _result(true, true, player_take, gross, int(comp["heat"]), int(comp["casualties"]))


func _result(
	launched: bool, success: bool, take: int, gross: int, heat: int, casualties: int
) -> Dictionary:
	return {
		"launched": launched,
		"success": success,
		"take": take,
		"gross": gross,
		"heat": heat,
		"casualties": casualties,
	}
