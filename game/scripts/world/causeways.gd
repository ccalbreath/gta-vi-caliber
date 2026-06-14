extends Node3D
## Builds the physical, drivable causeways over Biscayne Bay from the authored
## CausewayNetwork layout — arched asphalt decks with trimesh collision (so the
## player and vehicles can drive across), edge railings, and support pillars
## marching down into the water. This is the connective tissue that makes the
## five paged Miami districts feel like one continuous Florida map.
##
## One mesh + one StaticBody per causeway; pillars are a single MultiMesh. Built
## once on _ready from static data, so it is cheap and always present (no
## streaming needed — the spans are the bridge BETWEEN streamed districts).

## Vertical thickness of the deck slab (visual underside + railing footing).
const DECK_THICKNESS: float = 0.6
## Railing height above the deck surface.
const RAIL_HEIGHT: float = 0.95
## Spacing between support pillars along each deck.
const PILLAR_SPACING: float = 64.0
## Pillar radius.
const PILLAR_RADIUS: float = 1.1
## How far below the water the pillars are footed.
const SEABED_Y: float = CausewayNetwork.WATER_Y - 9.0

var _road_mat: Material
var _rail_mat: Material
var _pillar_mat: Material


func _ready() -> void:
	_make_materials()
	for c in CausewayNetwork.causeways():
		_build_causeway(c)


func _make_materials() -> void:
	# Reuse the district asphalt shader so the deck matches street surfaces;
	# fall back to greybox if the shader is missing (keeps the scene importable).
	_road_mat = _shader_or_fallback("res://shaders/road.gdshader", Color(0.33, 0.32, 0.31))
	if (
		_road_mat is ShaderMaterial
		and ResourceLoader.exists("res://assets/textures/asphalt_albedo.png")
	):
		(_road_mat as ShaderMaterial).set_shader_parameter(
			"detail_tex", load("res://assets/textures/asphalt_albedo.png")
		)

	var rail := StandardMaterial3D.new()
	rail.albedo_color = Color(0.72, 0.74, 0.78)
	rail.metallic = 0.7
	rail.roughness = 0.45
	_rail_mat = rail

	var pillar := StandardMaterial3D.new()
	pillar.albedo_color = Color(0.78, 0.77, 0.73)
	pillar.roughness = 0.85
	_pillar_mat = pillar


func _build_causeway(c: Dictionary) -> void:
	var points: PackedVector2Array = c["points"]
	var width: float = c["width"]
	var rise: float = c["rise"]
	if points.size() < 2:
		return

	var holder := Node3D.new()
	holder.name = "Causeway_%s" % c["name"]
	add_child(holder)

	var deck_mesh := _deck_mesh(points, width, rise)
	if deck_mesh == null:
		return
	deck_mesh.surface_set_material(0, _road_mat)

	# Visible deck.
	var mi := MeshInstance3D.new()
	mi.name = "Deck"
	mi.mesh = deck_mesh
	holder.add_child(mi)

	# Drivable collision from the same surface.
	var body := StaticBody3D.new()
	body.name = "DeckBody"
	var col := CollisionShape3D.new()
	col.shape = deck_mesh.create_trimesh_shape()
	body.add_child(col)
	holder.add_child(body)

	_add_railings(holder, points, width, rise)
	_add_pillars(holder, points, rise)


## Arched ribbon deck: walk the centreline, lift each cross-section to the arch
## height for its span fraction, and bridge consecutive sections with quads.
func _deck_mesh(points: PackedVector2Array, width: float, rise: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var uvs := PackedVector2Array()

	var total := CausewayNetwork.length_of(points)
	var half := width * 0.5
	var travelled := 0.0

	for i in points.size():
		if i > 0:
			travelled += points[i].distance_to(points[i - 1])
		var t: float = travelled / total if total > 0.0 else 0.0
		var y := CausewayNetwork.deck_height(t, rise)
		var dir := _tangent(points, i)
		var side := Vector2(-dir.y, dir.x)  # planar left normal
		var lp := points[i] + side * half
		var rp := points[i] - side * half
		verts.append(Vector3(lp.x, y, lp.y))
		verts.append(Vector3(rp.x, y, rp.y))
		norms.append(Vector3.UP)
		norms.append(Vector3.UP)
		uvs.append(Vector2(0.0, travelled / 8.0))
		uvs.append(Vector2(1.0, travelled / 8.0))

	for i in range(1, points.size()):
		var a := (i - 1) * 2
		_quad(idx, a, a + 1, a + 3, a + 2)

	if verts.is_empty():
		return null
	return CityBuilder.arrays_to_mesh(
		{"vertices": verts, "normals": norms, "indices": idx, "uvs": uvs}
	)


## Two thin vertical walls running along the deck edges.
func _add_railings(holder: Node3D, points: PackedVector2Array, width: float, rise: float) -> void:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()

	var total := CausewayNetwork.length_of(points)
	var half := width * 0.5
	var travelled := 0.0

	for side_sign: float in [1.0, -1.0]:
		travelled = 0.0
		var base := verts.size()
		for i in points.size():
			if i > 0:
				travelled += points[i].distance_to(points[i - 1])
			var t: float = travelled / total if total > 0.0 else 0.0
			var y := CausewayNetwork.deck_height(t, rise)
			var dir := _tangent(points, i)
			var side := Vector2(-dir.y, dir.x) * side_sign
			var edge := points[i] + side * half
			verts.append(Vector3(edge.x, y, edge.y))
			verts.append(Vector3(edge.x, y + RAIL_HEIGHT, edge.y))
			var n := Vector3(side.x, 0.0, side.y)
			norms.append(n)
			norms.append(n)
		for i in range(1, points.size()):
			var a := base + (i - 1) * 2
			_quad(idx, a, a + 2, a + 3, a + 1)

	if verts.is_empty():
		return
	var mesh := CityBuilder.arrays_to_mesh({"vertices": verts, "normals": norms, "indices": idx})
	if mesh == null:
		return
	mesh.surface_set_material(0, _rail_mat)
	var mi := MeshInstance3D.new()
	mi.name = "Railings"
	mi.mesh = mesh
	holder.add_child(mi)


## Support pillars from the deck underside down into the seabed, as one MultiMesh.
func _add_pillars(holder: Node3D, points: PackedVector2Array, rise: float) -> void:
	var foots := CausewayNetwork.pillar_points(points, PILLAR_SPACING)
	if foots.is_empty():
		return
	var total := CausewayNetwork.length_of(points)

	var cyl := CylinderMesh.new()
	cyl.top_radius = PILLAR_RADIUS
	cyl.bottom_radius = PILLAR_RADIUS * 1.25
	cyl.height = 1.0
	cyl.radial_segments = 8
	cyl.material = _pillar_mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cyl
	mm.instance_count = foots.size()

	for i in foots.size():
		# pillar_points placed footing i at arc-distance spacing*(i+1); reuse that
		# to read the arched deck height directly (no geometric back-solve).
		var t: float = (PILLAR_SPACING * float(i + 1)) / total if total > 0.0 else 0.0
		var deck_y := CausewayNetwork.deck_height(t, rise) - DECK_THICKNESS
		var h := deck_y - SEABED_Y
		var cy := (deck_y + SEABED_Y) * 0.5
		var basis := Basis.IDENTITY.scaled(Vector3(1.0, h, 1.0))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(foots[i].x, cy, foots[i].y)))

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Pillars"
	mmi.multimesh = mm
	holder.add_child(mmi)


## Smoothed tangent at vertex i of a polyline (uses neighbours where available).
func _tangent(points: PackedVector2Array, i: int) -> Vector2:
	var prev: Vector2 = points[maxi(i - 1, 0)]
	var next: Vector2 = points[mini(i + 1, points.size() - 1)]
	var d := next - prev
	if d.length() < 0.0001:
		return Vector2(1, 0)
	return d.normalized()


func _quad(idx: PackedInt32Array, a: int, b: int, c: int, d: int) -> void:
	idx.append(a)
	idx.append(b)
	idx.append(c)
	idx.append(a)
	idx.append(c)
	idx.append(d)


static func _shader_or_fallback(path: String, fallback: Color) -> Material:
	var shader := load(path) as Shader
	if shader != null:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		return mat
	var std := StandardMaterial3D.new()
	std.albedo_color = fallback
	std.roughness = 0.9
	return std
