class_name TrafficCar
extends Node3D
## A lightweight kinematic ambient-traffic car: follows a list of world waypoints
## (typically straight from NavGrid.find_path) by turn-rate-limited steering, so
## it arcs through corners and faces where it's going. Visual-only — it carries
## a simple procedural body so a street of these reads as moving traffic without
## the cost of a full VehicleBody3D per car. The player's own car stays physical.
##
## Steering maths is the pure, tested TrafficMotion; this node only owns the
## state and the mesh. Hand it a route with set_route(); poll is_done() to know
## when to give it a new one (the TrafficDirector does this).

@export var speed: float = 9.0
@export var max_turn_rate: float = 2.2  # rad/s
@export var arrive_tolerance: float = 2.0
@export var body_color: Color = Color(0.7, 0.2, 0.2)
## Loop the route forever (handy for a standalone demo); the director leaves this
## off and repaths on completion instead.
@export var loop: bool = false

## Per-tick speed cap set by the director's car-following (TrafficFlow); negative
## means uncapped. Lets a car slow or stop for the vehicle ahead without changing
## its own cruising `speed`.
var speed_limit: float = -1.0

var _waypoints: PackedVector3Array = PackedVector3Array()
var _index: int = 0
var _heading: Vector3 = Vector3(0, 0, 1)


func _ready() -> void:
	_build_body()


## Start following a new route. The car snaps its heading toward the first leg so
## it doesn't spin on spawn. Positions are world-space (y is followed as given).
func set_route(waypoints: PackedVector3Array) -> void:
	_waypoints = waypoints
	_index = 0
	if waypoints.size() >= 2:
		_heading = TrafficMotion.planar_dir(waypoints[0], waypoints[1])
		if _heading == Vector3.ZERO:
			_heading = Vector3(0, 0, 1)


func is_done() -> bool:
	return _index >= _waypoints.size()


func heading() -> Vector3:
	return _heading


func _physics_process(delta: float) -> void:
	_index = TrafficMotion.advance_waypoint(global_position, _waypoints, _index, arrive_tolerance)
	if is_done():
		if loop and _waypoints.size() > 0:
			_index = 0
		else:
			return
	var target := _waypoints[_index]
	var drive_speed := speed if speed_limit < 0.0 else minf(speed, speed_limit)
	var r := TrafficMotion.step(
		global_position, _heading, target, drive_speed, max_turn_rate, delta
	)
	global_position = r["position"]
	_heading = r["heading"]
	# Face travel direction (heading is planar unit, so look along it on the flat).
	var look := global_position + _heading
	look.y = global_position.y
	if _heading.length() > 0.0001:
		look_at(look, Vector3.UP)


## A boxy three-part car (body, cabin, four wheels) — enough silhouette to read
## as a vehicle at street distance. Built once; no per-frame allocation.
func _build_body() -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = body_color
	paint.metallic = 0.4
	paint.roughness = 0.4

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.1, 0.12, 0.16)
	glass.metallic = 0.6
	glass.roughness = 0.15

	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.05, 0.05, 0.06)
	rubber.roughness = 0.9

	_box(Vector3(1.8, 0.6, 4.2), Vector3(0.0, 0.55, 0.0), paint)  # body
	_box(Vector3(1.6, 0.55, 2.0), Vector3(0.0, 1.05, -0.2), glass)  # cabin
	for x: float in [-0.85, 0.85]:
		for z: float in [-1.3, 1.3]:
			_wheel(Vector3(x, 0.35, z), rubber)


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func _wheel(pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.35
	cyl.height = 0.25
	mi.mesh = cyl
	mi.material_override = mat
	mi.rotation = Vector3(0.0, 0.0, PI * 0.5)  # lay the cylinder on its side
	mi.position = pos
	add_child(mi)
