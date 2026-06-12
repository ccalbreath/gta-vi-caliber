extends RefCounted
## Unit tests for WeaponInventory (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).


func test_starts_with_only_fists_equipped() -> bool:
	var inv := WeaponInventory.new()
	return (
		inv.weapon_count() == 1
		and inv.has_weapon(WeaponInventory.UNARMED_ID)
		and inv.current_id() == WeaponInventory.UNARMED_ID
		and not inv.can_fire()
	)


func test_add_weapon_owns_equips_and_currents() -> bool:
	var inv := WeaponInventory.new()
	inv.add_weapon("pistol", 12, 36)
	return (
		inv.has_weapon("pistol")
		and inv.weapon_count() == 2
		and inv.equip("pistol")
		and inv.current_id() == "pistol"
	)


func test_new_weapon_starts_with_full_mag() -> bool:
	var inv := WeaponInventory.new()
	inv.add_weapon("pistol", 12, 36)
	inv.equip("pistol")
	return inv.ammo_in_mag() == 12 and inv.reserve_ammo() == 36


func test_add_duplicate_tops_up_reserve_not_second_slot() -> bool:
	var inv := WeaponInventory.new()
	inv.add_weapon("pistol", 12, 36)
	inv.add_weapon("pistol", 99, 14)
	inv.equip("pistol")
	# Still one pistol slot; reserve summed; original mag_size kept.
	return inv.weapon_count() == 2 and inv.reserve_ammo() == 50 and inv.ammo_in_mag() == 12


func test_add_ammo_increases_reserve() -> bool:
	var inv := WeaponInventory.new()
	inv.add_weapon("rifle", 30, 30)
	inv.equip("rifle")
	inv.add_ammo("rifle", 60)
	return inv.reserve_ammo() == 90


func test_add_ammo_unowned_is_noop() -> bool:
	var inv := WeaponInventory.new()
	inv.add_ammo("ghost", 10)
	return not inv.has_weapon("ghost") and inv.weapon_count() == 1


func test_equip_unowned_fails_and_keeps_current() -> bool:
	var inv := WeaponInventory.new()
	inv.add_weapon("pistol", 12, 12)
	inv.equip("pistol")
	var ok := inv.equip("rocket")
	return not ok and inv.current_id() == "pistol"


func test_owned_ids_in_wheel_order() -> bool:
	var inv := WeaponInventory.new()
	inv.add_weapon("pistol", 12, 0)
	inv.add_weapon("rifle", 30, 0)
	var ids := inv.owned_ids()
	return (
		ids.size() == 3
		and ids[0] == WeaponInventory.UNARMED_ID
		and ids[1] == "pistol"
		and ids[2] == "rifle"
	)


func test_owned_ids_is_a_copy() -> bool:
	var inv := WeaponInventory.new()
	inv.add_weapon("pistol", 12, 0)
	var ids := inv.owned_ids()
	ids.clear()
	return inv.weapon_count() == 2


func test_next_weapon_cycles_and_wraps() -> bool:
	var inv := WeaponInventory.new()
	inv.add_weapon("pistol", 12, 0)
	inv.add_weapon("rifle", 30, 0)
	# fists -> pistol -> rifle -> fists
	var a := inv.next_weapon()
	var b := inv.next_weapon()
	var c := inv.next_weapon()
	return a == "pistol" and b == "rifle" and c == WeaponInventory.UNARMED_ID


func test_previous_weapon_cycles_and_wraps() -> bool:
	var inv := WeaponInventory.new()
	inv.add_weapon("pistol", 12, 0)
	inv.add_weapon("rifle", 30, 0)
	# from fists, previous wraps to rifle -> pistol -> fists
	var a := inv.previous_weapon()
	var b := inv.previous_weapon()
	var c := inv.previous_weapon()
	return a == "rifle" and b == "pistol" and c == WeaponInventory.UNARMED_ID


func test_switching_preserves_per_weapon_state() -> bool:
	var inv := WeaponInventory.new()
	inv.add_weapon("pistol", 12, 12)
	inv.add_weapon("rifle", 30, 30)
	inv.equip("pistol")
	inv.fire()
	inv.fire()  # pistol mag now 10
	inv.equip("rifle")
	inv.fire()  # rifle mag now 29
	var rifle_mag := inv.ammo_in_mag()
	inv.equip("pistol")
	return rifle_mag == 29 and inv.ammo_in_mag() == 10


func test_fire_decrements_mag_and_returns_true() -> bool:
	var inv := WeaponInventory.new()
	inv.add_weapon("pistol", 12, 0)
	inv.equip("pistol")
	var shot := inv.fire()
	return shot and inv.ammo_in_mag() == 11


func test_fire_empty_mag_returns_false_no_consume() -> bool:
	var inv := WeaponInventory.new()
	inv.add_weapon("pistol", 1, 5)
	inv.equip("pistol")
	inv.fire()  # mag 1 -> 0
	var shot := inv.fire()
	return not shot and inv.ammo_in_mag() == 0 and inv.reserve_ammo() == 5


func test_fists_cannot_fire() -> bool:
	var inv := WeaponInventory.new()
	return not inv.can_fire() and not inv.fire()


func test_can_fire_reflects_mag() -> bool:
	var inv := WeaponInventory.new()
	inv.add_weapon("pistol", 1, 0)
	inv.equip("pistol")
	var before := inv.can_fire()
	inv.fire()
	return before and not inv.can_fire()


func test_reload_fills_mag_from_reserve() -> bool:
	var inv := WeaponInventory.new()
	inv.add_weapon("pistol", 12, 30)
	inv.equip("pistol")
	for i in range(5):
		inv.fire()  # mag 12 -> 7
	var loaded := inv.reload()
	return loaded == 5 and inv.ammo_in_mag() == 12 and inv.reserve_ammo() == 25


func test_reload_partial_when_reserve_low() -> bool:
	var inv := WeaponInventory.new()
	inv.add_weapon("pistol", 12, 0)
	inv.equip("pistol")
	inv.add_ammo("pistol", 3)
	for i in range(10):
		inv.fire()  # mag 12 -> 2, needs 10
	var loaded := inv.reload()
	return loaded == 3 and inv.ammo_in_mag() == 5 and inv.reserve_ammo() == 0


func test_reload_empty_reserve_loads_zero() -> bool:
	var inv := WeaponInventory.new()
	inv.add_weapon("pistol", 12, 0)
	inv.equip("pistol")
	inv.fire()  # mag 11, reserve 0
	var loaded := inv.reload()
	return loaded == 0 and inv.ammo_in_mag() == 11


func test_reload_full_mag_is_noop() -> bool:
	var inv := WeaponInventory.new()
	inv.add_weapon("pistol", 12, 30)
	inv.equip("pistol")
	var loaded := inv.reload()
	return loaded == 0 and inv.ammo_in_mag() == 12 and inv.reserve_ammo() == 30


func test_reserve_ammo_zero_for_fists() -> bool:
	var inv := WeaponInventory.new()
	return inv.reserve_ammo() == 0 and inv.reload() == 0
