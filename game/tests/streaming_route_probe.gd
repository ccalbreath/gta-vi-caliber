extends SceneTree
## Automated district-boundary drive route for Phase 2 streaming regressions.
##
## The player travels downtown -> Wynwood -> downtown, forcing unload/reload
## crossings while the streamer records background preparation and bounded
## main-thread tile work.

enum RouteState { DOWNTOWN_SETTLE, OUTBOUND, WYNWOOD_SETTLE, RETURN, FINAL_SETTLE }

const SCENE_PATH: String = "res://scenes/world/miami.tscn"
const DOWNTOWN := Vector3(0.0, 2.0, 0.0)
const WYNWOOD := Vector3(-504.0, 2.0, -3364.0)
const DRIVE_FRAMES: int = 180
const MIN_READY_TILES: int = 8
const STATE_TIMEOUT_MSEC: int = 20_000
const ROUTE_TIMEOUT_MSEC: int = 60_000
const MAX_STREAMING_STEP_MS: float = 50.0

var _scene: Node
var _player: CharacterBody3D
var _streamer: Node
var _state: RouteState = RouteState.DOWNTOWN_SETTLE
var _state_frame: int = 0
var _started_msec: int = 0
var _state_started_msec: int = 0
var _saw_wynwood: bool = false
var _saw_downtown_return: bool = false


func _initialize() -> void:
	Engine.max_fps = 120
	_started_msec = Time.get_ticks_msec()
	_state_started_msec = _started_msec
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("scene failed to load")
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	_player = _scene.get_node_or_null("Player") as CharacterBody3D
	_streamer = _scene.get_node_or_null("Streamer")
	if _player == null or _streamer == null:
		_fail("player or streamer missing")


func _process(_delta: float) -> bool:
	if _player == null or _streamer == null:
		return true
	if Time.get_ticks_msec() - _started_msec > ROUTE_TIMEOUT_MSEC:
		_fail("route timed out")
		return true
	if Time.get_ticks_msec() - _state_started_msec > STATE_TIMEOUT_MSEC:
		_fail("state %s timed out" % RouteState.keys()[_state])
		return true

	_state_frame += 1
	_player.global_position = _route_position()
	_player.velocity = Vector3.ZERO

	match _state:
		RouteState.DOWNTOWN_SETTLE:
			if _district_ready("downtown_miami"):
				_advance(RouteState.OUTBOUND)
		RouteState.OUTBOUND:
			if _state_frame >= DRIVE_FRAMES:
				_advance(RouteState.WYNWOOD_SETTLE)
		RouteState.WYNWOOD_SETTLE:
			if _district_ready("wynwood"):
				_saw_wynwood = true
				_advance(RouteState.RETURN)
		RouteState.RETURN:
			if _state_frame >= DRIVE_FRAMES:
				_advance(RouteState.FINAL_SETTLE)
		RouteState.FINAL_SETTLE:
			if _district_ready("downtown_miami"):
				_saw_downtown_return = true
				return _finish()
	return false


func _route_position() -> Vector3:
	match _state:
		RouteState.DOWNTOWN_SETTLE, RouteState.FINAL_SETTLE:
			return DOWNTOWN
		RouteState.OUTBOUND:
			return DOWNTOWN.lerp(WYNWOOD, float(_state_frame) / float(DRIVE_FRAMES))
		RouteState.WYNWOOD_SETTLE:
			return WYNWOOD
		RouteState.RETURN:
			return WYNWOOD.lerp(DOWNTOWN, float(_state_frame) / float(DRIVE_FRAMES))
	return DOWNTOWN


func _district_ready(district_name: String) -> bool:
	var loader := _streamer.get_node_or_null("District_%s" % district_name)
	if loader == null or not loader.has_method("streaming_stats"):
		return false
	var loader_stats: Dictionary = loader.call("streaming_stats")
	return (
		int(loader_stats["tiles_resident"]) >= MIN_READY_TILES
		and float(loader_stats["background_build_ms"]) > 0.0
	)


func _advance(next_state: RouteState) -> void:
	_state = next_state
	_state_frame = 0
	_state_started_msec = Time.get_ticks_msec()


func _finish() -> bool:
	var stats: Dictionary = _streamer.call("stats")
	var failures := PackedStringArray()
	if not _saw_wynwood:
		failures.append("Wynwood never became resident")
	if not _saw_downtown_return:
		failures.append("downtown did not reload on the return crossing")
	if int(stats["district_unloads_total"]) < 2:
		failures.append("expected at least two district unloads")
	if float(stats["initial_load_ms"]) <= 0.0:
		failures.append("initial load timing was not captured")
	if float(stats["background_build_ms"]) <= 0.0:
		failures.append("background preparation timing was not captured")
	if int(stats["tiles_resident"]) < MIN_READY_TILES:
		failures.append("final district did not build enough tiles")
	if float(stats["max_main_thread_step_ms"]) > MAX_STREAMING_STEP_MS:
		failures.append(
			(
				"streaming step %.2f ms exceeded %.2f ms ceiling"
				% [float(stats["max_main_thread_step_ms"]), MAX_STREAMING_STEP_MS]
			)
		)
	if int(stats["peak_operations_per_frame"]) > 1:
		failures.append("streamer performed more than one bounded operation in a frame")

	if not failures.is_empty():
		for failure: String in failures:
			push_error("streaming route probe FAIL :: %s" % failure)
		quit(1)
		return true
	print(
		(
			(
				"streaming route probe: OK initial=%.1f ms background=%.1f ms "
				+ "max_step=%.2f ms (%s) tile_step=%.2f ms (%s) "
				+ "loads=%d unloads=%d tiles=%d/%d"
			)
			% [
				float(stats["initial_load_ms"]),
				float(stats["background_build_ms"]),
				float(stats["max_main_thread_step_ms"]),
				str(stats["max_main_thread_step_kind"]),
				float(stats["max_tile_commit_ms"]),
				str(stats["max_tile_commit_kind"]),
				int(stats["district_loads_total"]),
				int(stats["district_unloads_total"]),
				int(stats["tiles_resident"]),
				int(stats["tiles_total"]),
			]
		)
	)
	quit(0)
	return true


func _fail(message: String) -> void:
	push_error("streaming route probe FAIL :: %s" % message)
	quit(1)
