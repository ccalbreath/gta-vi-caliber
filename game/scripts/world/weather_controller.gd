extends Node3D
## Applies the tested Weather model to the live scene: drives environment fog and
## a rain particle system that follows the player, and (optionally) cycles
## conditions over time. The pure rules live in Weather (tested); this node is the
## visual integration — sky/particles/wetness.

@export var auto_cycle: bool = true
@export var seconds_per_condition: float = 45.0
@export var start_condition: Weather.Condition = Weather.Condition.CLEAR
@export var rain_height: float = 35.0

var _weather: Weather
var _env: WorldEnvironment
var _rain: GPUParticles3D
var _timer: float = 0.0


func _ready() -> void:
	_weather = Weather.new()
	_weather.set_condition(start_condition)
	_env = _find_environment()
	_rain = _make_rain()
	add_child(_rain)
	_apply()


func _process(delta: float) -> void:
	_weather.update(delta)
	if auto_cycle:
		_timer += delta
		if _timer >= seconds_per_condition:
			_timer = 0.0
			_weather.set_condition((_weather.condition + 1) % Weather.Condition.size())
	_follow_player()
	_apply()


func _apply() -> void:
	if _env != null and _env.environment != null:
		_env.environment.fog_density = _weather.fog_density()
	_rain.emitting = _weather.is_raining()
	_rain.amount_ratio = clampf(_weather.rain_intensity(), 0.05, 1.0)


func _follow_player() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node3D:
			var pos := (p as Node3D).global_position
			_rain.global_position = Vector3(pos.x, pos.y + rain_height, pos.z)
			return


func _make_rain() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 1400
	p.lifetime = 1.4
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-50, -60, -50), Vector3(100, 80, 100))

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 2.0
	mat.gravity = Vector3(0, -35, 0)
	mat.initial_velocity_min = 12.0
	mat.initial_velocity_max = 16.0
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(45, 1, 45)
	p.process_material = mat

	var drop := BoxMesh.new()
	drop.size = Vector3(0.02, 0.45, 0.02)
	var drop_mat := StandardMaterial3D.new()
	drop_mat.albedo_color = Color(0.6, 0.7, 0.85, 0.6)
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = drop_mat
	p.draw_pass_1 = drop
	return p


func _find_environment() -> WorldEnvironment:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is WorldEnvironment:
			return child
	return null
