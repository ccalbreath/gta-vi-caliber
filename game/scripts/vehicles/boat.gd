class_name Boat
extends RigidBody3D
## Greybox boat: four-point buoyancy (corner float points give natural
## pitch/roll righting), propeller thrust and rudder torque while submerged.
## Math is delegated to BoatMotion (pure, unit-tested). Implements the same
## enter()/exit()/has_driver() contract Player expects from vehicles.

const FLOAT_POINTS: Array[Vector3] = [
	Vector3(-0.8, 0.0, -1.4),
	Vector3(0.8, 0.0, -1.4),
	Vector3(-0.8, 0.0, 1.4),
	Vector3(0.8, 0.0, 1.4),
]

## World-space height of the water surface this boat floats on.
@export var water_level: float = 0.5
## Buoyancy spring per float point, in g-per-meter-of-submersion terms.
@export var buoyancy_strength: float = 30.0
@export var max_thrust: float = 9000.0
@export var rudder_torque_max: float = 6000.0

var _driver: Node3D = null

@onready var _camera: Camera3D = $CameraPivot/SpringArm/Camera
@onready var _exit_point: Marker3D = $ExitPoint


func has_driver() -> bool:
	return _driver != null


func enter(driver: Node3D) -> void:
	_driver = driver
	_camera.current = true


## Releases the driver and returns a safe world position to step out at.
func exit() -> Vector3:
	_driver = null
	_camera.current = false
	return _exit_point.global_position


func _physics_process(_delta: float) -> void:
	var submerged := false
	var point_strength := buoyancy_strength * mass / FLOAT_POINTS.size()
	for point in FLOAT_POINTS:
		var world_point := global_transform * point
		var depth := water_level - world_point.y
		if depth > 0.0:
			submerged = true
		var force := BoatMotion.buoyancy_force(depth, point_strength)
		apply_force(Vector3.UP * force, world_point - global_position)

	if _driver == null:
		return
	var throttle := VehicleMotion.driving_axis(
		Input.get_action_strength("move_back"), Input.get_action_strength("move_forward")
	)
	var steer := VehicleMotion.driving_axis(
		Input.get_action_strength("move_left"), Input.get_action_strength("move_right")
	)
	var forward := -global_transform.basis.z
	apply_central_force(forward * BoatMotion.thrust(throttle, max_thrust, submerged))
	apply_torque(
		(
			Vector3.UP
			* BoatMotion.rudder_torque(
				VehicleMotion.godot_steering(steer), rudder_torque_max, submerged
			)
		)
	)
