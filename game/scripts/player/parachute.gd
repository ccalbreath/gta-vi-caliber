class_name Parachute
extends RefCounted
## Pure parachute / skydive model — the freefall → canopy → landing arc a player
## rides after leaping from a helicopter or rooftop. Stateful instance, no nodes:
## it owns the jump's State and the descent physics, and hands a CharacterBody3D
## (gravity and collision stay the engine's job) a vertical fall speed plus a
## horizontal drift each frame.
##
## The arc has three beats. In FREEFALL you plummet, accelerating under gravity
## toward `terminal_velocity` with barely any steering. `deploy()` pops the canopy
## (once, and only from freefall): now you bleed speed down toward the gentle
## `canopy_descent_rate` and can steer-glide across the XZ plane. `land()` ends
## the jump; a soft canopy touchdown does no damage, a freefall splat does.
##
## Same testable-core pattern as VehicleHandling / NpcSteering: Vector3 in /
## Vector3 out on the XZ plane (y is up), defensive throughout — zero descent
## rates are guarded, every output clamped, no path produces a NaN. Covered by
## tests/unit/test_parachute.gd.

enum State { FREEFALL, DEPLOYED, LANDED }

## Gravity pulling a freefalling skydiver down (m/s²). Positive = downward, since
## fall speed is tracked as a positive magnitude.
const GRAVITY: float = 9.8

## How fast the canopy bleeds excess speed once deployed (m/s² of deceleration).
const CANOPY_DRAG: float = 12.0

var _state: int = State.FREEFALL
var _terminal_velocity: float = 55.0
var _canopy_descent_rate: float = 6.0


## `terminal_velocity` caps the freefall plummet; `canopy_descent_rate` is the
## gentle speed the open chute settles toward. Both are floored positive so the
## physics never inverts.
func _init(terminal_velocity: float = 55.0, canopy_descent_rate: float = 6.0) -> void:
	_terminal_velocity = maxf(terminal_velocity, 0.0)
	_canopy_descent_rate = maxf(canopy_descent_rate, 0.0)


## Pop the canopy. Only valid from FREEFALL — a second deploy (or deploying after
## landing) is a no-op. Returns true iff the chute actually opened this call.
func deploy() -> bool:
	if _state != State.FREEFALL:
		return false
	_state = State.DEPLOYED
	return true


## True once the canopy is open (and not yet landed).
func is_deployed() -> bool:
	return _state == State.DEPLOYED


## The current jump State (FREEFALL / DEPLOYED / LANDED).
func state() -> int:
	return _state


## Advance the vertical fall speed (positive m/s, downward) one frame. In FREEFALL
## you accelerate under gravity toward `terminal_velocity`; under canopy you
## decelerate toward the slow `canopy_descent_rate`. Result is clamped so freefall
## never exceeds terminal and the canopy never speeds back up past terminal.
func update_fall_speed(current_speed: float, delta: float) -> float:
	var speed := maxf(current_speed, 0.0)
	var dt := maxf(delta, 0.0)
	if _state == State.DEPLOYED:
		if speed > _canopy_descent_rate:
			speed = maxf(speed - CANOPY_DRAG * dt, _canopy_descent_rate)
		else:
			speed = minf(speed + CANOPY_DRAG * dt, _canopy_descent_rate)
		return clampf(speed, 0.0, _terminal_velocity)
	# FREEFALL (and LANDED, harmlessly): accelerate toward terminal.
	speed = minf(speed + GRAVITY * dt, _terminal_velocity)
	return clampf(speed, 0.0, _terminal_velocity)


## Horizontal velocity (XZ) from a steer input. Under canopy you carve across the
## sky at `glide_speed`; in freefall you can only barely shift your fall line, so
## the same input yields a fraction of the drift. Vertical input is dropped and
## the result is clamped to `glide_speed`, so no input can drift faster than the
## canopy allows.
func horizontal_drift(steer_input: Vector3, deployed: bool, glide_speed: float) -> Vector3:
	var flat := Vector3(steer_input.x, 0.0, steer_input.z)
	if flat.length() < 0.0001:
		return Vector3.ZERO
	var glide := maxf(glide_speed, 0.0)
	# Freefall body-flying gives only a sliver of the canopy's authority.
	var authority := glide if deployed else glide * 0.12
	var drift := flat.normalized() * authority
	if drift.length() > glide:
		drift = drift.normalized() * glide
	return drift


## Landing damage factor in [0, 1]: 0 for any touchdown at or below `safe_speed`
## (a soft canopy landing), ramping to a full 1 splat as the impact speed climbs
## to twice `safe_speed` and beyond. Guarded so a zero/negative safe_speed can't
## divide by zero.
func landing_impact(vertical_speed: float, safe_speed: float) -> float:
	var v := maxf(vertical_speed, 0.0)
	var safe := maxf(safe_speed, 0.0)
	if v <= safe:
		return 0.0
	if safe < 0.0001:
		return 1.0
	# Excess speed beyond safe, normalised over another `safe` band → full damage.
	return clampf((v - safe) / safe, 0.0, 1.0)


## Whether a touchdown at `vertical_speed` is walked-off cleanly (no damage).
func is_safe_landing(vertical_speed: float, safe_speed: float) -> bool:
	return maxf(vertical_speed, 0.0) <= maxf(safe_speed, 0.0)


## Seconds until the ground at the current `descent_rate` — info/HUD only. Guarded:
## negative altitude reads as already-landed (0), and a zero/negative descent rate
## (hovering) returns INF rather than dividing by zero.
func time_to_ground(altitude: float, descent_rate: float) -> float:
	var alt := maxf(altitude, 0.0)
	if alt <= 0.0:
		return 0.0
	if descent_rate <= 0.0001:
		return INF
	return alt / descent_rate


## End the jump — feet on the ground.
func land() -> void:
	_state = State.LANDED


## Back to a fresh pre-jump FREEFALL, ready to skydive again.
func reset() -> void:
	_state = State.FREEFALL
