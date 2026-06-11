class_name Weather
extends RefCounted
## Weather model: a condition (clear → overcast → rain → storm) drives rain
## intensity, fog density, and cloud cover, plus a ground-wetness value that lags
## behind the rain (puddles build up and dry out). Pure and scene-free so it
## unit-tests headless (tests/unit/test_weather.gd); a sky/particle layer reads
## the outputs.

enum Condition { CLEAR, OVERCAST, RAIN, STORM }

const RAIN_INTENSITY := {
	Condition.CLEAR: 0.0, Condition.OVERCAST: 0.0, Condition.RAIN: 0.6, Condition.STORM: 1.0
}
const FOG_DENSITY := {
	Condition.CLEAR: 0.0006,
	Condition.OVERCAST: 0.0012,
	Condition.RAIN: 0.002,
	Condition.STORM: 0.0035
}
const CLOUD_COVER := {
	Condition.CLEAR: 0.1, Condition.OVERCAST: 0.7, Condition.RAIN: 0.85, Condition.STORM: 1.0
}
const WET_RATE := 0.1  # wetness gained per second while raining
const DRY_RATE := 0.05  # wetness lost per second while dry

var condition: Condition = Condition.CLEAR
var wetness: float = 0.0  # 0 (dry) … 1 (soaked)


func set_condition(c: Condition) -> void:
	condition = c


## Advance puddle wetness over `delta` seconds based on the current condition.
func update(delta: float) -> void:
	if rain_intensity() > 0.0:
		wetness = minf(1.0, wetness + delta * WET_RATE)
	else:
		wetness = maxf(0.0, wetness - delta * DRY_RATE)


func rain_intensity() -> float:
	return RAIN_INTENSITY[condition]


func fog_density() -> float:
	return FOG_DENSITY[condition]


func cloud_cover() -> float:
	return CLOUD_COVER[condition]


func is_raining() -> bool:
	return rain_intensity() > 0.0


func is_wet() -> bool:
	return wetness > 0.01
