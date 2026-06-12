class_name CrowdRoutedDemo
extends Node3D
## The realistic production crowd, combining three native modules: FlowField
## gives each agent a global routing direction around walls toward the goal,
## while SpatialHash + CrowdSteering add local separation so agents flow without
## piling up. step(delta) drives it for a headless probe; falls back to static
## if the native modules are absent.

@export var grid_w: int = 24
@export var grid_h: int = 24
@export var cell_size: float = 2.5
@export var agent_count: int = 150
@export var max_speed: float = 8.0
@export var neighbor_radius: float = 2.2
@export var route_weight: float = 1.0
@export var separation_weight: float = 1.8
@export var seed: int = 11

var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var costs: PackedFloat32Array = PackedFloat32Array()

var _flow: Object = null
var _hash: Object = null
var _steer: Object = null
var _goal_world := Vector2.ZERO
var _origin := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _mm: MultiMesh = null


func _ready() -> void:
	_rng.seed = seed
	_origin = Vector2(-grid_w * cell_size * 0.5, -grid_h * cell_size * 0.5)
	_build_grid()
	_setup_native()
	_spawn_agents()
	_setup_multimesh()
	_sync_multimesh()


func native_active() -> bool:
	return _flow != null and _hash != null and _steer != null


func goal() -> Vector2:
	return _goal_world


func is_wall_at(p: Vector2) -> bool:
	var cx := int(floor((p.x - _origin.x) / cell_size))
	var cz := int(floor((p.y - _origin.y) / cell_size))
	if cx < 0 or cx >= grid_w or cz < 0 or cz >= grid_h:
		return true
	return costs[cz * grid_w + cx] < 0.0


func _build_grid() -> void:
	costs.resize(grid_w * grid_h)
	costs.fill(1.0)
	_wall_rect(6, 3, 2, 13)
	_wall_rect(15, 8, 2, 13)
	_goal_world = _cell_center(grid_w - 3, grid_h - 3)


func _wall_rect(x: int, y: int, w: int, h: int) -> void:
	for cz in range(y, mini(y + h, grid_h)):
		for cx in range(x, mini(x + w, grid_w)):
			costs[cz * grid_w + cx] = -1.0


func _cell_center(cx: int, cz: int) -> Vector2:
	return _origin + Vector2((cx + 0.5) * cell_size, (cz + 0.5) * cell_size)


func _setup_native() -> void:
	if not (
		ClassDB.class_exists("FlowField")
		and ClassDB.class_exists("SpatialHash")
		and ClassDB.class_exists("CrowdSteering")
	):
		push_warning("CrowdRoutedDemo: native modules absent — agents will sit still")
		return
	_flow = ClassDB.instantiate("FlowField")
	_flow.set("cell_size", cell_size)
	_flow.set("origin", _origin)
	_flow.call("build", grid_w, grid_h, costs, _goal_world)
	if not _flow.call("is_built"):
		_flow = null
		return
	_hash = ClassDB.instantiate("SpatialHash")
	_hash.set("cell_size", neighbor_radius)
	_steer = ClassDB.instantiate("CrowdSteering")
	_steer.set("neighbor_radius", neighbor_radius)
	_steer.set("max_force", 12.0)
	_steer.set("separation_weight", 1.5)
	_steer.set("alignment_weight", 0.0)  # the flow field owns direction
	_steer.set("cohesion_weight", 0.0)  # don't clump — just avoid overlap


func _spawn_agents() -> void:
	positions.resize(agent_count)
	velocities.resize(agent_count)
	for i in agent_count:
		var p := Vector2.ZERO
		for _try in 60:
			p = (
				_origin
				+ Vector2(
					_rng.randf_range(0.0, grid_w * cell_size),
					_rng.randf_range(0.0, grid_h * cell_size)
				)
			)
			if not is_wall_at(p):
				break
		positions[i] = p
		velocities[i] = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if native_active():
		step(delta)
		_sync_multimesh()


## One tick: global route (FlowField) + local separation (SpatialHash +
## CrowdSteering), integrated, with a wall-reject so separation can't shove an
## agent into a wall.
func step(delta: float) -> void:
	if not native_active():
		return

	_hash.call("clear")
	for i in agent_count:
		_hash.call("insert", i, positions[i])

	var new_pos := PackedVector2Array()
	var new_vel := PackedVector2Array()
	new_pos.resize(agent_count)
	new_vel.resize(agent_count)

	for i in agent_count:
		var route: Vector2 = _flow.call("direction_at", positions[i])
		var ids: PackedInt32Array = _hash.call("query_radius", positions[i], neighbor_radius)
		var npos := PackedVector2Array()
		var nvel := PackedVector2Array()
		for id in ids:
			if id == i:
				continue
			npos.append(positions[id])
			nvel.append(velocities[id])
		var sep: Vector2 = _steer.call("steer", positions[i], velocities[i], npos, nvel)

		var force := route * max_speed * route_weight + sep * separation_weight
		var v: Vector2 = velocities[i] + force * delta
		if v.length() > max_speed:
			v = v.normalized() * max_speed
		var move := v * delta
		if move.length() > cell_size:
			move = move.normalized() * cell_size

		var candidate := positions[i] + move
		if is_wall_at(candidate):
			candidate = positions[i]  # separation pushed into a wall — hold position
			v = Vector2.ZERO
		new_pos[i] = candidate
		new_vel[i] = v

	positions = new_pos
	velocities = new_vel


func _setup_multimesh() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.7, 1.7, 0.7)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = mesh
	_mm.instance_count = agent_count
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Agents"
	mmi.multimesh = _mm
	add_child(mmi)


func _sync_multimesh() -> void:
	if _mm == null:
		return
	for i in agent_count:
		var p := positions[i]
		_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(p.x, 0.85, p.y)))
