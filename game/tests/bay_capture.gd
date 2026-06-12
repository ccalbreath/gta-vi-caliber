extends SceneTree
## Dev-only visual QA shot of Biscayne Bay — frames the causeways + residential
## islands from a chopper-height vantage so the new connective geography can be
## judged by eye (build-probes only prove it constructs). Run WINDOWED:
##   SHOT=/tmp/bay.png godot --path game --script res://tests/bay_capture.gd
## Optional env: CAMX/CAMY/CAMZ (eye) and TGTX/TGTZ (look-at) to reframe.

var _frames := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/world/miami.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 150:
		_setup_cam()
	if _frames < 320:
		return false
	var path := OS.get_environment("SHOT")
	if path == "":
		path = "/tmp/bay.png"
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("bay capture: %s (%dx%d)" % [path, img.get_width(), img.get_height()])
	quit()
	return true


func _setup_cam() -> void:
	var eye := Vector3(_envf("CAMX", 2600.0), _envf("CAMY", 520.0), _envf("CAMZ", 650.0))
	var tgt := Vector3(_envf("TGTX", 2700.0), 0.0, _envf("TGTZ", -650.0))
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.far = 18000.0
	root.add_child(cam)
	cam.global_position = eye
	cam.look_at(tgt, Vector3.UP)
	cam.current = true


func _envf(key: String, fallback: float) -> float:
	var v := OS.get_environment(key)
	return float(v) if v != "" else fallback
