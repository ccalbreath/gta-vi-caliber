extends SceneTree
## Integration test for the Ocean node: it builds a displaced grid mesh and its
## surface heaves over time (so boats sampling surface_height actually bob). The
## Gerstner math itself is unit-tested in test_ocean_waves.gd; this guards the
## node — mesh assembly, vertex count, and the world-space buoyancy sample.
## Run: godot --headless --path game --script res://tests/ocean_capture.gd

var _ocean: Ocean = null
var _frame := 0
var _h0 := 0.0
var _failures: PackedStringArray = []


func _initialize() -> void:
	_ocean = Ocean.new()
	_ocean.name = "Ocean"
	_ocean.subdivisions = 16
	_ocean.plane_size = 64.0
	root.add_child(_ocean)
	_ocean.set_process(false)  # drive time by hand for determinism
	_h0 = _ocean.surface_height(5.0, 5.0)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 3:
		return false
	# Advance ocean time and rebuild a few times.
	for _i in 5:
		_ocean._process(0.4)
	_check()
	return _finish()


func _check() -> void:
	var m := _ocean.mesh as ArrayMesh
	if m == null or m.get_surface_count() < 1:
		_fail("ocean built no mesh surface")
		return
	var verts: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var expected := (16 + 1) * (16 + 1)
	if verts.size() != expected:
		_fail("ocean grid has %d verts, expected %d" % [verts.size(), expected])
	# The surface should have moved at our sample point after time passed.
	if absf(_ocean.surface_height(5.0, 5.0) - _h0) < 0.0001:
		_fail("ocean surface did not heave over time")


func _fail(message: String) -> void:
	_failures.append(message)


func _finish() -> bool:
	if _failures.is_empty():
		print("ocean: OK — Gerstner sea built a live mesh and heaved at the buoyancy sample")
		quit(0)
	else:
		for f in _failures:
			push_error("ocean: %s" % f)
		quit(1)
	return true
