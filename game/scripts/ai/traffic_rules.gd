class_name TrafficRules
extends RefCounted
## Pure right-of-way helpers for ambient traffic — the "yield to the car on your
## right" rule of an uncontrolled junction, plus already-in-junction priority.
##
## Static, scene-free and deterministic so it unit-tests headless
## (tests/unit/test_traffic_rules.gd). The TrafficDirector will call these when a
## car nears a junction node to decide whether to hold; foundation now, wiring
## once junction nodes exist. Planar (XZ); +Y is up so "right" = heading × up.

const UP: Vector3 = Vector3.UP


## Unit vector pointing to the driver's right for a planar heading. For heading
## +Z this is -X (forward × up), matching a right-hand drive frame.
static func right_of(heading: Vector3) -> Vector3:
	var h := Vector3(heading.x, 0.0, heading.z)
	if h.length() < 0.0001:
		return Vector3.ZERO
	return h.normalized().cross(UP).normalized()


## Is `other` on this driver's right-hand side? to_other is the planar vector from
## us to the other car.
static func is_on_right(heading: Vector3, to_other: Vector3) -> bool:
	var r := right_of(heading)
	if r == Vector3.ZERO:
		return false
	return Vector3(to_other.x, 0.0, to_other.z).dot(r) > 0.0


## Whether to yield to another car converging on a junction. Yield when the other
## car is within `range_m`, not behind us (so we don't yield to someone we've
## already passed), and either already inside the junction or approaching from our
## right. Distance/strength of approach is the caller's; this is the rule.
static func should_yield(
	my_pos: Vector3,
	my_heading: Vector3,
	other_pos: Vector3,
	other_in_junction: bool,
	range_m: float
) -> bool:
	var to_other := Vector3(other_pos.x - my_pos.x, 0.0, other_pos.z - my_pos.z)
	if to_other.length() > range_m:
		return false
	var h := Vector3(my_heading.x, 0.0, my_heading.z)
	if h.length() > 0.0001 and to_other.dot(h.normalized()) < -0.2:
		return false  # other is behind us — already cleared
	if other_in_junction:
		return true
	return is_on_right(my_heading, to_other)
