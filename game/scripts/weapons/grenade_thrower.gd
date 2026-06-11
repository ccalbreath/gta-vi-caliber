class_name GrenadeThrower
extends Node
## Throws a grenade on the throw key (G), arcing from the player's hand along the
## camera heading.
##
## Self-contained: finds the player by group and the aim from the active camera,
## raw-key input (no new input action), spawns the grenade into the current
## scene with an initial velocity. A short cooldown stops spamming.

const GRENADE_SCENE := preload("res://scenes/weapons/grenade.tscn")

@export var throw_key: int = KEY_G
@export var throw_force: float = 15.0
@export var up_force: float = 4.5
@export var cooldown: float = 0.8

var _cooldown_left: float = 0.0


func _process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == throw_key and _cooldown_left <= 0.0:
		_throw()


func _throw() -> void:
	var player := _player()
	var cam := get_viewport().get_camera_3d()
	var scene := get_tree().current_scene
	if player == null or cam == null or scene == null:
		return
	_cooldown_left = cooldown
	var forward := -cam.global_transform.basis.z
	var grenade := GRENADE_SCENE.instantiate()
	scene.add_child(grenade)
	grenade.global_position = player.global_position + Vector3(0.0, 1.4, 0.0) + forward * 0.6
	if grenade is RigidBody3D:
		(grenade as RigidBody3D).linear_velocity = forward * throw_force + Vector3.UP * up_force


func _player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as Node3D if not players.is_empty() else null
