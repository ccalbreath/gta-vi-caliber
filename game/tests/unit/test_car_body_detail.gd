extends RefCounted
## Headless coverage for CarBody's premium detail: the paint clearcoat and the
## emissive head/tail-light + trim materials, plus the nose/tail light layout.
## CarBody itself is a runtime Node3D, but its material + landmark logic is static
## and scene-free, so it tests without a tree (same pattern as test_car_mesh).

const CarBodyScript := preload("res://scripts/vehicles/car_body.gd")


func test_paint_has_metallic_clearcoat() -> bool:
	var mat := CarBodyScript.paint_material(Color(0.74, 0.18, 0.15))
	return (
		mat != null
		and mat.clearcoat_enabled
		and mat.clearcoat > 0.5
		and mat.metallic > 0.5
		and mat.roughness < 0.35
		and mat.albedo_color.is_equal_approx(Color(0.74, 0.18, 0.15))
	)


func test_headlight_is_warm_emissive() -> bool:
	var mat := CarBodyScript.headlight_material()
	# Emissive and warm: red/green well above blue, real emission energy.
	return (
		mat != null
		and mat.emission_enabled
		and mat.emission_energy_multiplier > 1.0
		and mat.emission.r >= mat.emission.b
		and mat.emission.g >= mat.emission.b
	)


func test_taillight_is_red_emissive() -> bool:
	var mat := CarBodyScript.taillight_material()
	return (
		mat != null
		and mat.emission_enabled
		and mat.emission_energy_multiplier > 1.0
		and mat.emission.r > 0.5
		and mat.emission.r > mat.emission.g * 4.0
		and mat.emission.r > mat.emission.b * 4.0
	)


func test_trim_is_dark_satin() -> bool:
	var mat := CarBodyScript.trim_material()
	return mat != null and mat.albedo_color.v < 0.1 and mat.roughness < 0.5


func test_plate_is_legible_but_dim() -> bool:
	var mat := CarBodyScript.plate_material()
	# Lit enough to read at night, but not a headlight.
	return (
		mat != null
		and mat.emission_enabled
		and mat.emission_energy_multiplier > 0.0
		and mat.emission_energy_multiplier < 1.0
		and mat.albedo_color.v > 0.6
	)


func test_lights_sit_at_correct_ends() -> bool:
	# Headlights at the nose (-Z), taillights at the tail (+Z), each mirrored on X.
	return (
		CarBodyScript.NOSE_Z < 0.0
		and CarBodyScript.TAIL_Z > 0.0
		and CarBodyScript.HEADLIGHT.x > 0.0
		and CarBodyScript.TAILLIGHT.x > 0.0
		and CarBodyScript.HEADLIGHT.y > 0.3
		and CarBodyScript.TAILLIGHT.y > 0.3
	)
