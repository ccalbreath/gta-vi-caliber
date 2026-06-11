class_name Police
extends CharacterBody3D
## Police responder: patrols near a post, then chases the nearest player while a
## WantedTracker reports an active wanted level.
##
## Reuses CharacterAnimator for procedural running and Damageable for health
## (shootable like any NPC — and shooting a cop is itself a crime). All steering
## is NpcBrain (pure, tested); this node just owns state and moves the body.

@export var patrol_speed: float = 2.6
@export var chase_speed: float = 7.0
@export var wander_radius: float = 6.0
@export var arrive_tolerance: float = 1.0
@export var idle_time: float = 1.2
## Stops chasing (an "arrest" hold) once this close to the target.
@export var catch_distance: float = 1.8
## Damage per second dealt to the player while within catch_distance.
@export var attack_dps: float = 22.0
@export var acceleration: float = 16.0
@export var max_health: float = 70.0
@export var respawn_delay: float = 6.0

var _target: Vector3 = Vector3.ZERO
var _home: Vector3 = Vector3.ZERO
var _idle_left: float = 0.0
var _dead: bool = false
var _hp: Damageable
var _rng := RandomNumberGenerator.new()

@onready var _rig: CharacterAnimator = $Rig


func _ready() -> void:
	_rng.randomize()
	_home = global_position
	_hp = Damageable.new(max_health)
	add_to_group("police")
	_pick_patrol()


func _physics_process(delta: float) -> void:
	if _dead:
		_fall(delta)
		return

	var dir := Vector3.ZERO
	var speed := 0.0
	var player := _nearest_player()
	if player != null and _is_wanted():
		if NpcBrain.planar_distance(global_position, player.global_position) > catch_distance:
			dir = NpcBrain.pursue_dir(global_position, player.global_position)
			speed = chase_speed
		else:
			_attack(delta)
	elif NpcBrain.arrived(global_position, _target, arrive_tolerance):
		_idle_left -= delta
		if _idle_left <= 0.0:
			_pick_patrol()
	else:
		dir = NpcBrain.planar_dir(global_position, _target)
		speed = patrol_speed

	if not is_on_floor():
		velocity += get_gravity() * delta
	var target_v := dir * speed
	velocity.x = move_toward(velocity.x, target_v.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_v.z, acceleration * delta)
	move_and_slide()
	_rig.animate(Vector3(velocity.x, 0.0, velocity.z), is_on_floor(), velocity.y, false, delta)


## Duck-typed weapon target entry point.
func take_damage(amount: float, _point: Vector3, _normal: Vector3) -> void:
	if _dead:
		return
	if _hp.apply(amount):
		_die()


func is_dead() -> bool:
	return _dead


func _attack(delta: float) -> void:
	for health in get_tree().get_nodes_in_group("player_health"):
		if health.has_method("take_damage"):
			health.take_damage(attack_dps * delta)


func _is_wanted() -> bool:
	for tracker in get_tree().get_nodes_in_group("wanted"):
		if tracker.has_method("is_wanted") and tracker.is_wanted():
			return true
	return false


func _pick_patrol() -> void:
	_idle_left = idle_time
	_target = NpcBrain.wander_target(_home, wander_radius, _rng.randf(), _rng.randf())


func _nearest_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as Node3D if not players.is_empty() else null


func _fall(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()


func _die() -> void:
	_dead = true
	var tween := create_tween()
	tween.tween_property(_rig, "rotation:z", deg_to_rad(88.0), 0.4)
	if respawn_delay > 0.0:
		tween.tween_interval(respawn_delay)
		tween.tween_callback(_respawn)


func _respawn() -> void:
	_hp.revive()
	_dead = false
	_rig.rotation = Vector3.ZERO
	global_position = _home
	velocity = Vector3.ZERO
	_pick_patrol()
