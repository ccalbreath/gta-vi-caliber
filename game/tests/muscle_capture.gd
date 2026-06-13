extends SceneTree
## Diagnostic capture of assets/cars/muscle_gta6.glb.
## Renders the imported GLB under a dusk sky with sky-sourced reflections so
## metallic surfaces actually read as metal. Two modes:
##   MODE=raw   -> keep Meshy's baked material untouched (is it rubbery out of the box?)
##   MODE=paint -> keep baked albedo, force car-paint look (metallic^, roughness v, clearcoat)
## Run WITHOUT --headless (needs the GPU):
##   SHOT=/tmp/muscle_raw.png   MODE=raw   godot --path game --script res://tests/muscle_capture.gd
##   SHOT=/tmp/muscle_paint.png MODE=paint godot --path game --script res://tests/muscle_capture.gd

const GLB := "res://assets/cars/muscle_gta6.glb"
const TARGET_LEN := 4.6  # meters, classic muscle car length

var _frames := 0
var _ready := false


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 1000))


func _process(_delta: float) -> bool:
	_frames += 1
	if not _ready and _frames >= 3:
		_build()
		_ready = true
	if _frames < 70:
		return false
	var path := OS.get_environment("SHOT")
	if path == "":
		path = "/tmp/muscle.png"
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("muscle_capture: saved %s (mode=%s)" % [path, OS.get_environment("MODE")])
	quit(0)
	return true


func _build() -> void:
	var packed := load(GLB) as PackedScene
	if packed == null:
		push_error("could not load %s" % GLB)
		quit(1)
		return
	var car := packed.instantiate() as Node3D
	root.add_child(car)

	# --- normalize scale + sit on ground ---
	var aabb := _world_aabb(car)
	var longest: float = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
	if longest > 0.0:
		car.scale *= TARGET_LEN / longest
	aabb = _world_aabb(car)
	var c := aabb.position + aabb.size * 0.5
	car.position -= Vector3(c.x, aabb.position.y, c.z)  # center XZ, rest on y=0

	# --- material treatment ---
	if OS.get_environment("MODE") == "paint":
		_apply_car_paint(car)

	# --- environment: dusk sky + sky reflections ---
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.16, 0.22, 0.40)
	sky_mat.sky_horizon_color = Color(0.92, 0.55, 0.38)
	sky_mat.ground_horizon_color = Color(0.40, 0.30, 0.32)
	sky_mat.ground_bottom_color = Color(0.08, 0.08, 0.10)
	sky_mat.sun_angle_max = 24.0
	sky_mat.energy_multiplier = 1.2
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.ssr_enabled = true
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.15
	world.environment = env
	root.add_child(world)

	# reflective ground so the car has something to sit in
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.05, 0.06, 0.08)
	gmat.metallic = 0.2
	gmat.roughness = 0.35
	ground.mesh.surface_set_material(0, gmat)
	root.add_child(ground)

	# --- key + rim lighting ---
	var key := DirectionalLight3D.new()
	key.light_energy = 2.4
	key.light_color = Color(1.0, 0.94, 0.86)
	key.rotation_degrees = Vector3(-38.0, 35.0, 0.0)
	key.shadow_enabled = true
	root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_energy = 1.4
	rim.light_color = Color(0.45, 0.8, 1.0)
	rim.rotation_degrees = Vector3(-12.0, -135.0, 0.0)
	root.add_child(rim)

	# --- camera: front 3/4 hero framing ---
	var cam := Camera3D.new()
	cam.fov = 40.0
	root.add_child(cam)
	var view := OS.get_environment("VIEW")
	var pos := Vector3(3.6, 1.5, 4.4)  # front 3/4
	if view == "side":
		pos = Vector3(6.5, 1.3, 0.0)
	elif view == "rear":
		pos = Vector3(-3.6, 1.5, -4.4)
	elif view == "close":
		pos = Vector3(2.2, 1.0, 2.6)
	cam.look_at_from_position(pos, Vector3(0.0, 0.7, 0.0), Vector3.UP)
	cam.make_current()


func _apply_car_paint(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var n := mi.mesh.get_surface_count() if mi.mesh else 0
		for s in n:
			var src := mi.get_active_material(s)
			var m := StandardMaterial3D.new()
			# preserve the baked color + normal detail
			if src is BaseMaterial3D:
				var b := src as BaseMaterial3D
				m.albedo_texture = b.albedo_texture
				m.albedo_color = b.albedo_color
				if b.normal_enabled:
					m.normal_enabled = true
					m.normal_texture = b.normal_texture
					m.normal_scale = b.normal_scale
			# force a glossy clearcoat car-paint surface
			m.metallic = 0.9
			m.metallic_specular = 0.6
			m.roughness = 0.28
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
			m.clearcoat_roughness = 0.06
			mi.set_surface_override_material(s, m)
	for child in node.get_children():
		_apply_car_paint(child)


func _world_aabb(node: Node) -> AABB:
	var out := AABB()
	var has := false
	for mi in _all_mesh_instances(node):
		if mi.mesh == null:
			continue
		var a: AABB = mi.global_transform * mi.get_aabb()
		if not has:
			out = a
			has = true
		else:
			out = out.merge(a)
	return out


func _all_mesh_instances(node: Node) -> Array:
	var arr := []
	if node is MeshInstance3D:
		arr.append(node)
	for child in node.get_children():
		arr += _all_mesh_instances(child)
	return arr
