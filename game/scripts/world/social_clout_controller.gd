class_name SocialCloutController
extends Node
## GTA VI's everyone-is-filming, go-viral living world, wired live. When the player pulls
## off a crime in front of the city (the wanted level rises), bystanders film it: the
## controller records the act, and a flashy enough clip goes VIRAL, jumping the follower
## count. Fame has a price — a viral clip is EVIDENCE, so it tips a little extra heat back
## to the wanted system. Followers then pay passive SPONSORSHIP income on a day clock and
## raise RECOGNIZABILITY (a lying-low penalty other systems can read). Self-wires by group
## ("social_clout"): CONSUMES the `wanted` node's stars_changed (one filmed act per crime
## SPREE, debounced until the heat cools) and FEEDS PlayerStats (income) + wanted (the tip).
## Owns ONE SocialClout (tests/unit/test_social_clout.gd); verified social_clout_probe.gd.

signal went_viral(followers: int, gained: int)
signal followers_changed(followers: int, tier: String)

## Floor on the day period and cap on days advanced per frame, so a tiny seconds_per_day or
## a lag-spike delta can't run thousands of income/decay ticks in one frame.
const MIN_SECONDS_PER_DAY: float = 1.0
const MAX_DAYS_PER_FRAME: float = 10.0

## Wanted stars at/above which a crime is "filmed" (counts as a recordable act).
@export var film_at_stars: int = 2
## The controller can't see the real act, so these stand in: severity per wanted star, the
## bystander estimate, and how flashy the crime reads. They drive the clip's viral reach.
@export var severity_per_star: float = 12.0
@export var est_witnesses: int = 3
@export_range(0.0, 4.0) var flashiness: float = 1.0
## Real seconds per in-game day for the sponsorship-income / follower-decay clock.
@export var seconds_per_day: float = 90.0

var _clout: SocialClout
var _day_accum: float = 0.0
## Weak ref to the wanted node we listen to; re-binds if it's freed/replaced.
var _wanted_ref: WeakRef = null
## Debounce: true once the current wanted spree has been filmed, cleared when the stars cool
## below the film threshold — so one crime spree is one clip, not one per star tick (and the
## viral heat-tip we feed back can't re-trigger another recording).
var _spree_flagged: bool = false


func _ready() -> void:
	_clout = SocialClout.new()
	add_to_group("social_clout")


func _process(delta: float) -> void:
	_bind_wanted()
	if seconds_per_day <= 0.0 or _clout == null:
		return
	var period := maxf(seconds_per_day, MIN_SECONDS_PER_DAY)
	_day_accum = minf(_day_accum + delta, period * MAX_DAYS_PER_FRAME)
	while _day_accum >= period:
		_day_accum -= period
		_on_day()


## A day passes: pay the day's sponsorship income, then let the audience drift.
func _on_day() -> void:
	var income := _clout.sponsorship_income()
	if income > 0:
		var stats := get_tree().get_first_node_in_group("player_stats")
		if stats != null and stats.has_method("add_money"):
			stats.add_money(income)
	var before := _clout.followers()
	_clout.decay(1.0)
	if _clout.followers() != before:
		_emit_followers()


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
	if _clout == null:
		return
	if stars < film_at_stars:
		_spree_flagged = false
		return
	if _spree_flagged:
		return
	_spree_flagged = true
	_record_crime(stars)


## Film the current crime: a flashy enough clip goes viral (followers jump) and tips a bit
## of heat back to the wanted system (the clip is evidence). A flop does neither.
func _record_crime(stars: int) -> void:
	var severity := severity_per_star * float(stars)
	var result := _clout.record_act(severity, est_witnesses, flashiness)
	if not bool(result["viral"]):
		return
	went_viral.emit(_clout.followers(), int(result["followers_gained"]))
	_tip_heat(int(result["heat_tip"]))
	_emit_followers()


## A viral clip is evidence: tip a little heat to the wanted system. The re-entrant
## stars_changed this causes is inert — _spree_flagged is already set, so it won't re-film.
func _tip_heat(heat: int) -> void:
	if heat <= 0:
		return
	var wanted := get_tree().get_first_node_in_group("wanted")
	if wanted == null or not wanted.has_method("report_crime"):
		return
	for _i in heat:
		wanted.report_crime(false)


func _emit_followers() -> void:
	followers_changed.emit(_clout.followers(), _clout.fame_tier())


# --- Passthroughs / direct hooks ---------------------------------------------


func followers() -> int:
	return _clout.followers() if _clout != null else 0


func fame_tier() -> String:
	return _clout.fame_tier() if _clout != null else ""


## 0..1 — how easily the player is recognized on sight (a lying-low penalty seam).
func recognizability() -> float:
	return _clout.recognizability() if _clout != null else 0.0


func sponsorship_income() -> int:
	return _clout.sponsorship_income() if _clout != null else 0


## Grow the following from a non-crime source (a banger Snapmatic post) — the ContentCareer
## hook. Returns the new follower count.
func post_content(amount: int) -> int:
	if _clout == null:
		return 0
	var total := _clout.add_followers(amount)
	_emit_followers()
	return total
