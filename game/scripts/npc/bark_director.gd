class_name BarkDirector
extends Node
## Drives ambient and reactive NPC barks for a living street.
##
## On a timer it floats an idle one-liner over a pedestrian; when the player
## opens fire (WeaponController.hit_confirmed) the nearest pedestrian shouts a
## panic line. Self-contained: finds pedestrians/player by group and the gunfire
## signal by group, and parents a billboarded Label3D to the speaker — so it
## needs no edits to the (busy) pedestrian script. Lines come from BarkPool
## (pure, tested).

@export var ambient_interval: float = 5.5
@export var bark_duration: float = 2.3
@export var bark_height: float = 2.15
@export var idle_color: Color = Color(0.9, 0.92, 1.0)
@export var flee_color: Color = Color(1.0, 0.8, 0.5)
@export var react_range: float = 30.0

var _timer: float = 0.0
var _counter: int = 0


func _ready() -> void:
	add_to_group("bark_director")
	call_deferred("_bind")


func _bind() -> void:
	for controller in get_tree().get_nodes_in_group("weapon_controller"):
		if controller.has_signal("hit_confirmed"):
			controller.hit_confirmed.connect(_on_gunfire)


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= ambient_interval:
		_timer = 0.0
		_ambient_bark()


func _ambient_bark() -> void:
	var peds := get_tree().get_nodes_in_group("pedestrians")
	if peds.is_empty():
		return
	_counter += 1
	var ped := peds[_counter % peds.size()] as Node3D
	_bark(ped, BarkPool.line(BarkPool.Situation.IDLE, _counter), idle_color)


func _on_gunfire(_killed: bool) -> void:
	var ped := _nearest_pedestrian_to_player()
	if ped == null:
		return
	_counter += 1
	_bark(ped, BarkPool.line(BarkPool.Situation.FLEE, _counter), flee_color)


func _bark(ped: Node3D, text: String, color: Color) -> void:
	if ped == null or text == "":
		return
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.006
	label.font_size = 32
	label.outline_size = 6
	ped.add_child(label)
	label.position = Vector3.UP * bark_height
	get_tree().create_timer(bark_duration).timeout.connect(label.queue_free)


func _nearest_pedestrian_to_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	var origin := (players[0] as Node3D).global_position
	var best: Node3D = null
	var best_distance := react_range
	for node in get_tree().get_nodes_in_group("pedestrians"):
		var ped := node as Node3D
		if ped == null:
			continue
		var distance := origin.distance_to(ped.global_position)
		if distance < best_distance:
			best_distance = distance
			best = ped
	return best
