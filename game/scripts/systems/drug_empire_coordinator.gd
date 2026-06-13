class_name DrugEmpireCoordinator
extends Node
## Self-wiring coordinator that runs the whole drug VERTICAL as ONE drop-in node:
## DrugLab cooks → DealerNetwork distributes → MoneyLaundering washes → the clean
## money is banked to `player_stats`. It packages three pure systems into a single
## thing you add to `miami.tscn` with one line (set `auto = true` and it ticks a
## "business day" on a timer, reading live police heat from the `wanted` group).
##
## The orchestration core, [method run_day], is pure (it touches no scene tree —
## only the owned models), so it unit-tests headless
## (tests/unit/test_drug_empire_coordinator.gd). The only tree-touching code is the
## thin self-wiring in [method _ready]/[method _on_day] (the timer + group lookups +
## wallet credit), mirroring `CharacterSwitcher`'s `player_stats` hookup.

## Units cooked per business day (a batch finishes same-day at this cook step).
@export var batch_size: int = 20
## Cook time of a batch — equal to one day's cook step so a batch finishes daily.
@export var cook_per_day: float = 60.0
## Street price per unit the dealers sell at.
@export var unit_price: int = 40
## Baseline district demand (0..1) used by the live timer path.
@export var demand: float = 0.8
## Turf control (0..1) assumed by the live path until a GangTerritory feed is wired.
@export var turf_control: float = 0.5
## When true, the node runs itself on a timer once in the scene.
@export var auto: bool = false
## Real seconds between business days on the live timer.
@export var day_seconds: float = 120.0

var _lab: DrugLab
var _dealer: DealerNetwork
var _laundering: MoneyLaundering


func _init() -> void:
	_lab = DrugLab.new()
	_dealer = DealerNetwork.new()
	_laundering = MoneyLaundering.new()


# Owned models, exposed so a setup UI (or a probe) can recruit dealers etc.
func lab() -> DrugLab:
	return _lab


func dealer() -> DealerNetwork:
	return _dealer


func laundering() -> MoneyLaundering:
	return _laundering


func _ready() -> void:
	if auto:
		var timer := Timer.new()
		timer.wait_time = maxf(day_seconds, 1.0)
		timer.autostart = true
		timer.timeout.connect(_on_day)
		add_child(timer)


func _on_day() -> void:
	var result := run_day(demand, unit_price, _heat_from_wanted(), turf_control)
	_credit_wallet(int(result["clean_earned"]))


## Pure core: cook a batch, supply + sell it, wash the proceeds. Returns
## {produced, sold, revenue, clean_earned, dirty_left}. No scene access.
func run_day(demand01: float, price: int, heat01: float, turf01: float) -> Dictionary:
	if not _lab.is_cooking():
		_lab.start_batch(batch_size, cook_per_day)
	_lab.cook(cook_per_day)
	var produced := 0
	if _lab.is_batch_done():
		var got := _lab.collect()
		produced = int(got["units"])
		_dealer.supply(produced)

	var sale := _dealer.run_cycle(demand01, price, heat01, turf01)
	_laundering.add_dirty(int(sale["revenue"]))
	_laundering.tick()  # open a fresh laundering window
	var washed := _laundering.launder("marina", _laundering.dirty_balance())
	return {
		"produced": produced,
		"sold": int(sale["units_sold"]),
		"revenue": int(sale["revenue"]),
		"clean_earned": int(washed["clean"]),
		"dirty_left": _laundering.dirty_balance(),
	}


# --- Live self-wiring (tree-touching; exercised in-scene, not in the unit test) --


func _heat_from_wanted() -> float:
	var nodes := get_tree().get_nodes_in_group("wanted")
	if nodes.is_empty():
		return 0.0
	var w: Node = nodes[0]
	if w.has_method("stars"):
		return clampf(float(w.stars()) / 5.0, 0.0, 1.0)
	return 0.0


func _credit_wallet(amount: int) -> void:
	if amount <= 0:
		return
	var nodes := get_tree().get_nodes_in_group("player_stats")
	if nodes.is_empty():
		return
	var stats: Node = nodes[0]
	if stats.has_method("add_money"):
		stats.add_money(amount)
