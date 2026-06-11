class_name MissionDirector
extends Node
## Runs one active Mission and ties it to gameplay events.
##
## Listens to the player WeaponController's hit_confirmed kills, counts them
## toward the objective, runs the timer, and auto-restarts a short while after a
## mission ends so the playground always has something to do. Joins group
## "mission" and exposes hud_text() for the HUD to poll. The objective/fail
## logic is pure (Mission, tested); this node is the scene glue.

@export var title: String = "RAMPAGE"
@export var objective: String = "Take down targets"
@export var required: int = 5
@export var time_limit: float = 60.0
@export var restart_delay: float = 4.0

var _mission: Mission
var _cooldown: float = 0.0


func _ready() -> void:
	add_to_group("mission")
	call_deferred("_bind")
	_start()


func _bind() -> void:
	for controller in get_tree().get_nodes_in_group("weapon_controller"):
		if controller.has_signal("hit_confirmed"):
			controller.hit_confirmed.connect(_on_hit)


func _on_hit(killed: bool) -> void:
	if killed and _mission != null and _mission.is_active():
		_mission.record(1)
		if not _mission.is_active():
			_cooldown = restart_delay


func _process(delta: float) -> void:
	if _mission == null:
		return
	if _mission.is_active():
		_mission.tick(delta)
		if not _mission.is_active():
			_cooldown = restart_delay
	else:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_start()


## Single line for the HUD to poll.
func hud_text() -> String:
	if _mission == null:
		return ""
	match _mission.status:
		Mission.Status.COMPLETE:
			return "%s: COMPLETE" % _mission.title
		Mission.Status.FAILED:
			return "%s: FAILED" % _mission.title
		_:
			var clock := ""
			if _mission.time_limit > 0.0:
				clock = "  %ds" % int(ceil(_mission.time_left))
			return (
				"%s — %s %d/%d%s"
				% [_mission.title, _mission.objective, _mission.progress, _mission.required, clock]
			)


func _start() -> void:
	_mission = Mission.new(title, objective, required, time_limit)
