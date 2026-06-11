class_name WeatherController
extends Node3D
## Runs a rolling weather front over a scene: advances a WeatherState (pure,
## tested) and turns it into fog, rain, and shiny wet streets — roadmap M4's
## "Weather fronts: clear → overcast → rain, wet-surface materials".
##
## Owns weather only; it never touches the DirectionalLight, so it layers
## cleanly over DayNightCycle (sun) — overcast reads as thickening grey fog, not
## a dimmed sun. Drives: a WorldEnvironment's fog, a GPUParticles3D rain emitter
## (which it parks over the player), and every MeshInstance3D in the
## "wet_surfaces" group (roughness drops as wetness rises, so streets gleam).

## Real seconds for one full front (clear → rain → clear). 120 = a 2-minute front.
@export var front_length_sec: float = 120.0
## Where in the front the scene starts (0 clear, ~0.6 mid-rain).
@export_range(0.0, 1.0) var start_cycle: float = 0.0
@export var environment_path: NodePath
@export var rain_path: NodePath

var _state := WeatherState.new()
var _cycle: float = 0.0
var _env: WorldEnvironment = null
var _rain: GPUParticles3D = null
var _wet_base_roughness: Dictionary = {}


func _ready() -> void:
	add_to_group("weather")  # citizens find it here to comment on the sky
	_cycle = start_cycle
	_env = get_node_or_null(environment_path) as WorldEnvironment
	_rain = get_node_or_null(rain_path) as GPUParticles3D
	_apply()


func _process(delta: float) -> void:
	if front_length_sec > 0.0:
		_cycle = fposmod(_cycle + delta / front_length_sec, 1.0)
	var targets := WeatherState.front_targets(_cycle)
	_state.step(delta, targets["cloud"], targets["rain"])
	_apply()


## Current human-readable condition, e.g. for a debug HUD or weather-anchor barks.
func condition() -> String:
	return _state.label()


func _apply() -> void:
	_apply_fog()
	_apply_rain()
	_apply_wetness()


func _apply_fog() -> void:
	if _env == null or _env.environment == null:
		return
	var env := _env.environment
	env.fog_enabled = true
	# Thicker, greyer air as clouds and rain build.
	env.fog_density = lerpf(0.0006, 0.03, _state.cloudiness) + _state.rain * 0.02
	var clear_air := Color(0.7, 0.74, 0.8)
	var storm_air := Color(0.5, 0.52, 0.56)
	env.fog_light_color = clear_air.lerp(storm_air, _state.cloudiness)


func _apply_rain() -> void:
	if _rain == null:
		return
	var falling := _state.rain > 0.05
	_rain.emitting = falling
	_rain.visible = falling
	# Park the rain volume over the player so it's always where the camera is.
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p := players[0] as Node3D
		if p != null:
			_rain.global_position = p.global_position + Vector3(0.0, 9.0, 0.0)


func _apply_wetness() -> void:
	for node in get_tree().get_nodes_in_group("wet_surfaces"):
		var mi := node as MeshInstance3D
		if mi == null:
			continue
		var mat := mi.material_override as StandardMaterial3D
		if mat == null:
			continue
		if not _wet_base_roughness.has(mi):
			_wet_base_roughness[mi] = mat.roughness
		# Wet asphalt is darker and far glossier than dry.
		mat.roughness = lerpf(float(_wet_base_roughness[mi]), 0.12, _state.wetness)
