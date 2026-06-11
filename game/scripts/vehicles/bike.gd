class_name Bike
extends Car
## Two-wheeled prototype: inherits Car's driving and damage logic, adds PD
## upright stabilization that leans into the current steering angle.

## Wheelie: forward acceleration (m/s²) past which the front lifts, the torque
## per excess m/s², and its cap — keeps a hard launch popping a wheelie.
@export var wheelie_threshold: float = 6.0
@export var wheelie_scale: float = 8.0
@export var wheelie_max_torque: float = 90.0
## Spring strength toward the lean target (rad-ish error -> torque).
@export var upright_stiffness: float = 90.0
## Roll-rate damping so the bike settles instead of wobbling.
@export var upright_damping: float = 12.0
## How far the bike leans into a full-lock turn (fraction of tilt).
@export var lean_per_steer: float = 0.5


func _physics_process(delta: float) -> void:
	super(delta)
	_stabilize()
	_apply_wheelie()


## Pop a wheelie on hard acceleration: a pitch torque about the rear axle lifts
## the front while grounded. Pure magnitude from VehicleMotion.wheelie_torque.
func _apply_wheelie() -> void:
	if _is_airborne():
		return
	var torque := VehicleMotion.wheelie_torque(
		_long_accel, wheelie_threshold, wheelie_scale, wheelie_max_torque
	)
	if torque > 0.0:
		# Pitch up about the bike's right axis (nose rises).
		apply_torque(global_transform.basis.x * torque * mass)


func _stabilize() -> void:
	# Off the ground, Car's air-righting owns attitude — running the steering-
	# based ground lean here too would fight it mid-jump.
	if _is_airborne():
		return
	# Tilt is the right axis' vertical component: 0 upright, +1 flat on the
	# left side. The lean target follows steering so turns feel committed.
	var back := global_transform.basis.z
	var tilt := global_transform.basis.x.y
	var target := lean_per_steer * steering
	var roll_rate := angular_velocity.dot(back)
	var torque := VehicleMotion.upright_torque(
		tilt - target, roll_rate, upright_stiffness, upright_damping
	)
	apply_torque(back * torque * mass)
