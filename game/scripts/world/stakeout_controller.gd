class_name StakeoutController
extends Node
## Owns the player's ONE marked SCORE and cases it over time: while marked, a day clock builds
## RECON; moving in robs it for a take scaled by how well it's cased, with a low-recon hit
## tripping the alarm. Self-wires by group ("stakeout"); a ScoreTarget marks it then moves in.
## Banks the take to PlayerStats and reports the robbery (+ the alarm) to the wanted system. Owns
## ONE Stakeout (tests/unit/test_stakeout.gd); verified stakeout_probe.gd.

signal marked
signal moved_in(take: int, alarm: bool)

## Floor on the day period and cap on days advanced per frame, so a tiny seconds_per_day or a
## lag-spike delta can't run thousands of casing ticks in one frame.
const MIN_SECONDS_PER_DAY: float = 1.0
const MAX_DAYS_PER_FRAME: float = 10.0

@export var base_take: int = Stakeout.DEFAULT_BASE_TAKE
## Real seconds per in-game day for the casing clock (<=0 pauses it).
@export var seconds_per_day: float = 90.0

var _stakeout: Stakeout
var _day_accum: float = 0.0


func _ready() -> void:
	_stakeout = Stakeout.new(base_take)
	add_to_group("stakeout")


func _process(delta: float) -> void:
	if seconds_per_day <= 0.0 or _stakeout == null:
		return
	var period := maxf(seconds_per_day, MIN_SECONDS_PER_DAY)
	_day_accum = minf(_day_accum + delta, period * MAX_DAYS_PER_FRAME)
	while _day_accum >= period:
		_day_accum -= period
		_stakeout.case_for(1.0)


## Begin casing the score (the crew starts watching).
func mark() -> void:
	if _stakeout != null and not _stakeout.is_marked():
		_stakeout.mark()
		marked.emit()


## Move in: bank the take to PlayerStats and report the robbery (+ alarm) to the wanted system.
## Guards the wallet BEFORE the model commits, so an un-bankable score isn't consumed. Returns
## the take (0 if not marked / already done / no wallet).
func move_in() -> int:
	if _stakeout == null:
		return 0
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats == null or not stats.has_method("add_money"):
		return 0
	var result := _stakeout.move_in()
	if not bool(result["success"]):
		return 0
	var take := int(result["take"])
	stats.add_money(take)
	_report_heat(bool(result["alarm"]))
	moved_in.emit(take, bool(result["alarm"]))
	return take


# --- Queries (passthroughs for the target / HUD) -----------------------------


func is_marked() -> bool:
	return _stakeout != null and _stakeout.is_marked()


func is_done() -> bool:
	return _stakeout != null and _stakeout.is_done()


func recon() -> float:
	return _stakeout.recon() if _stakeout != null else 0.0


func projected_take() -> int:
	return _stakeout.projected_take() if _stakeout != null else 0


# --- Internal ----------------------------------------------------------------


## The robbery draws heat; a tripped alarm brings them harder.
func _report_heat(alarm: bool) -> void:
	var wanted := get_tree().get_first_node_in_group("wanted")
	if wanted == null or not wanted.has_method("report_crime"):
		return
	wanted.report_crime(false)
	if alarm:
		wanted.report_crime(true)
