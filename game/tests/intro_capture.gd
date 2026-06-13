extends SceneTree
## GPU still-capture tool for the boot cinematic — renders intro_sequence.tscn at
## chosen clock times so each beat (studio sting, title ignite, light-sweep,
## settle) can be judged by pixels. The intro's own clock is frozen and driven
## manually so each shot lands on an exact beat. Run WITHOUT --headless (needs
## the GPU):
##   godot --path game --script res://tests/intro_capture.gd
## Env (optional): DIR output dir (default /tmp), RES "WxH" (default 1600x900),
##   TIMES "1.0,4.6,6.3,8.2" clock seconds, NAMES "sting,ignite,sweep,settle".

const SETTLE_FRAMES: int = 36

var _intro: Node = null
var _times: PackedFloat32Array = PackedFloat32Array([1.0, 4.6, 6.3, 8.2])
var _names: PackedStringArray = PackedStringArray(["sting", "ignite", "sweep", "settle"])
var _dir: String = "/tmp"
var _index: int = -1
var _wait: int = 0


func _initialize() -> void:
	var res := _parse_res(OS.get_environment("RES"), Vector2i(1600, 900))
	DisplayServer.window_set_size(res)
	var env_dir := OS.get_environment("DIR")
	if env_dir != "":
		_dir = env_dir
	_parse_times(OS.get_environment("TIMES"), OS.get_environment("NAMES"))

	var packed := load("res://scenes/ui/intro_sequence.tscn") as PackedScene
	if packed == null:
		push_error("intro_capture: could not load res://scenes/ui/intro_sequence.tscn")
		quit(1)
		return
	_intro = packed.instantiate()
	_intro.set("enable_audio", false)
	root.add_child(_intro)
	# Freeze the timeline so we can pose it at exact beats; children (the dusk sky
	# and the draw layers) keep animating and redrawing on their own.
	_intro.set_process(false)
	_intro.set_physics_process(false)


func _process(_delta: float) -> bool:
	if _index < 0:
		_advance()
		return false

	_wait += 1
	# Re-pose every frame so the layers redraw against the frozen clock.
	_intro.set("_clock", _times[_index])
	_intro.call("_update_state")
	_intro.call("_apply_to_nodes")

	if _wait < SETTLE_FRAMES:
		return false

	var path := "%s/intro_%02d_%s.png" % [_dir, _index + 1, _names[_index]]
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("intro captured: %s  (t=%.2fs)" % [path, _times[_index]])

	if _index + 1 >= _times.size():
		quit(0)
		return true
	_advance()
	return false


func _advance() -> void:
	_index += 1
	_wait = 0


func _parse_res(text: String, fallback: Vector2i) -> Vector2i:
	var parts := text.split("x")
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		return Vector2i(int(parts[0]), int(parts[1]))
	return fallback


func _parse_times(times_text: String, names_text: String) -> void:
	if times_text == "":
		return
	var t := PackedFloat32Array()
	for piece in times_text.split(","):
		if piece.is_valid_float():
			t.append(float(piece))
	if t.is_empty():
		return
	_times = t
	var n := PackedStringArray()
	var name_pieces := names_text.split(",") if names_text != "" else PackedStringArray()
	for i in _times.size():
		n.append(name_pieces[i] if i < name_pieces.size() else "shot%d" % (i + 1))
	_names = n
