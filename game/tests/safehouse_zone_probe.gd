extends SceneTree
## Runtime wiring probe for the SafehouseZone lay-low loop: stepping into your
## safehouse heals the player (PlayerHealth) and sheds the wanted heat (clears the
## tracker), and the stash banks cash safe off your person. Run:
##   godot --headless --path game --script res://tests/safehouse_zone_probe.gd

const WARMUP_FRAMES: int = 3
const REST_HOURS: float = 8.0
# 8h * Safehouse.HEAL_PER_HOUR (20) = 160.
const EXPECTED_HEAL: float = 160.0
const START_MONEY: int = 1000

var _zone: SafehouseZone = null
var _health: MockHealth = null
var _wanted: MockWanted = null
var _stats: MockStats = null
var _player: StaticBody3D = null
var _frames: int = 0


class MockHealth:
	extends Node
	var healed_total: float = 0.0

	func _ready() -> void:
		add_to_group("player_health")

	func heal(amount: float) -> void:
		healed_total += amount


class MockWanted:
	extends Node
	var cleared: int = 0

	func _ready() -> void:
		add_to_group("wanted")

	func clear() -> void:
		cleared += 1


class MockStats:
	extends Node
	var money: int = 0

	func _ready() -> void:
		add_to_group("player_stats")

	func spend_money(amount: int) -> void:
		money -= amount

	func add_money(amount: int) -> void:
		money += amount


func _initialize() -> void:
	_health = MockHealth.new()
	root.add_child(_health)
	_wanted = MockWanted.new()
	root.add_child(_wanted)
	_stats = MockStats.new()
	root.add_child(_stats)

	_zone = SafehouseZone.new()
	_zone.rest_hours = REST_HOURS
	root.add_child(_zone)

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _zone == null or _health == null or _wanted == null or _stats == null:
		return _fail("mock tree did not assemble")
	_stats.money = START_MONEY

	# Group gate: a non-player at the door rests nothing.
	var bystander := StaticBody3D.new()
	root.add_child(bystander)
	_zone.body_entered.emit(bystander)
	if _health.healed_total != 0.0 or _wanted.cleared != 0:
		return _fail("a non-player rested at the safehouse")

	# The player lays low: heals + the heat is shed.
	_zone.body_entered.emit(_player)
	if not is_equal_approx(_health.healed_total, EXPECTED_HEAL):
		return _fail("rest did not heal the expected amount (%.1f)" % _health.healed_total)
	if _wanted.cleared != 1:
		return _fail("rest did not shed the wanted heat")

	return _run_stash()


func _run_stash() -> bool:
	# Bank cash in the stash: it leaves the wallet and is held safe at home.
	if _zone.deposit(400) != 400 or _stats.money != START_MONEY - 400:
		return _fail("deposit did not move cash to the stash (money %d)" % _stats.money)
	# Withdraw part of it back to the wallet.
	if _zone.withdraw_cash(150) != 150 or _stats.money != START_MONEY - 400 + 150:
		return _fail("withdraw did not return cash to the wallet (money %d)" % _stats.money)
	if _zone.stash_balance() != 250:
		return _fail("stash balance wrong after deposit/withdraw (%d)" % _zone.stash_balance())

	# Overdraft: withdrawing more than is stashed is bounded by the balance.
	if _zone.withdraw_cash(9999) != 250 or _zone.stash_balance() != 0:
		return _fail("overdraft withdraw was not bounded (balance %d)" % _zone.stash_balance())

	# Deposit beyond the wallet balance is rejected (-1), with no state moved.
	_stats.money = 50
	if _zone.deposit(100) != -1 or _stats.money != 50 or _zone.stash_balance() != 0:
		return _fail("deposit beyond the wallet mutated state (money %d)" % _stats.money)
	return _pass()


func _pass() -> bool:
	print("safehouse zone probe: OK (lay low heals + sheds heat; stash banks cash safe off you)")
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("safehouse zone probe FAIL :: %s" % message)
	print("safehouse zone probe: FAIL — %s" % message)
	quit(1)
	return true
