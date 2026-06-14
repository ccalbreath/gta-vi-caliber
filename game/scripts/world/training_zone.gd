class_name TrainingZone
extends Area3D
## A gym / gun range / track — step in to TRAIN the skill it teaches. Each session
## raises that skill (with diminishing returns toward mastery), then a short rest
## cooldown stops you spamming the door to instant-max. Trains the shared
## PlayerSkillsController (group "player_skills") so the gains carry everywhere.
## Self-wires by group (player / player_skills). Needs a CollisionShape3D child;
## watches the player's collision layer (2). Verified in tests/training_zone_probe.gd.

signal trained(skill_id: String, level: float)

## The skill this place teaches (driving / shooting / stamina / strength).
@export var skill_id: String = "strength"
## Training effort per session (folded through the model's rate + headroom).
@export_range(0.01, 100.0) var session_effort: float = 1.0
## Real seconds of rest between sessions (you can't train again until it elapses).
@export_range(0.0, 3600.0) var rest_seconds: float = 20.0

var _cooldown: float = 0.0
var _warned_unknown: bool = false


func _ready() -> void:
	if session_effort <= 0.0:
		push_warning("TrainingZone: session_effort must be > 0 — defaulting to 1.0")
		session_effort = 1.0
	add_to_group("training_zone")
	collision_mask |= 2
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or _cooldown > 0.0:
		return
	var controller := get_tree().get_first_node_in_group("player_skills")
	if controller == null or not controller.has_method("train"):
		return
	if (
		not _warned_unknown
		and controller.has_method("has_skill")
		and not controller.has_skill(skill_id)
	):
		push_warning("TrainingZone: skill_id '%s' is unknown — this zone trains nothing" % skill_id)
		_warned_unknown = true
	var gain: float = controller.train(skill_id, session_effort)
	if gain <= 0.0:
		return  # unknown skill or already maxed — no session spent
	_cooldown = rest_seconds
	trained.emit(skill_id, float(controller.level(skill_id)))


## Seconds left before the next session can be trained, for a HUD readout.
func rest_remaining() -> float:
	return maxf(_cooldown, 0.0)
