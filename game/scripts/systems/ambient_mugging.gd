class_name AmbientMugging
extends RefCounted
## Pure model for an ambient mugging encounter — the timed "stop the mugging"
## loop: a mugger threatens a victim until the player kills or scares the mugger
## away, or the scene expires. Scene-free and unit-tested headless
## (tests/unit/test_ambient_mugging.gd); AmbientMuggingController drives it.

const DURATION: float = 90.0
const SAVED_REWARD: int = 250

var _started_at: float = -INF
var _outcome: String = ""


func start(at_time: float) -> void:
	_started_at = at_time
	_outcome = ""


func is_active() -> bool:
	return _outcome.is_empty() and _started_at > -INF


## Advance the encounter clock and resolve when the mugger is stopped or time runs out.
func tick(now: float, mugger_dead: bool, mugger_fled: bool, _player_near: bool) -> void:
	if not is_active():
		return
	if mugger_dead or mugger_fled:
		_outcome = "saved"
		return
	if now - _started_at >= DURATION:
		_outcome = "expired"


func outcome() -> String:
	return _outcome


static func reward_for(outcome_id: String) -> int:
	return SAVED_REWARD if outcome_id == "saved" else 0
