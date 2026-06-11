extends SceneTree
## Integration test for the buoyancy bridge: drop a rigid crate above the Gerstner
## ocean and confirm the Floater catches it — it sinks from the drop height, then
## settles to bob around the surface instead of plummeting through. Ties Ocean +
## Buoyancy + Floater into actual physics. The math is unit-tested separately
## (test_buoyancy.gd / test_ocean_waves.gd); this proves the forces reach a body.
## Run: godot --headless --path game --script res://tests/floater_capture.gd

const SETTLE_FRAMES := 360

var _ocean: Ocean = null
var _crate: RigidBody3D = null
var _frame := 0
var _drop_y := 5.0
var _failures: PackedStringArray = []


func _initialize() -> void:
	_ocean = Ocean.new()
	_ocean.name = "Ocean"
	_ocean.subdivisions = 8
	_ocean.plane_size = 40.0
	root.add_child(_ocean)  # sits at y = 0, joins group "water"

	_crate = RigidBody3D.new()
	_crate.name = "Crate"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 0.6, 1)
	col.shape = box
	_crate.add_child(col)
	var floater := Floater.new()
	_crate.add_child(floater)
	root.add_child(_crate)
	_crate.global_position = Vector3(0, _drop_y, 0)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return false
	_check()
	return _finish()


func _check() -> void:
	var y := _crate.global_position.y
	# It must have fallen from the drop height (buoyancy isn't holding it in the air)...
	if y > _drop_y - 1.0:
		_fail("crate never fell from the drop height (y = %.2f)" % y)
	# ...but must NOT have sunk through the sea (buoyancy caught it near the surface).
	if y < -2.0:
		_fail("crate sank through the ocean (y = %.2f)" % y)
	if y > 2.5:
		_fail("crate is floating implausibly high (y = %.2f)" % y)


func _fail(message: String) -> void:
	_failures.append(message)


func _finish() -> bool:
	if _failures.is_empty():
		print(
			(
				"floater: OK — crate dropped and settled to bob on the waves (y = %.2f)"
				% _crate.global_position.y
			)
		)
		quit(0)
	else:
		for f in _failures:
			push_error("floater: %s" % f)
		quit(1)
	return true
