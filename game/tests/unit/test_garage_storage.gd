extends RefCounted
## Unit tests for GarageStorage (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).


func test_store_adds_and_occupies_space() -> bool:
	var g := GarageStorage.new(4)
	var ok := g.store("home", "car1")
	return (
		ok
		and g.is_stored("car1")
		and g.garage_of("car1") == "home"
		and g.count_in("home") == 1
		and g.free_space("home") == 3
	)


func test_full_garage_rejects() -> bool:
	var g := GarageStorage.new(2)
	g.store("home", "car1")
	g.store("home", "car2")
	var ok := g.store("home", "car3")
	return not ok and g.count_in("home") == 2 and not g.is_stored("car3")


func test_double_store_rejects() -> bool:
	var g := GarageStorage.new(4)
	g.store("home", "car1")
	var again := g.store("home", "car1")
	var elsewhere := g.store("garage2", "car1")
	return not again and not elsewhere and g.total_stored() == 1


func test_retrieve_removes() -> bool:
	var g := GarageStorage.new(4)
	g.store("home", "car1")
	var ok := g.retrieve("home", "car1")
	return ok and not g.is_stored("car1") and g.count_in("home") == 0


func test_retrieve_wrong_garage_fails() -> bool:
	var g := GarageStorage.new(4)
	g.store("home", "car1")
	var ok := g.retrieve("garage2", "car1")
	return not ok and g.is_stored("car1") and g.garage_of("car1") == "home"


func test_retrieve_missing_vehicle_fails() -> bool:
	var g := GarageStorage.new(4)
	g.store("home", "car1")
	var ok := g.retrieve("home", "ghost")
	return not ok and g.count_in("home") == 1


func test_garage_of_out_vehicle_is_empty() -> bool:
	var g := GarageStorage.new(4)
	return g.garage_of("car1") == "" and not g.is_stored("car1")


func test_contents_lists_stored() -> bool:
	var g := GarageStorage.new(4)
	g.store("home", "car1")
	g.store("home", "car2")
	var c: Array = g.contents("home")
	return c.size() == 2 and c.has("car1") and c.has("car2")


func test_contents_is_a_copy() -> bool:
	var g := GarageStorage.new(4)
	g.store("home", "car1")
	var c: Array = g.contents("home")
	c.append("hacked")
	return g.count_in("home") == 1


func test_free_space_unknown_garage_is_capacity() -> bool:
	var g := GarageStorage.new(3)
	return g.free_space("nowhere") == 3 and g.count_in("nowhere") == 0


func test_multiple_garages_independent() -> bool:
	var g := GarageStorage.new(2)
	g.store("home", "car1")
	g.store("docks", "boat1")
	return (
		g.garage_of("car1") == "home" and g.garage_of("boat1") == "docks" and g.total_stored() == 2
	)


func test_impound_flags() -> bool:
	var g := GarageStorage.new(4)
	g.impound("car1")
	return g.is_impounded("car1") and not g.is_stored("car1")


func test_impound_pulls_from_garage() -> bool:
	var g := GarageStorage.new(4)
	g.store("home", "car1")
	g.impound("car1")
	return g.is_impounded("car1") and not g.is_stored("car1") and g.count_in("home") == 0


func test_cannot_store_impounded() -> bool:
	var g := GarageStorage.new(4)
	g.impound("car1")
	var ok := g.store("home", "car1")
	return not ok and not g.is_stored("car1") and g.is_impounded("car1")


func test_recover_pays_fee_and_frees() -> bool:
	var g := GarageStorage.new(4)
	g.impound("car1")
	var result: Dictionary = g.recover_from_impound("car1", 1000, 250)
	var success: bool = result["success"]
	var new_balance: int = result["new_balance"]
	return (
		success
		and result["cost"] == 250
		and new_balance == 750
		and not g.is_impounded("car1")
		and not g.is_stored("car1")
	)


func test_recover_fails_when_broke() -> bool:
	var g := GarageStorage.new(4)
	g.impound("car1")
	var result: Dictionary = g.recover_from_impound("car1", 100, 250)
	var success: bool = result["success"]
	var new_balance: int = result["new_balance"]
	return not success and new_balance == 100 and g.is_impounded("car1")


func test_recover_not_impounded_fails() -> bool:
	var g := GarageStorage.new(4)
	var result: Dictionary = g.recover_from_impound("car1", 1000, 250)
	var success: bool = result["success"]
	return not success and result["new_balance"] == 1000


func test_recovered_can_be_stored_again() -> bool:
	var g := GarageStorage.new(4)
	g.impound("car1")
	g.recover_from_impound("car1", 1000, 250)
	var ok := g.store("home", "car1")
	return ok and g.is_stored("car1")


func test_total_stored() -> bool:
	var g := GarageStorage.new(4)
	g.store("home", "car1")
	g.store("home", "car2")
	g.store("docks", "boat1")
	return g.total_stored() == 3


func test_serialize_restore_round_trip() -> bool:
	var g := GarageStorage.new(3)
	g.store("home", "car1")
	g.store("docks", "boat1")
	g.impound("wreck1")
	var snapshot: Dictionary = g.serialize()
	var g2 := GarageStorage.new(4)
	g2.restore(snapshot)
	return (
		g2.capacity() == 3
		and g2.garage_of("car1") == "home"
		and g2.garage_of("boat1") == "docks"
		and g2.is_impounded("wreck1")
		and g2.total_stored() == 2
	)


func test_reset_clears_everything() -> bool:
	var g := GarageStorage.new(4)
	g.store("home", "car1")
	g.impound("wreck1")
	g.reset()
	return g.total_stored() == 0 and not g.is_impounded("wreck1") and not g.is_stored("car1")
