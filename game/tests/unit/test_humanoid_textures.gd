extends RefCounted
## Unit tests for the procedural detail-normal maps. They must be deterministic,
## correctly sized, normal-encoded (blue-dominant), varied, and cached.


func test_skin_normal_is_correct_size() -> bool:
	var t := HumanoidTextures.skin_normal()
	return (
		t != null
		and t.get_width() == HumanoidTextures.SIZE
		and t.get_height() == HumanoidTextures.SIZE
	)


func test_normal_map_is_blue_dominant() -> bool:
	# A normal map points mostly +Z (out of the surface): blue channel ~ 1.0.
	var img := HumanoidTextures.skin_normal().get_image()
	var sum := 0.0
	var n := 0
	for y in range(0, HumanoidTextures.SIZE, 8):
		for x in range(0, HumanoidTextures.SIZE, 8):
			sum += img.get_pixel(x, y).b
			n += 1
	return sum / float(n) > 0.55


func test_cached_instance_is_shared() -> bool:
	# Generated once and reused, so a crowd doesn't re-bake per body.
	var first := HumanoidTextures.skin_normal()
	var second := HumanoidTextures.skin_normal()
	return first == second


func test_skin_and_fabric_are_distinct() -> bool:
	return HumanoidTextures.skin_normal() != HumanoidTextures.fabric_normal()


func test_skin_has_lateral_variation() -> bool:
	# If the surface were dead flat every red value would be 0.5; pores vary it.
	var img := HumanoidTextures.skin_normal().get_image()
	var lo := 1.0
	var hi := 0.0
	for y in range(0, HumanoidTextures.SIZE, 4):
		for x in range(0, HumanoidTextures.SIZE, 4):
			var r := img.get_pixel(x, y).r
			lo = minf(lo, r)
			hi = maxf(hi, r)
	return hi - lo > 0.02


func test_fabric_has_directional_structure() -> bool:
	# The weave is not flat either.
	var img := HumanoidTextures.fabric_normal().get_image()
	var lo := 1.0
	var hi := 0.0
	for y in range(0, HumanoidTextures.SIZE, 4):
		for x in range(0, HumanoidTextures.SIZE, 4):
			var g := img.get_pixel(x, y).g
			lo = minf(lo, g)
			hi = maxf(hi, g)
	return hi - lo > 0.02


func test_skin_albedo_is_bright_and_varied() -> bool:
	# An albedo multiplier: near-white (preserves skin_color) but not dead-flat.
	var img := HumanoidTextures.skin_albedo().get_image()
	var lo := 1.0
	var hi := 0.0
	for y in range(0, HumanoidTextures.SIZE, 4):
		for x in range(0, HumanoidTextures.SIZE, 4):
			var g := img.get_pixel(x, y).g
			lo = minf(lo, g)
			hi = maxf(hi, g)
	return lo > 0.8 and hi <= 1.0 and hi - lo > 0.02


func test_albedo_maps_are_cached() -> bool:
	var first := HumanoidTextures.fabric_albedo()
	var second := HumanoidTextures.fabric_albedo()
	return first == second
