extends Node3D
## Builds the Biscayne Bay residential islands from the authored BayIslands
## layout: each is a low seawalled land pad (walkable/drivable trimesh-free
## cylinder collision) dressed with a cluster of villa blocks, so the causeways
## thread between real Miami landmarks instead of empty water.
##
## One land cylinder + one StaticBody + one villa MultiMesh per island, all built
## once on _ready from static data. Cheap and always present (the islands sit in
## the gap between streamed districts).

var _land_mat: StandardMaterial3D
var _sand_mat: StandardMaterial3D
var _villa_mat: StandardMaterial3D


func _ready() -> void:
	_make_materials()
	for isle in BayIslands.islands():
		_build_island(isle)


func _make_materials() -> void:
	_land_mat = StandardMaterial3D.new()
	_land_mat.albedo_color = Color(0.40, 0.53, 0.28)  # manicured lawn / palm green
	_land_mat.roughness = 0.95

	_sand_mat = StandardMaterial3D.new()
	_sand_mat.albedo_color = Color(0.87, 0.81, 0.62)  # pale Miami beach sand
	_sand_mat.roughness = 1.0

	_villa_mat = StandardMaterial3D.new()
	_villa_mat.albedo_color = Color(0.93, 0.91, 0.85)  # cream stucco mansions
	_villa_mat.roughness = 0.6


func _build_island(isle: Dictionary) -> void:
	var center: Vector2 = isle["center"]
	var radius: float = isle["radius"]
	var kind: String = isle["kind"]

	var holder := Node3D.new()
	holder.name = "Island_%s" % isle["name"]
	holder.position = Vector3(center.x, 0.0, center.y)
	add_child(holder)

	var height := BayIslands.LAND_Y - BayIslands.FOOT_Y
	var cy := (BayIslands.LAND_Y + BayIslands.FOOT_Y) * 0.5

	# Seawalled land pad: a slightly flared cylinder reads as a concrete rim
	# rising to a flat grassy top.
	var land := CylinderMesh.new()
	land.top_radius = radius
	land.bottom_radius = radius * 1.04
	land.height = height
	land.radial_segments = 28
	land.material = _land_mat
	var mi := MeshInstance3D.new()
	mi.name = "Land"
	mi.mesh = land
	mi.position.y = cy
	holder.add_child(mi)

	# Sand beach skirt at the waterline so the pad reads as a lush island, not a
	# bare green disc.
	var beach := CylinderMesh.new()
	beach.top_radius = radius * 1.06
	beach.bottom_radius = radius * 1.12
	beach.height = 1.4
	beach.radial_segments = 28
	beach.material = _sand_mat
	var bmi := MeshInstance3D.new()
	bmi.name = "Beach"
	bmi.mesh = beach
	bmi.position.y = BayIslands.LAND_Y - 0.5
	holder.add_child(bmi)

	# Walkable/drivable collision (solid cylinder; top face is the lawn).
	var body := StaticBody3D.new()
	body.name = "LandBody"
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	col.position.y = cy
	body.add_child(col)
	holder.add_child(body)

	_build_villas(holder, radius, kind)


## A deterministic cluster of villa blocks ringing the island interior.
func _build_villas(holder: Node3D, radius: float, kind: String) -> void:
	var count := 10
	match kind:
		"luxury":
			count = 14
		"civic":
			count = 7
		"residential":
			count = 9

	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	box.material = _villa_mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = count

	# Two concentric rings of lots fill the pad so islands read as dense estates.
	var seed := int(radius) + count * 31
	for i in count:
		var inner: bool = i % 2 == 0
		var per_ring: float = ceilf(float(count) / 2.0)
		var a := TAU * float(i) / per_ring + float(seed) * 0.13
		var ring_r := radius * (0.34 if inner else 0.66)
		var px := cos(a) * ring_r
		var pz := sin(a) * ring_r
		# Deterministic footprint + height so mansions vary without randomness.
		var w := 12.0 + float((seed + i * 7) % 10)
		var d := 14.0 + float((seed + i * 5) % 12)
		var h := 8.0 + float((seed + i * 3) % 11)
		var basis := Basis.IDENTITY.scaled(Vector3(w, h, d)).rotated(Vector3.UP, a)
		var pos := Vector3(px, BayIslands.LAND_Y + h * 0.5, pz)
		mm.set_instance_transform(i, Transform3D(basis, pos))

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Villas"
	mmi.multimesh = mm
	holder.add_child(mmi)
