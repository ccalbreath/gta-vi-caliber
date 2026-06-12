class_name StatsCoordinator
extends Node
## Makes StatTracker live: records lifetime gameplay stats from the events the
## scene already emits, so 100%-completion tracking accrues during play. Thin
## self-wiring coordinator — counts missions passed off the MissionController's
## mission_completed signal and busts off the wanted level — and joins group
## "stats" so the HUD / pause menu can read the tally. More event sources
## (kills, distance, jacks) hook in here as those systems get wired.

var _stats: StatTracker
var _was_wanted: bool = false


func _ready() -> void:
	_stats = StatTracker.new()
	add_to_group("stats")
	var mission := get_tree().get_first_node_in_group("mission")
	if mission != null and mission.has_signal("mission_completed"):
		mission.connect("mission_completed", _on_mission_passed)


func _process(_delta: float) -> void:
	# A wanted level that rises then clears counts as one "evaded" bust dodge.
	var tracker := get_tree().get_first_node_in_group("wanted")
	if tracker == null or not tracker.has_method("is_wanted"):
		return
	var wanted: bool = tracker.is_wanted()
	if _was_wanted and not wanted:
		_stats.add("busts_evaded", 1)
	_was_wanted = wanted


func _on_mission_passed() -> void:
	_stats.add("missions_passed", 1)


## Read a lifetime stat (0 if never recorded), for the HUD / completion screen.
func stat(stat_id: String) -> float:
	return _stats.get_stat(stat_id) if _stats != null else 0.0


## Overall completion 0..100, for the pause-menu progress readout.
func completion_percent() -> float:
	return _stats.completion_percent() if _stats != null else 0.0
