extends SceneTree
## Integration test for WeatherController: pins the front to its rain band and
## confirms the node turns weather into scene state — rain emitter on, fog
## thickened, streets gone glossy — then pins it clear and confirms it dries out.
## The front/wetness math is unit-tested in test_weather_state.gd; this guards the
## node wiring (env fog, rain particles, the wet_surfaces group).
## Run: godot --headless --path game --script res://tests/weather_capture.gd

const RAIN_FRAMES := 60
const DRY_FRAMES := 120

var _ctl: WeatherController = null
var _env: WorldEnvironment = null
var _rain: GPUParticles3D = null
var _ground: MeshInstance3D = null
var _frame := 0
var _phase := "rain"
var _wet := {}
var _failures: PackedStringArray = []


func _initialize() -> void:
	_env = WorldEnvironment.new()
	_env.name = "WorldEnvironment"
	_env.environment = Environment.new()
	root.add_child(_env)

	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.emitting = false
	root.add_child(_rain)

	_ground = MeshInstance3D.new()
	_ground.name = "Ground"
	_ground.mesh = PlaneMesh.new()
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.9
	_ground.material_override = mat
	_ground.add_to_group("wet_surfaces")
	root.add_child(_ground)

	_ctl = WeatherController.new()
	_ctl.name = "WeatherController"
	_ctl.environment_path = NodePath("../WorldEnvironment")
	_ctl.rain_path = NodePath("../Rain")
	root.add_child(_ctl)
	_ctl.set_process(false)  # drive deterministically below


func _process(_delta: float) -> bool:
	_frame += 1
	match _phase:
		"rain":
			_ctl._cycle = 0.625  # pin to peak rain
			_ctl._process(0.1)
			if _frame >= RAIN_FRAMES:
				_capture_rain()
				_phase = "dry"
				_frame = 0
		"dry":
			_ctl._cycle = 0.0  # pin to clear
			_ctl._process(0.1)
			if _frame >= DRY_FRAMES:
				_check_dry()
				return _finish()
	return _phase == "done"


func _roughness() -> float:
	return (_ground.material_override as StandardMaterial3D).roughness


func _capture_rain() -> void:
	_wet = {
		"emitting": _rain.emitting,
		"fog": _env.environment.fog_density,
		"roughness": _roughness(),
	}
	if not bool(_wet["emitting"]):
		_fail("rain emitter did not switch on during the rain band")
	if float(_wet["fog"]) <= 0.01:
		_fail("fog did not thicken in the rain (%.4f)" % _wet["fog"])
	if float(_wet["roughness"]) >= 0.9:
		_fail("streets did not get wet/glossy (roughness %.2f)" % _wet["roughness"])
	if _ctl.condition() != "rain":
		_fail("condition is '%s', expected 'rain'" % _ctl.condition())


func _check_dry() -> void:
	if _rain.emitting:
		_fail("rain emitter still on after the front cleared")
	# Surfaces should be drying back toward their base roughness.
	if _roughness() <= float(_wet["roughness"]):
		_fail(
			(
				"streets did not dry out (roughness %.2f vs wet %.2f)"
				% [_roughness(), _wet["roughness"]]
			)
		)


func _fail(message: String) -> void:
	_failures.append(message)


func _finish() -> bool:
	_phase = "done"
	if _failures.is_empty():
		print(
			(
				"weather: OK — front rained (roughness %.2f, fog %.4f) then cleared and dried"
				% [float(_wet["roughness"]), float(_wet["fog"])]
			)
		)
		quit(0)
	else:
		for f in _failures:
			push_error("weather: %s" % f)
		quit(1)
	return true
