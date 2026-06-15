class_name AmbientMuggingActor
extends Pedestrian
## Scripted pedestrian for an ambient mugging: the victim holds still while the
## mugger walks in and menaces. Swapped onto spawned pedestrian instances by
## AmbientMuggingController — does not modify the base Pedestrian scene.

enum Role { VICTIM, MUGGER }

@export var role: Role = Role.VICTIM

var partner: Node3D = null

var _at_menace: bool = false


func _ready() -> void:
	respawn_delay = 0.0
	_rng.randomize()
	_home = global_position
	_hp = Damageable.new(max_health)
	add_to_group("pedestrians")
	if role == Role.MUGGER:
		add_to_group("mugging_mugger")


func _physics_process(delta: float) -> void:
	if _dead:
		_fall(delta)
		return
	if role == Role.MUGGER and _fear > 0.0:
		super._physics_process(delta)
		return
	if role == Role.VICTIM:
		_hold_idle(delta)
		return
	_menace_victim(delta)


func at_menace() -> bool:
	return _at_menace


func _hold_idle(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
	move_and_slide()
	if _rig != null:
		_rig.animate(Vector3.ZERO, is_on_floor(), velocity.y, false, delta)


func _menace_victim(delta: float) -> void:
	var target := partner.global_position if partner != null else global_position
	if NpcBrain.arrived(global_position, target, 1.5):
		_at_menace = true
		if not is_on_floor():
			velocity += get_gravity() * delta
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		move_and_slide()
		if _rig != null:
			_rig.animate(Vector3.ZERO, is_on_floor(), velocity.y, false, delta)
		return
	_at_menace = false
	var dir := NpcBrain.planar_dir(global_position, target)
	if not is_on_floor():
		velocity += get_gravity() * delta
	var target_v := dir * walk_speed
	velocity.x = move_toward(velocity.x, target_v.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_v.z, acceleration * delta)
	move_and_slide()
	if _rig != null:
		_rig.animate(Vector3(velocity.x, 0.0, velocity.z), is_on_floor(), velocity.y, false, delta)
