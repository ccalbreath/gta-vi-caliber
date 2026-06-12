extends SceneTree
## High-res hero/quality capture tool (M6 visual-review workflow).
## Renders a scene at a chosen resolution from a free camera so building/material
## quality can be judged without streaming pop-in or the third-person rig.
## Run WITHOUT --headless (needs the GPU):
##   SCENE=res://scenes/world/miami.tscn \
##   CAMPOS=80,14,90 CAMLOOK=0,40,0 TOD=16 RES=1920x1080 \
##   SHOT=/tmp/hero.png godot --path game --script res://tests/hero_capture.gd
##
## Env vars (all optional):
##   SCENE   res:// path           (default downtown_la)
##   CAMPOS  "x,y,z" camera pos    (default 90,16,110)
##   CAMLOOK "x,y,z" look target   (default 0,35,0)
##   TOD     hour 0-24             (force time of day if a DayNightCycle exists)
##   RES     "WxH"                 (default 1920x1080)
##   FOV     vertical degrees      (default 55)
##   SETTLE  frames before shot    (default 240 — lets streaming/AA/SDFGI converge)
##   SHOT    output png            (default /tmp/gta6_hero.png)

var _frames := 0
var _cam: Camera3D


func _initialize() -> void:
	var res := _vec2i(OS.get_environment("RES"), Vector2i(1920, 1080))
	DisplayServer.window_set_size(res)
	var scene := OS.get_environment("SCENE")
	if scene == "":
		scene = "res://scenes/world/miami.tscn"
	change_scene_to_file(scene)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 20:
		_setup()
	var settle := int(OS.get_environment("SETTLE")) if OS.get_environment("SETTLE") != "" else 240
	if _frames < settle:
		return false
	var path := OS.get_environment("SHOT")
	if path == "":
		path = "/tmp/gta6_hero.png"
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("hero captured: %s (%dx%d)" % [path, img.get_width(), img.get_height()])
	quit()
	return true


func _setup() -> void:
	var tod := OS.get_environment("TOD")
	if tod != "":
		var cyc := root.find_child("DayNightCycle", true, false)
		if cyc == null:
			cyc = root.find_child("DayNight", true, false)
		if cyc != null and cyc.has_method("set_time_of_day"):
			if "day_length_seconds" in cyc:
				cyc.day_length_seconds = 0.0
			cyc.set_time_of_day(float(tod))
			print("hero: set time_of_day=%s on %s" % [tod, cyc.get_path()])
		else:
			print("hero: WARNING no DayNightCycle with set_time_of_day")
	var pos := _vec3(OS.get_environment("CAMPOS"), Vector3(90, 16, 110))
	var look := _vec3(OS.get_environment("CAMLOOK"), Vector3(0, 35, 0))
	_cam = Camera3D.new()
	_cam.far = 6000.0
	_cam.fov = float(OS.get_environment("FOV")) if OS.get_environment("FOV") != "" else 55.0
	var host := current_scene
	if host == null:
		host = root
	host.add_child(_cam)
	_cam.global_position = pos
	_cam.look_at(look, Vector3.UP)
	_cam.make_current()
	print("hero: cam %s -> %s" % [pos, look])


func _vec3(raw: String, fallback: Vector3) -> Vector3:
	if not raw.contains(","):
		return fallback
	var p := raw.split(",")
	if p.size() < 3:
		return fallback
	return Vector3(p[0].to_float(), p[1].to_float(), p[2].to_float())


func _vec2i(raw: String, fallback: Vector2i) -> Vector2i:
	if not raw.contains("x"):
		return fallback
	var p := raw.split("x")
	if p.size() < 2:
		return fallback
	return Vector2i(int(p[0]), int(p[1]))
