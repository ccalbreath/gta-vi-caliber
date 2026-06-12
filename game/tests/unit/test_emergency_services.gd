extends RefCounted
## Unit tests for EmergencyServices (see tests/run_tests.gd for the runner
## contract: test_* methods return true to pass). Deterministic, no RNG/scene.

# --- service_for mapping -----------------------------------------------------


func test_service_for_fire_is_fire_truck() -> bool:
	return (
		EmergencyServices.service_for(EmergencyServices.Incident.FIRE)
		== EmergencyServices.Service.FIRE_TRUCK
	)


func test_service_for_injury_and_wreck_are_ambulance() -> bool:
	var ambulance: int = EmergencyServices.Service.AMBULANCE
	return (
		EmergencyServices.service_for(EmergencyServices.Incident.INJURY) == ambulance
		and EmergencyServices.service_for(EmergencyServices.Incident.WRECK) == ambulance
	)


func test_service_for_shooting_is_police_backup() -> bool:
	return (
		EmergencyServices.service_for(EmergencyServices.Incident.SHOOTING)
		== EmergencyServices.Service.POLICE_BACKUP
	)


func test_service_for_unknown_defaults_to_ambulance() -> bool:
	return EmergencyServices.service_for(999) == EmergencyServices.Service.AMBULANCE


# --- eta ---------------------------------------------------------------------


func test_eta_is_distance_over_speed() -> bool:
	# 30 m on the X axis at 10 m/s = 3.0 s; y is ignored (XZ plane).
	var t := EmergencyServices.eta(Vector3(0, 5, 0), Vector3(30, 99, 0), 10.0)
	return is_equal_approx(t, 3.0)


func test_eta_uses_xz_plane() -> bool:
	# 3-4-5 triangle on XZ: hypotenuse 5 at speed 5 = 1.0 s.
	var t := EmergencyServices.eta(Vector3.ZERO, Vector3(3, 0, 4), 5.0)
	return is_equal_approx(t, 1.0)


func test_eta_nonpositive_speed_guarded() -> bool:
	var zero := EmergencyServices.eta(Vector3.ZERO, Vector3(10, 0, 0), 0.0)
	var negative := EmergencyServices.eta(Vector3.ZERO, Vector3(10, 0, 0), -4.0)
	return zero == INF and negative == INF


# --- nearest_responder -------------------------------------------------------


func test_nearest_responder_picks_closest() -> bool:
	var responders: Array = [
		{"pos": Vector3(100, 0, 0), "service": EmergencyServices.Service.FIRE_TRUCK},
		{"pos": Vector3(5, 0, 0), "service": EmergencyServices.Service.AMBULANCE},
		{"pos": Vector3(40, 0, 0), "service": EmergencyServices.Service.AMBULANCE},
	]
	var best := EmergencyServices.nearest_responder(Vector3.ZERO, responders)
	var pos: Vector3 = best["pos"]
	return is_equal_approx(pos.x, 5.0)


func test_nearest_responder_carries_service_through() -> bool:
	var responders: Array = [
		{"pos": Vector3(2, 0, 0), "service": EmergencyServices.Service.FIRE_TRUCK},
	]
	var best := EmergencyServices.nearest_responder(Vector3.ZERO, responders)
	var service: int = best["service"]
	return service == EmergencyServices.Service.FIRE_TRUCK


func test_nearest_responder_empty_is_blank() -> bool:
	return EmergencyServices.nearest_responder(Vector3.ZERO, []).is_empty()


func test_nearest_responder_skips_entries_without_pos() -> bool:
	var responders: Array = [{"service": EmergencyServices.Service.AMBULANCE}]
	return EmergencyServices.nearest_responder(Vector3.ZERO, responders).is_empty()


# --- should_dispatch ---------------------------------------------------------


func test_should_dispatch_medical_when_safe() -> bool:
	return EmergencyServices.should_dispatch(EmergencyServices.Incident.INJURY, true, 0)


func test_should_dispatch_medical_suppressed_when_player_caused_hot() -> bool:
	# Player-caused injury at 4 stars: crews scared off, no dispatch.
	return not EmergencyServices.should_dispatch(EmergencyServices.Incident.INJURY, true, 4)


func test_should_dispatch_medical_at_hot_scene_player_not_caused() -> bool:
	# Same heat but the player didn't cause it: crews still roll.
	return EmergencyServices.should_dispatch(EmergencyServices.Incident.FIRE, false, 4)


func test_should_dispatch_shooting_always_gets_backup() -> bool:
	# Police backup goes in even at max heat, player-caused.
	return EmergencyServices.should_dispatch(EmergencyServices.Incident.SHOOTING, true, 6)


# --- revive_chance -----------------------------------------------------------


func test_revive_chance_falls_with_severity() -> bool:
	var light := EmergencyServices.revive_chance(0.2)
	var heavy := EmergencyServices.revive_chance(0.8)
	return is_equal_approx(light, 0.8) and is_equal_approx(heavy, 0.2) and light > heavy


func test_revive_chance_edges() -> bool:
	# Fatal severity is unrevivable (0.0); clamps below 0 to a full 1.0.
	return (
		is_equal_approx(EmergencyServices.revive_chance(1.0), 0.0)
		and is_equal_approx(EmergencyServices.revive_chance(-0.5), 1.0)
	)


# --- stateful response timer -------------------------------------------------


func test_timer_starts_idle() -> bool:
	var unit := EmergencyServices.new(6.0)
	return not unit.has_arrived() and is_equal_approx(unit.progress(), 0.0)


func test_tick_before_begin_is_noop() -> bool:
	var unit := EmergencyServices.new(6.0)
	unit.tick(10.0)
	return not unit.has_arrived() and is_equal_approx(unit.progress(), 0.0)


func test_timer_arrives_after_delay() -> bool:
	var unit := EmergencyServices.new(4.0)
	unit.begin()
	unit.tick(2.0)
	var midway: bool = not unit.has_arrived()
	unit.tick(2.0)
	return midway and unit.has_arrived()


func test_progress_ramps() -> bool:
	var unit := EmergencyServices.new(4.0)
	unit.begin()
	unit.tick(1.0)
	return is_equal_approx(unit.progress(), 0.25)


func test_treating_only_after_arrival() -> bool:
	var unit := EmergencyServices.new(4.0)
	unit.begin()
	unit.tick(1.0)
	var before: bool = not unit.treating()
	unit.tick(5.0)
	return before and unit.treating()


func test_arrive_once_and_progress_full() -> bool:
	var unit := EmergencyServices.new(4.0)
	unit.begin()
	unit.tick(100.0)
	var arrived: bool = unit.has_arrived()
	unit.tick(100.0)
	return arrived and unit.has_arrived() and is_equal_approx(unit.progress(), 1.0)


func test_cancel_resets_to_idle() -> bool:
	var unit := EmergencyServices.new(4.0)
	unit.begin()
	unit.tick(5.0)
	unit.cancel()
	return not unit.has_arrived() and is_equal_approx(unit.progress(), 0.0)


func test_reset_clears_and_allows_rebegin() -> bool:
	var unit := EmergencyServices.new(4.0)
	unit.begin()
	unit.tick(5.0)
	unit.reset()
	unit.begin()
	unit.tick(2.0)
	return is_equal_approx(unit.progress(), 0.5) and not unit.has_arrived()
