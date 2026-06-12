class_name WeaponInventory
extends RefCounted
## Pure owned-weapon / ammo model for the player's arsenal and weapon-wheel.
##
## No scene access — a node (e.g. WeaponController) owns one and asks it what is
## equipped and whether a shot can go out, so the slot/ammo/reload logic is
## unit-tested (tests/unit/test_weapon_inventory.gd).
##
## Each owned weapon is one slot keyed by a string id, holding its own magazine
## (chambered rounds) and reserve (spare) ammo independently. Acquiring a weapon
## already owned just tops up its reserve instead of adding a second slot.
##
## The inventory starts with the always-present unarmed "fists" slot equipped, so
## current_id() is never empty and the wheel always has at least one entry.

const UNARMED_ID: String = "fists"

## Insertion-ordered list of owned weapon ids; drives weapon-wheel cycling.
var _order: Array[String] = []
## id -> {"mag_size": int, "mag": int, "reserve": int}
var _slots: Dictionary = {}
var _current: String = ""


func _init() -> void:
	# Fists are unarmed: a zero-capacity slot that can never fire or hold ammo.
	_order.append(UNARMED_ID)
	_slots[UNARMED_ID] = {"mag_size": 0, "mag": 0, "reserve": 0}
	_current = UNARMED_ID


## Acquire a weapon. If already owned, top up its reserve ammo instead of adding
## a second slot (mag_size of the existing slot is kept). Negative inputs clamp
## to zero. The newly acquired weapon starts with a full magazine.
func add_weapon(id: String, mag_size: int = 0, ammo: int = 0) -> void:
	if id.is_empty():
		return
	var size := maxi(mag_size, 0)
	var spare := maxi(ammo, 0)
	if _slots.has(id):
		add_ammo(id, spare)
		return
	_order.append(id)
	_slots[id] = {"mag_size": size, "mag": size, "reserve": spare}


## Add spare (reserve) ammo to an owned weapon. No-op if unowned or amount <= 0.
func add_ammo(id: String, amount: int) -> void:
	if amount <= 0 or not _slots.has(id):
		return
	_slots[id]["reserve"] += amount


func has_weapon(id: String) -> bool:
	return _slots.has(id)


func weapon_count() -> int:
	return _order.size()


## Owned weapon ids in wheel order (a copy, so callers cannot mutate state).
func owned_ids() -> Array:
	return _order.duplicate()


## Equip an owned weapon. Returns false and leaves the current weapon unchanged
## if the id is not owned.
func equip(id: String) -> bool:
	if not _slots.has(id):
		return false
	_current = id
	return true


func current_id() -> String:
	return _current


## Cycle to the next owned weapon (wraps). Returns the newly equipped id.
func next_weapon() -> String:
	return _cycle(1)


## Cycle to the previous owned weapon (wraps). Returns the newly equipped id.
func previous_weapon() -> String:
	return _cycle(-1)


## Whether the current weapon has a round chambered (mag not empty).
func can_fire() -> bool:
	return _mag_of(_current) > 0


## Consume one round from the current magazine. Returns whether a shot went out;
## false (and consumes nothing) when the magazine is empty.
func fire() -> bool:
	if not can_fire():
		return false
	_slots[_current]["mag"] -= 1
	return true


func ammo_in_mag() -> int:
	return _mag_of(_current)


func reserve_ammo() -> int:
	if not _slots.has(_current):
		return 0
	return _slots[_current]["reserve"]


## Refill the current magazine from reserve up to mag_size. Returns how many
## rounds were loaded: a partial reload when reserve is low, 0 when already full
## or the reserve is empty.
func reload() -> int:
	if not _slots.has(_current):
		return 0
	var slot: Dictionary = _slots[_current]
	var needed: int = slot["mag_size"] - slot["mag"]
	if needed <= 0:
		return 0
	var loaded := mini(needed, slot["reserve"])
	slot["mag"] += loaded
	slot["reserve"] -= loaded
	return loaded


# --- private helpers -------------------------------------------------------


func _mag_of(id: String) -> int:
	if not _slots.has(id):
		return 0
	return _slots[id]["mag"]


func _cycle(step: int) -> String:
	if _order.is_empty():
		return _current
	var index := _order.find(_current)
	if index == -1:
		index = 0
	var count := _order.size()
	var next_index := ((index + step) % count + count) % count
	_current = _order[next_index]
	return _current
