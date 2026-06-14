class_name FenceController
extends Node
## Owns the player's ONE Fence — the stolen-goods stash. Self-wires by group
## ("fence") so a BurglaryZone drops loot in and a FenceCounter sells it. Runs a day
## clock that COOLS the goods over time: freshly-stolen loot is hot and fences for
## less, so sitting on it a few days fetches a better quote. Drives the tested Fence
## model (tests/unit/test_fence.gd); verified in tests/fence_loop_probe.gd.

signal loot_added(id: String, value: int)

## Floor on the day period + cap on days advanced per frame.
const MIN_SECONDS_PER_DAY: float = 1.0
const MAX_DAYS_PER_FRAME: float = 10.0

## Real seconds per in-game day for the cool-off clock (<=0 pauses it).
@export var seconds_per_day: float = 60.0

var _fence: Fence
var _day_accum: float = 0.0
var _next_id: int = 0


func _ready() -> void:
	_fence = Fence.new()
	add_to_group("fence")


func _process(delta: float) -> void:
	if seconds_per_day <= 0.0 or _fence == null:
		return
	var period := maxf(seconds_per_day, MIN_SECONDS_PER_DAY)
	_day_accum = minf(_day_accum + delta, period * MAX_DAYS_PER_FRAME)
	while _day_accum >= period:
		_day_accum -= period
		_fence.cool(1.0)


## Drop a stolen valuable into the stash as HOT goods (a unique id is minted).
## Returns the id, or "" if it couldn't be added.
func add_loot(category: String, value: int) -> String:
	if _fence == null or value <= 0:
		return ""
	# Scope the id to this controller so two fence stashes can never mint a colliding
	# id (there is normally one, but be robust to a second being placed).
	var id := "loot_%d_%d" % [get_instance_id(), _next_id]
	_next_id += 1
	if not _fence.add_loot(id, category, value):
		return ""
	loot_added.emit(id, value)
	return id


## Sell the whole stash at the current (heat-discounted) quote; returns the proceeds
## and clears the inventory.
func sell_all() -> int:
	return _fence.sell_all() if _fence != null else 0


## Sticker value of everything in the stash (pre-fence-cut), for a HUD readout.
func inventory_value() -> int:
	return _fence.inventory_value() if _fence != null else 0


## Number of stolen items currently held.
func inventory_count() -> int:
	return _fence.inventory_count() if _fence != null else 0
