extends SceneTree

const SCENE_PATH: String = "res://scenes/world/miami.tscn"
const WARMUP_FRAMES: int = 180
const STREAMED_SETTLE_FRAMES: int = 120
const MAX_WAIT_MSEC: int = 30_000
const TILE_SIZE: float = 128.0
const VISIBLE_GROUND_Y: float = 0.4
const TOLERANCE: float = 0.06

var _scene: Node = null
var _frames: int = 0
var _started_msec: int = 0
var _streamed_frames: int = 0


func _initialize() -> void:
	Engine.max_fps = 120
	_started_msec = Time.get_ticks_msec()
	var packed_scene := load(SCENE_PATH) as PackedScene
	if packed_scene == null:
		_fail("Could not load %s" % SCENE_PATH)
		return
	_scene = packed_scene.instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false

	var player := _scene.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		_fail("Player is missing")
		return true
	if _player_ground_tile_ready(player):
		_streamed_frames += 1
		if _streamed_frames < STREAMED_SETTLE_FRAMES:
			return false
	elif Time.get_ticks_msec() - _started_msec < MAX_WAIT_MSEC:
		_streamed_frames = 0
		return false
	_run_checks(player)
	return true


func _run_checks(player: CharacterBody3D) -> void:
	var rig := player.get_node_or_null("Rig") as Node3D
	if rig == null:
		_fail("Player rig is missing")
		return
	var feet_y := _visible_mesh_bottom(rig)
	if absf(feet_y - VISIBLE_GROUND_Y) > TOLERANCE:
		_fail("Player feet are at %.2f, expected %.2f" % [feet_y, VISIBLE_GROUND_Y])
		return
	if not player.is_on_floor():
		_fail("Player is not grounded after warmup")
		return

	print("PLAYER_GROUND_PROBE PASS: feet=%.2f surface=%.2f" % [feet_y, VISIBLE_GROUND_Y])
	quit(0)


func _player_ground_tile_ready(player: Node3D) -> bool:
	var player_coord := TileMath.tile_coord(player.global_position, TILE_SIZE)
	for tile: Node in get_nodes_in_group("district_tile"):
		if (
			tile.has_meta("coord")
			and tile.get_meta("coord") == player_coord
			and tile.has_node("Ground")
		):
			return true
	return false


func _visible_mesh_bottom(root_node: Node) -> float:
	var bottom_y := INF
	for child in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or not mesh_instance.is_visible_in_tree():
			continue
		var bounds := mesh_instance.global_transform * mesh_instance.get_aabb()
		bottom_y = minf(bottom_y, bounds.position.y)
	return bottom_y


func _fail(message: String) -> void:
	push_error("PLAYER_GROUND_PROBE FAIL: %s" % message)
	quit(1)
