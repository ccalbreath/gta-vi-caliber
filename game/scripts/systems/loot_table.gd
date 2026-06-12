class_name LootTable
extends RefCounted
## Pure weighted loot/drop model for defeated enemies and smashed crates.
##
## No scene access — a node (enemy, crate) owns one and asks it for drops.
## All randomness goes through a caller-supplied RandomNumberGenerator so the
## outcome is reproducible in tests (tests/unit/test_loot_table.gd); never the
## global randf/randi.
##
## Each entry is a Dictionary {id: String, weight: float, min: int, max: int}.
## The "empty" drop (id == "") represents "nothing dropped".

var entries: Array = []


func _init(table: Array = []) -> void:
	if table.is_empty():
		entries = LootTable.default_table()
	else:
		entries = LootTable._normalise(table)


## A sensible default drop table for a generic enemy/crate.
static func default_table() -> Array:
	return (
		LootTable
		. _normalise(
			[
				{"id": "cash", "weight": 5.0, "min": 50, "max": 200},
				{"id": "pistol_ammo", "weight": 4.0, "min": 6, "max": 18},
				{"id": "smg_ammo", "weight": 2.0, "min": 10, "max": 30},
				{"id": "body_armor", "weight": 1.0, "min": 1, "max": 1},
				{"id": "", "weight": 3.0, "min": 0, "max": 0},
			]
		)
	)


## Sum of all (non-negative) entry weights.
func total_weight() -> float:
	var sum := 0.0
	for entry in entries:
		sum += maxf(entry["weight"], 0.0)
	return sum


func entry_count() -> int:
	return entries.size()


## Pick one entry by weight and roll its quantity in [min, max] using rng.
## Returns {id, quantity}; an empty/zero-weight table yields the empty drop.
func roll(rng: RandomNumberGenerator) -> Dictionary:
	var total := total_weight()
	if total <= 0.0:
		return {"id": "", "quantity": 0}
	var pick := rng.randf() * total
	var cursor := 0.0
	for entry in entries:
		cursor += maxf(entry["weight"], 0.0)
		if pick < cursor:
			return LootTable._roll_entry(entry, rng)
	# Float drift guard: fall back to the last weighted entry.
	return LootTable._roll_entry(entries[entries.size() - 1], rng)


## n independent rolls.
func roll_many(rng: RandomNumberGenerator, n: int) -> Array:
	var out: Array = []
	for _i in range(maxi(n, 0)):
		out.append(roll(rng))
	return out


## Gate whether anything drops at all. chance is clamped to [0, 1];
## chance >= 1 always drops, chance <= 0 never does.
func drop_chance_satisfied(rng: RandomNumberGenerator, chance: float) -> bool:
	return rng.randf() < clampf(chance, 0.0, 1.0)


## Expected value of one roll given a per-id unit value map.
## sum over entries of (weight/total) * avg_quantity * unit_value(id).
func expected_value(value_of: Dictionary) -> float:
	var total := total_weight()
	if total <= 0.0:
		return 0.0
	var sum := 0.0
	for entry in entries:
		var weight := maxf(entry["weight"], 0.0)
		if weight <= 0.0:
			continue
		var avg_qty := (float(entry["min"]) + float(entry["max"])) * 0.5
		var unit_value := float(value_of.get(entry["id"], 0.0))
		sum += (weight / total) * avg_qty * unit_value
	return sum


## Determinism helper: a fresh rng seeded with `seed`, so a given seed
## reproduces a sequence of rolls.
static func make_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Normalise a raw table: drop malformed entries, fill defaults, fix swapped
## min/max and clamp negatives.
static func _normalise(table: Array) -> Array:
	var out: Array = []
	for entry in table:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id := str(entry.get("id", ""))
		var weight := maxf(float(entry.get("weight", 0.0)), 0.0)
		var lo := int(entry.get("min", 0))
		var hi := int(entry.get("max", 0))
		if lo > hi:
			var tmp := lo
			lo = hi
			hi = tmp
		out.append({"id": id, "weight": weight, "min": lo, "max": hi})
	return out


## Roll the quantity for a chosen entry (empty id always yields quantity 0).
static func _roll_entry(entry: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var id := str(entry["id"])
	if id == "":
		return {"id": "", "quantity": 0}
	var quantity := rng.randi_range(int(entry["min"]), int(entry["max"]))
	return {"id": id, "quantity": quantity}
