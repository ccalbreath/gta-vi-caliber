extends DirectionalLight3D
## Drives a live day/night cycle: advances time-of-day and applies the sun angle,
## light energy, and sky horizon tint from GameClock (tested). Attach to the Sun
## DirectionalLight3D; it finds the sibling WorldEnvironment to tint the sky.

@export var minutes_per_second: float = 60.0  # 1 real second = 1 game minute
@export var start_hour: float = 9.0
## Multiplies the computed sun energy — lets a scene push a brighter, punchier
## key light than the baseline day curve without editing the shared GameClock.
@export var energy_scale: float = 1.0

var _time: float = 9.0
var _env: WorldEnvironment


func _ready() -> void:
	_time = start_hour
	_env = _find_environment()
	_apply()


func _process(delta: float) -> void:
	_time = fmod(_time + delta * minutes_per_second / 60.0, GameClock.DAY_HOURS)
	_apply()


func _apply() -> void:
	rotation_degrees = Vector3(
		-GameClock.sun_elevation_deg(_time), GameClock.sun_azimuth_deg(_time), 0.0
	)
	light_energy = GameClock.light_energy(_time) * energy_scale
	# Share one day/night clock with world materials: feed the facade shader's
	# window-emission global (GPU) and the streetlamp CPU channel so lit windows
	# and streetlights come on at dusk in this scene too.
	var night := GameClock.night_amount(_time)
	RenderingServer.global_shader_parameter_set("world_night_amount", night)
	StreetlightSwitch.night_level = night
	if _env == null or _env.environment == null:
		return
	var sky := _env.environment.sky
	if sky != null and sky.sky_material is ProceduralSkyMaterial:
		var mat := sky.sky_material as ProceduralSkyMaterial
		var tint := GameClock.horizon_color(_time)
		mat.sky_horizon_color = tint
		mat.ground_horizon_color = tint


func _find_environment() -> WorldEnvironment:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is WorldEnvironment:
			return child
	return null
