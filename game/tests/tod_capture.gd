extends SceneTree
## Headed visual proof for the time-of-day cycle: boots the downtown district,
## snaps the clock to four key hours and saves a screenshot of each. Needs a
## renderer — run WITHOUT --headless:
##   godot --path game --script res://tests/tod_capture.gd
## Screenshots land in /tmp/tod_<name>.png. Not part of check.sh (CI is headless).

const SHOTS: Array = [
	{"hour": 7.0, "name": "dawn"},
	{"hour": 13.0, "name": "noon"},
	{"hour": 20.0, "name": "dusk"},
	{"hour": 1.0, "name": "night"},
	{"hour": 1.0, "name": "night_street", "street": true},
]
## Frames for the district build + first shot, and between shots (lets glow,
## shadows and exposure settle after each time jump).
const BOOT_FRAMES := 90
## Big time jumps need the sky's radiance/ambient probe and auto-exposure to
## re-converge before the shot, or a night frame still carries the previous
## hour's dusk glow. 60 frames clears it.
const SETTLE_FRAMES := 60

var _frame := 0
var _shot_index := 0
var _staged := false
var _cam: Camera3D
var _anchor := Vector3.ZERO


func _initialize() -> void:
	change_scene_to_file("res://scenes/world/miami.tscn")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < BOOT_FRAMES:
		return false
	if not _staged:
		_stage_camera()
		_staged = true
	var shot: Dictionary = SHOTS[_shot_index]
	if _frame == BOOT_FRAMES:
		_set_hour(float(shot["hour"]))
		if shot.get("street", false):
			_street_level_camera()
	if _frame < BOOT_FRAMES + SETTLE_FRAMES:
		return false
	_save_png(String(shot["name"]))
	_shot_index += 1
	if _shot_index >= SHOTS.size():
		quit(0)
		return true
	_frame = BOOT_FRAMES - 1
	return false


func _set_hour(hour: float) -> void:
	# The day/night clock is the SkyController (group "sky"); the old standalone
	# TimeOfDay node it replaced is gone. Freeze it so the snapped hour holds
	# while the shot settles.
	var tod: Node = current_scene.get_node_or_null("SkyController")
	if tod == null:
		for node in get_nodes_in_group("sky"):
			if node.has_method("set_time_of_day"):
				tod = node
				break
	if tod == null or not tod.has_method("set_time_of_day"):
		push_error("tod_capture: no time-of-day controller in scene")
		quit(1)
		return
	if "day_length_seconds" in tod:
		tod.set("day_length_seconds", 0.0)
	tod.call("set_time_of_day", hour)
	var lamps := get_nodes_in_group("streetlight")
	var lit := 0
	for lamp in lamps:
		if lamp is Node3D and (lamp as Node3D).visible:
			lit += 1
	print("tod_capture: clock set to %05.2f (%d/%d streetlights on)" % [hour, lit, lamps.size()])


## Park a dedicated camera above a street with the skyline filling the frame
## (the player's chase camera would fight any repositioning).
func _stage_camera() -> void:
	var spawn := get_first_node_in_group("spawn_points") as Node3D
	if spawn != null:
		_anchor = spawn.global_position
	_cam = Camera3D.new()
	_cam.name = "TodCaptureCamera"
	current_scene.add_child(_cam)
	_cam.global_position = _anchor + Vector3(110.0, 48.0, 110.0)
	_cam.look_at(_anchor + Vector3(0.0, 26.0, -30.0))
	_cam.make_current()


## Drop to street level so streetlight pools and pole bulbs are visible.
func _street_level_camera() -> void:
	if _cam == null:
		return
	_cam.global_position = _anchor + Vector3(10.0, 3.0, 30.0)
	_cam.look_at(_anchor + Vector3(-10.0, 6.0, -60.0))


func _save_png(name: String) -> void:
	var img := root.get_texture().get_image()
	var path := "/tmp/tod_%s.png" % name
	img.save_png(path)
	print("tod_capture: saved %s" % path)
