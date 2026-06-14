extends SceneTree
## Scene-free probe for ContrabandDealer's police-proximity bust risk: with cops near
## the fence zone, repeated seeded sales must SOMETIMES bust (no payout, wanted poked),
## and with the cops gone EVERY sale must pay out (the original always-pay path is
## untouched). Built with mock player_stats / wanted / police nodes so it needs no
## scene file. Run headless:
##   godot --headless --path game --script res://tests/contraband_bust_probe.gd

## How close to the fence zone to seat the cops (well inside police_scan_radius).
const POLICE_DIST: float = 5.0
## Sale attempts per phase — enough that a >0 risk almost surely busts at least once.
const ATTEMPTS: int = 200

var _dealer: ContrabandDealer = null
var _stats: MockStats = null
var _wanted: MockWanted = null
var _police: Array[Node3D] = []


class MockStats:
	extends Node
	var money: int = 0

	func _ready() -> void:
		add_to_group("player_stats")

	func add_money(amount: int) -> void:
		money = maxi(0, money + amount)

	func spend_money(amount: int) -> bool:
		if amount <= 0 or money < amount:
			return false
		money -= amount
		return true


class MockWanted:
	extends Node
	var reports: int = 0

	func _ready() -> void:
		add_to_group("wanted")

	func report_crime(_killed: bool) -> void:
		reports += 1


func _initialize() -> void:
	_stats = MockStats.new()
	root.add_child(_stats)
	_wanted = MockWanted.new()
	root.add_child(_wanted)
	_dealer = ContrabandDealer.new()
	# Give the dealer a FenceZone child so _ready finds it and _police_factor can
	# measure cop distance against its global position.
	var fence := Area3D.new()
	fence.name = "FenceZone"
	_dealer.add_child(fence)
	root.add_child(_dealer)
	_dealer.set_seed(12345)
	# Seat the cops right next to the fence zone so police_factor is firmly > 0.
	for i in range(3):
		var cop := Node3D.new()
		cop.add_to_group("police")
		root.add_child(cop)
		cop.global_position = Vector3(POLICE_DIST + float(i), 0, 0)
		_police.append(cop)


func _process(_delta: float) -> bool:
	var with_cops := _run_phase(true)
	if not with_cops.is_empty():
		return _fail(with_cops)
	var busts := _wanted.reports
	# Pull the cops far outside police_scan_radius -> police_factor must be 0.
	for cop in _police:
		cop.global_position = Vector3(10000, 0, 0)
	var without_cops := _run_phase(false)
	if not without_cops.is_empty():
		return _fail(without_cops)
	print(
		(
			"contraband bust probe: OK (%d busts w/ police, all reported wanted; %d clean sales w/o police)"
			% [busts, ATTEMPTS]
		)
	)
	quit(0)
	return true


## Drive ATTEMPTS seeded sales. With police: assert at least one bust, that each bust
## poked the wanted node and paid $0. Without police: assert every sale paid and none
## busted (the original path is intact). Returns "" on success, else a failure reason.
func _run_phase(police_near: bool) -> String:
	var busts := 0
	var paid := 0
	for _i in range(ATTEMPTS):
		var attempt := _run_attempt()
		if not attempt["error"].is_empty():
			return attempt["error"]
		busts += int(attempt["busts"])
		paid += int(attempt["paid"])
	return _check_phase(police_near, busts, paid)


## One seeded sale + its per-outcome assertions. Returns
## {"error": String, "busts": int, "paid": int} — error non-empty on a broken invariant.
func _run_attempt() -> Dictionary:
	var money_before := _stats.money
	var reports_pre := _wanted.reports
	# Re-stock one unit so every attempt has something to sell.
	_dealer.market.carry(_dealer.good_id, 1)
	var outcome := _dealer.resolve_fence_sale()
	if bool(outcome["busted"]):
		if _stats.money != money_before:
			return _attempt_err("busted sale still paid (%d -> %d)" % [money_before, _stats.money])
		if _wanted.reports != reports_pre + 1:
			return _attempt_err("bust did not call report_crime on the wanted node")
		return {"error": "", "busts": 1, "paid": 0}
	if int(outcome["revenue"]) <= 0 or _stats.money <= money_before:
		return _attempt_err("clean sale did not credit the wallet")
	return {"error": "", "busts": 0, "paid": 1}


## Phase-level tally checks: with police some sales must bust; without police none may.
func _check_phase(police_near: bool, busts: int, paid: int) -> String:
	if police_near:
		if busts <= 0:
			return "no busts occurred with police on top of the fence zone"
		return ""
	if busts != 0:
		return "a bust occurred with no police near (no-police path changed)"
	if paid != ATTEMPTS:
		return "not every no-police sale paid out (%d of %d)" % [paid, ATTEMPTS]
	return ""


func _attempt_err(reason: String) -> Dictionary:
	return {"error": reason, "busts": 0, "paid": 0}


func _fail(reason: String) -> bool:
	push_error("contraband bust probe FAIL: " + reason)
	quit(1)
	return true
