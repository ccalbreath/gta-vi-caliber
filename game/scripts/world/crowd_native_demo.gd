class_name CrowdNativeDemo
extends Node3D
## End-to-end demo of the native worldcore crowd stack: flocks `agent_count`
## agents on the XZ plane using SpatialHash (O(local-density) neighbour queries)
## + CrowdSteering (boids), drawn as a single MultiMesh (one draw call). Proves
## the native modules compose into a real, moving crowd.
##
## The per-frame simulation is `step(delta)` so it can be driven headlessly by a
## test probe. Falls back to a static field if the native module is absent, so
## the scene still loads in a GDScript-only build.

@export var agent_count: int = 200
@export var half_extent: float = 60.0  # agents wrap within [-he, he] on X/Z
@export var max_speed: float = 7.0
@export var neighbor_radius: float = 5.0
@export var goal_weight: float = 1.2  # pull toward the wandering goal
@export var avoid_weight: float = 2.5  # push away from obstacle pillars
@export var slow_radius: float = 8.0  # arrival slowdown band around the goal
@export var seed: int = 1234

var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var obstacle_positions: PackedVector2Array = PackedVector2Array()
var obstacle_radii: PackedFloat32Array = PackedFloat32Array()

var _hash: Object = null
var _steer: Object = null
var _mm: MultiMesh = null
var _rng := RandomNumberGenerator.new()
var _goal := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	_rng.seed = seed
	_spawn_agents()
	_setup_obstacles()
	_setup_native()
	_setup_multimesh()
	_sync_multimesh()


## True when the native crowd modules are present and wired.
func native_active() -> bool:
	return _hash != null and _steer != null


## Current wandering goal the crowd is steering toward (for probes/debug).
func current_goal() -> Vector2:
	return _goal


func _spawn_agents() -> void:
	positions.resize(agent_count)
	velocities.resize(agent_count)
	for i in agent_count:
		positions[i] = Vector2(
			_rng.randf_range(-half_extent, half_extent), _rng.randf_range(-half_extent, half_extent)
		)
		velocities[i] = (
			Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * max_speed
		)


func _setup_native() -> void:
	if not (ClassDB.class_exists("SpatialHash") and ClassDB.class_exists("CrowdSteering")):
		push_warning("CrowdNativeDemo: native worldcore modules absent — agents will sit still")
		return
	_hash = ClassDB.instantiate("SpatialHash")
	_hash.set("cell_size", neighbor_radius)
	_steer = ClassDB.instantiate("CrowdSteering")
	_steer.set("neighbor_radius", neighbor_radius)
	_steer.set("max_force", 10.0)
	_steer.set("max_speed", max_speed)
	_steer.set("separation_weight", 1.6)
	_steer.set("alignment_weight", 1.0)
	_steer.set("cohesion_weight", 0.9)


## A ring of static obstacle pillars the crowd must steer around, rendered as
## cylinders. Positions/radii feed CrowdSteering.avoid each frame.
func _setup_obstacles() -> void:
	var ring := half_extent * 0.5
	var count := 4
	for k in count:
		var ang := TAU * float(k) / float(count)
		var pos := Vector2(cos(ang), sin(ang)) * ring
		var radius := 4.0
		obstacle_positions.append(pos)
		obstacle_radii.append(radius)
		var cyl := CylinderMesh.new()
		cyl.top_radius = radius
		cyl.bottom_radius = radius
		cyl.height = 6.0
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		mi.position = Vector3(pos.x, 3.0, pos.y)
		add_child(mi)


func _setup_multimesh() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.6, 1.8, 0.6)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = mesh
	_mm.instance_count = agent_count
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Agents"
	mmi.multimesh = _mm
	add_child(mmi)


func _physics_process(delta: float) -> void:
	if native_active():
		step(delta)
		_sync_multimesh()


## One simulation tick. Rebuilds the spatial hash, steers each agent from its
## neighbours, integrates, clamps speed and wraps toroidally inside the field.
## Pure over (positions, velocities) given the native helpers — the probe calls
## this directly.
func step(delta: float) -> void:
	if not native_active():
		return

	# The goal slowly orbits the field; the crowd flows toward it (arrive) while
	# flocking (steer) and parting around the pillars (avoid).
	_t += delta
	_goal = Vector2(cos(_t * 0.2), sin(_t * 0.2)) * (half_extent * 0.55)

	_hash.call("clear")
	for i in agent_count:
		_hash.call("insert", i, positions[i])

	# Double-buffer: every agent steers from THIS frame's positions/velocities and
	# writes into new_*, so per-agent update order can't bias the flock with
	# mixed-frame neighbour state (Codex review).
	var new_pos := PackedVector2Array()
	var new_vel := PackedVector2Array()
	new_pos.resize(agent_count)
	new_vel.resize(agent_count)

	for i in agent_count:
		var ids: PackedInt32Array = _hash.call("query_radius", positions[i], neighbor_radius)
		var npos := PackedVector2Array()
		var nvel := PackedVector2Array()
		for id in ids:
			if id == i:
				continue
			npos.append(positions[id])
			nvel.append(velocities[id])

		var flock: Vector2 = _steer.call("steer", positions[i], velocities[i], npos, nvel)
		var to_goal: Vector2 = _steer.call(
			"arrive", positions[i], velocities[i], _goal, slow_radius
		)
		var dodge: Vector2 = _steer.call(
			"avoid", positions[i], obstacle_positions, obstacle_radii, 1.5
		)
		var force: Vector2 = flock + to_goal * goal_weight + dodge * avoid_weight

		var v: Vector2 = velocities[i] + force * delta
		if v.length() > max_speed:
			v = v.normalized() * max_speed
		new_vel[i] = v
		new_pos[i] = _wrap(positions[i] + v * delta)

	positions = new_pos
	velocities = new_vel


## Toroidal wrap into [-half_extent, half_extent] on both axes. fposmod handles
## any displacement magnitude (not just one span) so a large delta can't leave an
## agent out of bounds (Codex review).
func _wrap(p: Vector2) -> Vector2:
	var span := half_extent * 2.0
	return Vector2(
		fposmod(p.x + half_extent, span) - half_extent,
		fposmod(p.y + half_extent, span) - half_extent
	)


func _sync_multimesh() -> void:
	if _mm == null:
		return
	for i in agent_count:
		var p := positions[i]
		var facing := velocities[i]
		var basis := Basis.IDENTITY
		if facing.length() > 0.01:
			basis = Basis.looking_at(Vector3(facing.x, 0.0, facing.y), Vector3.UP)
		_mm.set_instance_transform(i, Transform3D(basis, Vector3(p.x, 0.9, p.y)))
