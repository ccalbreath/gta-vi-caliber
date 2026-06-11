extends RefCounted
## Unit tests for PoliceResponse — wanted-star escalation profile.


func test_no_police_at_zero_stars() -> bool:
	return PoliceResponse.units_for(0) == 0 and not PoliceResponse.uses_helicopter(0)


func test_units_escalate_with_stars() -> bool:
	return (
		PoliceResponse.units_for(1) < PoliceResponse.units_for(3)
		and PoliceResponse.units_for(5) == 8
	)


func test_helicopter_joins_at_three_stars() -> bool:
	return not PoliceResponse.uses_helicopter(2) and PoliceResponse.uses_helicopter(3)


func test_aggression_scales_zero_to_one() -> bool:
	return PoliceResponse.aggression(0) == 0.0 and PoliceResponse.aggression(5) == 1.0


func test_spawn_radius_widens_with_heat() -> bool:
	return PoliceResponse.spawn_radius(5) > PoliceResponse.spawn_radius(1)


func test_profile_bundles_fields() -> bool:
	var p := PoliceResponse.profile(4)
	return p.has("units") and p.has("helicopter") and p.has("aggression") and p.has("spawn_radius")


func test_star_count_is_clamped() -> bool:
	return PoliceResponse.units_for(99) == 8 and PoliceResponse.units_for(-3) == 0
