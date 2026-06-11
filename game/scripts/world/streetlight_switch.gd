class_name StreetlightSwitch
extends Node
## Fades a streetlight material's emission with the day/night cycle so lamps glow
## at night and go dark by day, instead of being always-on props. Reads the
## shared `world_night_amount` global that SkyController publishes (one clock for
## the whole world) and drives the emission each frame. The pure mapping is in
## lamp_energy(); attach with a material + its lit energy via setup().

## Global shader parameter SkyController publishes: 0 = full day, 1 = full night.
const NIGHT_PARAM: StringName = &"world_night_amount"

var _material: StandardMaterial3D = null
var _full_energy: float = 2.5


## Emission energy for a night level: off in daylight, ramping to full at night.
static func lamp_energy(night_amount: float, full_energy: float) -> float:
	return full_energy * clampf(night_amount, 0.0, 1.0)


## Bind the lamp material whose emission this should drive, and the energy it
## reaches at full night (its authored daytime/peak emission multiplier).
func setup(material: StandardMaterial3D, full_energy: float) -> void:
	_material = material
	_full_energy = full_energy


func _process(_delta: float) -> void:
	if _material == null:
		return
	# The global is unset until SkyController publishes it; treat absent as day.
	var raw: Variant = RenderingServer.global_shader_parameter_get(NIGHT_PARAM)
	var night: float = raw if raw is float else 0.0
	_material.emission_energy_multiplier = lamp_energy(night, _full_energy)
