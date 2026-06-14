extends RefCounted
## Functional guards for SouthBeachSurf. The surf line is procedural and
## asset-free, so populate() runs headless: the tests lock in that Miami gets
## three named foam bands, that they sit seaward of the authored shoreline, and
## that the builder stays idempotent.


func test_builds_three_named_bands() -> bool:
	var surf := SouthBeachSurf.new()
	var built := surf.populate()
	var names := PackedStringArray()
	for child in surf.get_children():
		names.append(child.name)
	surf.free()
	names.sort()
	return built == 3 and names == PackedStringArray(["MidBreak", "OuterBreak", "ShoreWash"])


func test_bands_have_mesh_and_shader_material() -> bool:
	var surf := SouthBeachSurf.new()
	surf.populate()
	var ok := true
	for child in surf.get_children():
		var band := child as MeshInstance3D
		if band == null or band.mesh == null or band.mesh.get_surface_count() != 1:
			ok = false
			break
		if band.material_override is not ShaderMaterial:
			ok = false
			break
	surf.free()
	return ok


func test_offset_path_moves_seaward() -> bool:
	var surf := SouthBeachSurf.new()
	var shore := FloridaMapModel.south_beach_shoreline(surf.map_scale)
	var shifted := surf.offset_path(shore, surf.first_band_offset_m)
	surf.free()
	if shore.size() < 2 or shifted.size() != shore.size():
		return false
	var shore_avg_x := 0.0
	var shifted_avg_x := 0.0
	for i in range(shore.size()):
		shore_avg_x += shore[i].x
		shifted_avg_x += shifted[i].x
	shore_avg_x /= float(shore.size())
	shifted_avg_x /= float(shifted.size())
	return shifted_avg_x > shore_avg_x


func test_populate_is_idempotent() -> bool:
	var surf := SouthBeachSurf.new()
	var first := surf.populate()
	var second := surf.populate()
	var made := surf.get_child_count()
	surf.free()
	return first == 3 and second == first and made == 3
