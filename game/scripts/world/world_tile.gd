class_name WorldTile
extends Node3D
## One streamable greybox tile: a ground slab plus a deterministic block of
## placeholder buildings, generated from the tile coordinate so the same
## coordinate always produces the same tile.
##
## This is the placeholder stand-in for authored city tiles. The contract a
## real tile must keep (docs/ARCHITECTURE.md): fully self-contained — no
## cross-scene node references, everything under one root, positioned by the
## streamer via `coord`.

## Buildings are placed on a blocks-per-side grid with street gaps between
## blocks.
const BLOCKS_PER_SIDE: int = 3
const STREET_WIDTH: float = 10.0
const MIN_BUILDING_HEIGHT: float = 4.0
const MAX_BUILDING_HEIGHT: float = 22.0

## Grid coordinate this tile occupies; the streamer sets both of these before
## adding the tile to the tree.
var coord: Vector2i = Vector2i.ZERO
var tile_size: float = 128.0


func _ready() -> void:
	position = TileMath.tile_center(coord, tile_size)
	_build_ground()
	_build_buildings()


func _build_ground() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.34, 0.36, 0.34)
	material.roughness = 1.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(tile_size, 1.0, tile_size)
	mesh.material = material
	_add_box(mesh, Vector3(0.0, -0.5, 0.0))


func _build_buildings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(coord)
	var block_size := (tile_size - STREET_WIDTH * (BLOCKS_PER_SIDE + 1)) / BLOCKS_PER_SIDE
	for row in range(BLOCKS_PER_SIDE):
		for column in range(BLOCKS_PER_SIDE):
			if _is_spawn_block(row, column):
				continue
			_build_building(rng, row, column, block_size)


## Keep the centre block of the origin tile clear so the player never spawns
## inside a building.
func _is_spawn_block(row: int, column: int) -> bool:
	var centre := BLOCKS_PER_SIDE / 2
	return coord == Vector2i.ZERO and row == centre and column == centre


func _build_building(rng: RandomNumberGenerator, row: int, column: int, block_size: float) -> void:
	var height := rng.randf_range(MIN_BUILDING_HEIGHT, MAX_BUILDING_HEIGHT)
	var footprint := block_size * rng.randf_range(0.6, 0.95)
	var shade := rng.randf_range(0.45, 0.65)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(shade, shade, shade * 1.05)
	material.roughness = 0.9
	var mesh := BoxMesh.new()
	mesh.size = Vector3(footprint, height, footprint)
	mesh.material = material
	var block_step := tile_size / BLOCKS_PER_SIDE
	var local := Vector3(
		(column + 0.5) * block_step - tile_size * 0.5,
		height * 0.5,
		(row + 0.5) * block_step - tile_size * 0.5
	)
	_add_box(mesh, local)


func _add_box(mesh: BoxMesh, local_position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = local_position
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
