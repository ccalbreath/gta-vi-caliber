extends RefCounted
## Unit tests for LootTable (see tests/run_tests.gd: test_* methods return true
## to pass). All randomness uses a seeded RandomNumberGenerator so rolls are
## deterministic.


func _seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_default_table_non_empty() -> bool:
	var t := LootTable.new()
	return t.entry_count() >= 4 and t.total_weight() > 0.0


func test_default_table_total_weight() -> bool:
	# 5 + 4 + 2 + 1 + 3 = 15.
	var t := LootTable.new()
	return is_equal_approx(t.total_weight(), 15.0)


func test_custom_table_used() -> bool:
	var t := LootTable.new([{"id": "gold", "weight": 2.0, "min": 1, "max": 1}])
	return t.entry_count() == 1 and is_equal_approx(t.total_weight(), 2.0)


func test_roll_returns_valid_entry() -> bool:
	var t := LootTable.new()
	var rng := _seeded(12345)
	var ids := {"cash": true, "pistol_ammo": true, "smg_ammo": true, "body_armor": true, "": true}
	var drop := t.roll(rng)
	return drop.has("id") and drop.has("quantity") and ids.has(drop["id"])


func test_roll_quantity_in_range() -> bool:
	var t := LootTable.new([{"id": "cash", "weight": 1.0, "min": 50, "max": 200}])
	var rng := _seeded(777)
	for _i in range(50):
		var drop := t.roll(rng)
		if drop["quantity"] < 50 or drop["quantity"] > 200:
			return false
	return true


func test_fixed_seed_reproduces_sequence() -> bool:
	var t := LootTable.new()
	var a := t.roll_many(_seeded(2024), 20)
	var b := t.roll_many(_seeded(2024), 20)
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i]["id"] != b[i]["id"] or a[i]["quantity"] != b[i]["quantity"]:
			return false
	return true


func test_make_rng_reproduces() -> bool:
	var t := LootTable.new()
	var a := t.roll(LootTable.make_rng(99))
	var b := t.roll(LootTable.make_rng(99))
	return a["id"] == b["id"] and a["quantity"] == b["quantity"]


func test_different_seed_can_differ() -> bool:
	# Not strictly guaranteed, but with these seeds the first ids differ.
	var t := LootTable.new()
	var a := t.roll_many(_seeded(1), 8)
	var b := t.roll_many(_seeded(2), 8)
	var same := true
	for i in range(a.size()):
		if a[i]["id"] != b[i]["id"] or a[i]["quantity"] != b[i]["quantity"]:
			same = false
	return not same


func test_roll_many_returns_n() -> bool:
	var t := LootTable.new()
	return t.roll_many(_seeded(5), 13).size() == 13


func test_roll_many_zero_or_negative() -> bool:
	var t := LootTable.new()
	return t.roll_many(_seeded(5), 0).is_empty() and t.roll_many(_seeded(5), -4).is_empty()


func test_weighting_heavy_beats_light() -> bool:
	# heavy weight 10 vs light weight 1: over many rolls heavy must dominate.
	var t := (
		LootTable
		. new(
			[
				{"id": "heavy", "weight": 10.0, "min": 1, "max": 1},
				{"id": "light", "weight": 1.0, "min": 1, "max": 1},
			]
		)
	)
	var rng := _seeded(42)
	var heavy := 0
	var light := 0
	for _i in range(1000):
		var drop := t.roll(rng)
		if drop["id"] == "heavy":
			heavy += 1
		else:
			light += 1
	return heavy > light


func test_drop_chance_one_always() -> bool:
	var t := LootTable.new()
	var rng := _seeded(9)
	for _i in range(20):
		if not t.drop_chance_satisfied(rng, 1.0):
			return false
	return true


func test_drop_chance_zero_never() -> bool:
	var t := LootTable.new()
	var rng := _seeded(9)
	for _i in range(20):
		if t.drop_chance_satisfied(rng, 0.0):
			return false
	return true


func test_drop_chance_clamped() -> bool:
	var t := LootTable.new()
	var rng := _seeded(9)
	# Out-of-range chances clamp: 5.0 -> always, -2.0 -> never.
	return t.drop_chance_satisfied(rng, 5.0) and not t.drop_chance_satisfied(rng, -2.0)


func test_expected_value_hand_computed() -> bool:
	# total = 4. EV = (3/4)*100*1.0 + (1/4)*0*0 = 75.0.
	var t := (
		LootTable
		. new(
			[
				{"id": "cash", "weight": 3.0, "min": 50, "max": 150},
				{"id": "", "weight": 1.0, "min": 0, "max": 0},
			]
		)
	)
	return is_equal_approx(t.expected_value({"cash": 1.0}), 75.0)


func test_expected_value_missing_value_is_zero() -> bool:
	var t := LootTable.new([{"id": "cash", "weight": 1.0, "min": 10, "max": 10}])
	return is_equal_approx(t.expected_value({}), 0.0)


func test_empty_table_roll_safe() -> bool:
	var t := LootTable.new([])
	# Empty input falls back to default; force a truly empty table instead:
	t.entries = []
	var drop := t.roll(_seeded(1))
	return drop["id"] == "" and drop["quantity"] == 0


func test_zero_weight_table_roll_safe() -> bool:
	var t := LootTable.new([{"id": "cash", "weight": 0.0, "min": 1, "max": 9}])
	var drop := t.roll(_seeded(1))
	return drop["id"] == "" and drop["quantity"] == 0 and is_equal_approx(t.total_weight(), 0.0)


func test_zero_weight_expected_value_zero() -> bool:
	var t := LootTable.new([{"id": "cash", "weight": 0.0, "min": 1, "max": 9}])
	return is_equal_approx(t.expected_value({"cash": 5.0}), 0.0)


func test_swapped_min_max_handled() -> bool:
	# min > max gets swapped during normalise, so quantity stays in [5, 10].
	var t := LootTable.new([{"id": "cash", "weight": 1.0, "min": 10, "max": 5}])
	var rng := _seeded(321)
	for _i in range(50):
		var drop := t.roll(rng)
		if drop["quantity"] < 5 or drop["quantity"] > 10:
			return false
	return true


func test_empty_drop_quantity_zero() -> bool:
	var t := LootTable.new([{"id": "", "weight": 1.0, "min": 5, "max": 5}])
	var drop := t.roll(_seeded(1))
	return drop["id"] == "" and drop["quantity"] == 0
