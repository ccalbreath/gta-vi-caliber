extends RefCounted
## Unit tests for VehicleSupplier (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).
##
## Covers roster validation, the request->in-transit->delivered timer flow, the
## destroyed->respawn cooldown, the wallet result, available/pending counts, and the
## save round-trip.


func test_default_vehicles_loaded() -> bool:
	var vs := VehicleSupplier.new()
	return vs.vehicle_count() == 3 and vs.has_vehicle("daily_sedan")


func test_malformed_dropped() -> bool:
	var vs := VehicleSupplier.new(
		[{"id": "ok"}, {"id": ""}, {"name": "x"}, {"id": "ok", "name": "dup"}]
	)
	return vs.vehicle_count() == 1 and vs.has_vehicle("ok")


func test_starts_available() -> bool:
	var vs := VehicleSupplier.new()
	return (
		vs.is_available("daily_sedan")
		and vs.eta_of("daily_sedan") == 0.0
		and vs.available_count() == 3
		and vs.pending_count() == 0
	)


func test_unknown_vehicle_inert() -> bool:
	var vs := VehicleSupplier.new()
	return (
		not vs.is_available("nope") and not vs.is_in_transit("nope") and vs.eta_of("nope") == -1.0
	)


func test_request_succeeds_and_charges() -> bool:
	var vs := VehicleSupplier.new()
	var r := vs.request("daily_sedan", 1000)  # cost 150, delivery 45
	var eta: float = r["eta_seconds"]
	return (
		r["success"]
		and r["cost"] == 150
		and r["new_balance"] == 850
		and vs.is_in_transit("daily_sedan")
		and is_equal_approx(eta, 45.0)
	)


func test_request_unavailable_fails() -> bool:
	var vs := VehicleSupplier.new()
	vs.request("daily_sedan", 1000)  # now in transit
	var r := vs.request("daily_sedan", 1000)
	return r["success"] == false and "not available" in r["reason"]


func test_request_insufficient_funds_fails() -> bool:
	var vs := VehicleSupplier.new()
	var r := vs.request("sports_coupe", 100)  # cost 350
	return (
		r["success"] == false
		and r["new_balance"] == 100
		and "insufficient" in r["reason"]
		and vs.is_available("sports_coupe")
	)


func test_request_unknown_fails() -> bool:
	var vs := VehicleSupplier.new()
	var r := vs.request("nope", 1000)
	return r["success"] == false and r["new_balance"] == 1000


func test_tick_delivers_after_eta() -> bool:
	var vs := VehicleSupplier.new()
	vs.request("daily_sedan", 1000)  # eta 45
	var arrivals := vs.tick(50.0)
	var first: Dictionary = arrivals[0]
	return (
		arrivals.size() == 1
		and first["vehicle_id"] == "daily_sedan"
		and first["event"] == "delivered"
		and vs.is_available("daily_sedan")
	)


func test_tick_before_eta_not_delivered() -> bool:
	var vs := VehicleSupplier.new()
	vs.request("daily_sedan", 1000)  # eta 45
	var arrivals := vs.tick(20.0)
	return (
		arrivals.size() == 0
		and vs.is_in_transit("daily_sedan")
		and is_equal_approx(vs.eta_of("daily_sedan"), 25.0)
	)


func test_report_destroyed_sets_state() -> bool:
	var vs := VehicleSupplier.new()
	var ok := vs.report_destroyed("daily_sedan")
	return (
		ok
		and vs.is_destroyed("daily_sedan")
		and vs.eta_of("daily_sedan") > 0.0
		and not vs.report_destroyed("nope")
	)


func test_tick_respawns_after_cooldown() -> bool:
	var vs := VehicleSupplier.new()
	vs.report_destroyed("daily_sedan")  # respawn 300
	var arrivals := vs.tick(301.0)
	var first: Dictionary = arrivals[0]
	return first["event"] == "respawned" and vs.is_available("daily_sedan")


func test_tick_nonpositive_noop() -> bool:
	var vs := VehicleSupplier.new()
	vs.request("daily_sedan", 1000)
	var a := vs.tick(0.0)
	var b := vs.tick(-5.0)
	return a.size() == 0 and b.size() == 0 and is_equal_approx(vs.eta_of("daily_sedan"), 45.0)


func test_report_destroyed_blocked_in_transit() -> bool:
	# Destroying an en-route vehicle must fail (it isn't in the world; would dodge the fee).
	var vs := VehicleSupplier.new()
	vs.request("daily_sedan", 1000)  # now in transit
	var ok := vs.report_destroyed("daily_sedan")
	return ok == false and vs.is_in_transit("daily_sedan") and not vs.is_destroyed("daily_sedan")


func test_tick_at_exact_eta_delivers() -> bool:
	# Boundary: a delivery whose timer hits exactly 0 this tick still arrives.
	var vs := VehicleSupplier.new()
	vs.request("daily_sedan", 1000)  # eta 45
	var arrivals := vs.tick(45.0)
	return arrivals.size() == 1 and vs.is_available("daily_sedan")


func test_destroyed_cannot_be_requested() -> bool:
	var vs := VehicleSupplier.new()
	vs.report_destroyed("daily_sedan")
	var r := vs.request("daily_sedan", 1000)
	return r["success"] == false and "not available" in r["reason"]


func test_available_and_pending_counts() -> bool:
	var vs := VehicleSupplier.new()
	vs.request("daily_sedan", 1000)
	vs.report_destroyed("sports_coupe")
	return vs.available_count() == 1 and vs.pending_count() == 2


func test_make_available_resets() -> bool:
	var vs := VehicleSupplier.new()
	vs.request("daily_sedan", 1000)
	vs.make_available("daily_sedan")
	return vs.is_available("daily_sedan") and vs.eta_of("daily_sedan") == 0.0


func test_serialize_restore_roundtrip() -> bool:
	var vs := VehicleSupplier.new()
	vs.request("daily_sedan", 1000)
	vs.tick(20.0)  # eta now 25
	vs.report_destroyed("sports_coupe")
	var snap := vs.serialize()
	var fresh := VehicleSupplier.new()
	fresh.restore(snap)
	return (
		fresh.is_in_transit("daily_sedan")
		and is_equal_approx(fresh.eta_of("daily_sedan"), vs.eta_of("daily_sedan"))
		and fresh.is_destroyed("sports_coupe")
	)


func test_restore_drops_unknown_and_clamps() -> bool:
	var vs := VehicleSupplier.new()
	# ghost unknown -> dropped; daily_sedan state 99 (out of range) -> AVAILABLE, timer -3 -> 0.
	(
		vs
		. restore(
			{
				"vehicles":
				{"ghost": {"state": 1, "timer": 5.0}, "daily_sedan": {"state": 99, "timer": -3.0}}
				# ghost unknown -> dropped; daily_sedan state 99 (out of range) -> AVAILABLE, timer -3 -> 0.
			}
		)
	)
	return (
		not vs.has_vehicle("ghost")
		and vs.is_available("daily_sedan")
		and vs.eta_of("daily_sedan") == 0.0
	)


func test_restore_malformed_noop() -> bool:
	var vs := VehicleSupplier.new()
	vs.request("daily_sedan", 1000)
	var before := vs.eta_of("daily_sedan")
	vs.restore({"vehicles": 42})  # non-dict
	vs.restore({})  # missing key
	return is_equal_approx(vs.eta_of("daily_sedan"), before) and vs.is_in_transit("daily_sedan")


func test_multiple_vehicles_independent_timers() -> bool:
	var vs := VehicleSupplier.new()
	vs.request("daily_sedan", 10000)  # eta 45
	vs.request("sports_coupe", 10000)  # eta 60
	var arrivals := vs.tick(50.0)  # sedan arrives, coupe still coming
	var first: Dictionary = arrivals[0]
	return (
		arrivals.size() == 1
		and first["vehicle_id"] == "daily_sedan"
		and vs.is_available("daily_sedan")
		and vs.is_in_transit("sports_coupe")
	)
