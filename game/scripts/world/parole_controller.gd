class_name ParoleController
extends Node
## Lucia's opening hook made playable: the player starts ON PAROLE. Getting WANTED
## breaks the terms — each spree counts as ONE violation (until the stars cool back to
## zero), and enough violations REVOKE parole, bringing the law down hard (a heat spike
## on the wanted system). Staying clean for enough in-game days COMPLETES parole and
## pays a freedom bonus. Fully integrated and self-wiring (group "parole"): it CONSUMES
## the live wanted node's `stars_changed` for violations and FEEDS BACK into wanted
## (revocation heat) and player_stats (completion reward) — no scene edit needed. Owns
## the pure ParoleTerms model (tests/unit/test_parole_terms.gd); verified parole_probe.gd.

signal violation_recorded(count: int)
signal parole_revoked
signal parole_completed(reward: int)

## Floor on the day period and cap on days advanced per frame, so a tiny seconds_per_day
## or a lag-spike delta can't run thousands of ticks in one frame.
const MIN_SECONDS_PER_DAY: float = 1.0
const MAX_DAYS_PER_FRAME: float = 10.0
## Crime reports a revocation slams the wanted system with (the law comes down hard).
const REVOCATION_HEAT_REPORTS: int = 4

## Consecutive clean in-game days to complete parole, and violations that revoke it.
@export var clean_days_to_complete: int = 5
@export var violations_to_revoke: int = 3
## Stars at/above this break the terms (any wanted level, by default).
@export var violation_stars: int = 1
## Real seconds per in-game day for the parole clock (<=0 pauses it).
@export var seconds_per_day: float = 90.0
## Cash paid for completing parole without a revocation.
@export var completion_reward: int = 5000

var _terms: ParoleTerms
var _day_accum: float = 0.0
## Weak ref to the wanted node we listen to; re-binds if it's freed/replaced.
var _wanted_ref: WeakRef = null
## Debounce: true once the current wanted spree has been counted, cleared when stars
## drop back below the threshold, so one chase is one violation — not one per star tick.
var _spree_flagged: bool = false


func _ready() -> void:
	_terms = ParoleTerms.new(clean_days_to_complete, violations_to_revoke)
	add_to_group("parole")


func _process(delta: float) -> void:
	_bind_wanted()
	if seconds_per_day <= 0.0 or _terms == null or not _terms.active:
		return
	var period := maxf(seconds_per_day, MIN_SECONDS_PER_DAY)
	_day_accum = minf(_day_accum + delta, period * MAX_DAYS_PER_FRAME)
	while _day_accum >= period and _terms.active:
		_day_accum -= period
		_apply(_terms.advance_day())


## Connect to the wanted source whenever it appears, and RE-connect if the node we were
## bound to has been freed/replaced (works in any spawn order).
func _bind_wanted() -> void:
	if _wanted_ref != null and is_instance_valid(_wanted_ref.get_ref()):
		return
	var wanted := get_tree().get_first_node_in_group("wanted")
	if wanted != null and wanted.has_signal("stars_changed"):
		if not wanted.is_connected("stars_changed", _on_stars_changed):
			wanted.connect("stars_changed", _on_stars_changed)
		_wanted_ref = weakref(wanted)


func _on_stars_changed(stars: int) -> void:
	if _terms == null or not _terms.active:
		return
	if stars < violation_stars:
		_spree_flagged = false
		return
	if _spree_flagged:
		return
	_spree_flagged = true
	_apply(_terms.record_violation())


## React to a model result: emit the matching signal and drive the integrated
## consequence (revocation heat / completion payout).
func _apply(result: Dictionary) -> void:
	# "day" and "ignored" are expected no-ops (no match arm).
	match String(result.get("event", "")):
		"violation":
			violation_recorded.emit(int(result["violations"]))
		"revoked":
			violation_recorded.emit(int(result["violations"]))
			# _terms.active is already false here (the model flips it before returning
			# "revoked"), so the stars_changed that _punish's heat spike re-emits is inert:
			# _on_stars_changed returns on the active guard. Keep this ordering.
			_punish()
			parole_revoked.emit()
		"completed":
			_reward()
			parole_completed.emit(completion_reward)


## Revocation: the law comes down — spike the wanted system.
func _punish() -> void:
	var wanted := get_tree().get_first_node_in_group("wanted")
	if wanted == null or not wanted.has_method("report_crime"):
		return
	for _i in REVOCATION_HEAT_REPORTS:
		wanted.report_crime(true)


## Completion: pay the freedom bonus.
func _reward() -> void:
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats != null and stats.has_method("add_money"):
		stats.add_money(completion_reward)


func is_on_parole() -> bool:
	return _terms != null and _terms.active


func violation_count() -> int:
	return _terms.violations if _terms != null else 0


func clean_streak() -> int:
	return _terms.clean_streak if _terms != null else 0


## "" while serving, then "revoked" or "completed".
func outcome() -> String:
	return _terms.outcome if _terms != null else ""
