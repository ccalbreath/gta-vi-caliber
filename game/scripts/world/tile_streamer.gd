class_name TileStreamer
extends Node3D
## Streams world tiles in a residency ring around the player (M3 groundwork).
##
## GDScript-first implementation of the design in docs/ARCHITECTURE.md:
## desired set = square ring around the player's tile, loads prioritised by
## the motion vector (TileMath, pure + unit-tested), scene loads on
## ResourceLoader's worker threads, instancing time-sliced on the main
## thread. The future `engine/` async streamer must beat this implementation
## in a captured profile before it earns C++.
##
## Tiles join the tree as children of this node. The tile under the player is
## loaded synchronously in _ready so a clone never boots over a void.

signal tile_loaded(coord: Vector2i)
signal tile_unloaded(coord: Vector2i)

## Scene instantiated per tile; its root must be a WorldTile.
@export_file("*.tscn") var tile_scene_path: String = "res://scenes/world/tiles/greybox_tile.tscn"
## Edge length of one square tile, metres (docs/ARCHITECTURE.md targets 128).
@export var tile_size: float = 128.0
## Rings of tiles kept resident around the player.
@export_range(1, 8) var load_radius: int = 2
## Rings beyond which resident tiles unload. Keep > load_radius: the gap is
## hysteresis so boundary tiles don't thrash on small back-and-forth movement.
@export_range(1, 9) var unload_radius: int = 3
## Tiles instanced per physics frame — the main-thread time-slice.
@export_range(1, 8) var max_instances_per_frame: int = 1
## Seconds between residency scans; loading/instancing still ticks every frame.
@export var scan_interval: float = 0.25

var _resident: Dictionary[Vector2i, Node3D] = {}
var _loading: Dictionary[Vector2i, String] = {}
var _queue: Array[Vector2i] = []
var _scan_timer: float = 0.0
var _last_origin: Vector3 = Vector3.ZERO
var _observed_velocity: Vector3 = Vector3.ZERO
var _loaded_total: int = 0
var _unloaded_total: int = 0


func _ready() -> void:
	add_to_group("tile_streamer")
	var origin := _observer_position()
	_last_origin = origin
	_instance_tile(TileMath.tile_coord(origin, tile_size), load(tile_scene_path) as PackedScene)


func _physics_process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = scan_interval
		_scan(maxf(scan_interval, delta))
	_drain_loads()


## Recompute the desired residency set and queue/unload the difference.
func _scan(elapsed: float) -> void:
	var origin := _observer_position()
	_observed_velocity = (origin - _last_origin) / elapsed
	_last_origin = origin
	var center := TileMath.tile_coord(origin, tile_size)

	var desired := TileMath.desired_set(center, load_radius)
	var missing := TileMath.missing(desired, _resident, _loading)
	for coord in TileMath.load_order(missing, tile_size, origin, _observed_velocity):
		_loading[coord] = tile_scene_path
		if not ResourceLoader.has_cached(tile_scene_path):
			ResourceLoader.load_threaded_request(tile_scene_path)
		_queue.append(coord)

	for coord in TileMath.stale(_resident, center, unload_radius):
		var tile: Node3D = _resident[coord]
		_resident.erase(coord)
		tile.queue_free()
		_unloaded_total += 1
		tile_unloaded.emit(coord)


## Instance queued tiles whose scene has finished loading, a few per frame.
## The cache check first: once any tile finished loading a path, every later
## tile of that path resolves instantly (and a threaded request that was
## already consumed by load_threaded_get would report invalid, not loaded).
func _drain_loads() -> void:
	var budget := max_instances_per_frame
	while budget > 0 and not _queue.is_empty():
		var coord := _queue[0]
		var path: String = _loading[coord]
		var scene: PackedScene = null
		if ResourceLoader.has_cached(path):
			scene = load(path) as PackedScene
		else:
			var status := ResourceLoader.load_threaded_get_status(path)
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				return
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				scene = ResourceLoader.load_threaded_get(path) as PackedScene
		_queue.pop_front()
		_loading.erase(coord)
		if scene == null:
			push_error("tile streamer: failed to load %s for %s" % [path, coord])
			continue
		_instance_tile(coord, scene)
		budget -= 1


func _instance_tile(coord: Vector2i, scene: PackedScene) -> void:
	if _resident.has(coord):
		return
	var tile: WorldTile = scene.instantiate()
	tile.coord = coord
	tile.tile_size = tile_size
	add_child(tile)
	_resident[coord] = tile
	_loaded_total += 1
	tile_loaded.emit(coord)


## Counters for the debug HUD (UI observes; it never drives streaming).
func stats() -> Dictionary:
	return {
		"resident": _resident.size(),
		"loading": _loading.size(),
		"loaded_total": _loaded_total,
		"unloaded_total": _unloaded_total,
	}


func _observer_position() -> Vector3:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return global_position
	return player.global_position
