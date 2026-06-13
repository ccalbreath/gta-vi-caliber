extends SceneTree
## Runtime wiring probe for the HitContractBoard -> PlayerStats + StockMarket loop,
## proven through the live node graph in a mock tree (no scene file). Drives the
## two-zone board: a non-player at the Board zone takes nothing (group gate); the
## player steps into the Board zone to ACCEPT the next contract, then reaches the
## Target zone to COMPLETE it — banking the reward and firing the contract's market
## shock at a StockMarket-shaped node. Physics overlap is the scene author's job;
## this probe emits body_entered on the zones directly. Run:
##   godot --headless --path game --script res://tests/hit_contract_probe.gd

const WARMUP_FRAMES: int = 3
const TRAVEL_A := Vector3(120, 0, 0)
const TRAVEL_B := Vector3(-120, 0, 0)

var _board_node: HitContractBoard = null
var _board_zone: Area3D = null
var _target_zone: Area3D = null
var _stats: MockStats = null
var _tracker: MockTracker = null
var _market: MockStockMarket = null
var _player: StaticBody3D = null
var _frames: int = 0

var _accepted_count: int = 0
var _accepted_reward: int = 0
var _last_accepted_id: String = ""
var _completed_count: int = 0
var _completed_reward: int = 0
var _completed_company: String = ""


class MockStats:
	extends Node
	var money: int = 0

	func _ready() -> void:
		add_to_group("player_stats")

	func add_money(amount: int) -> void:
		money += amount


class MockTracker:
	extends Node
	var counts: Dictionary = {}

	func _ready() -> void:
		add_to_group("stats")

	func add(key: String, amount: int) -> void:
		counts[key] = int(counts.get(key, 0)) + amount


class MockStockMarket:
	extends Node
	var shock_count: int = 0
	var last_company: String = ""
	var last_magnitude: float = 0.0

	func _ready() -> void:
		add_to_group("stock_market")

	func apply_rivalry_shock(company_id: String, magnitude: float, _spillover: float) -> bool:
		shock_count += 1
		last_company = company_id
		last_magnitude = magnitude
		return true


func _initialize() -> void:
	_stats = MockStats.new()
	root.add_child(_stats)
	_tracker = MockTracker.new()
	root.add_child(_tracker)
	_market = MockStockMarket.new()
	root.add_child(_market)

	_board_node = HitContractBoard.new()
	_board_zone = Area3D.new()
	_board_zone.name = "Board"
	_board_node.add_child(_board_zone)
	_target_zone = Area3D.new()
	_target_zone.name = "Target"
	_board_node.add_child(_target_zone)
	_board_node.contract_accepted.connect(_on_accepted)
	_board_node.contract_completed.connect(_on_completed)
	root.add_child(_board_node)

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _on_accepted(id: String, reward: int) -> void:
	_accepted_count += 1
	_accepted_reward = reward
	_last_accepted_id = id


func _on_completed(reward: int, company_id: String) -> void:
	_completed_count += 1
	_completed_reward = reward
	_completed_company = company_id


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _board_node == null or _board_zone == null or _target_zone == null or _player == null:
		return _fail("mock tree did not assemble")

	# Group gate: a non-player at the board takes no contract.
	var bystander := Node.new()
	root.add_child(bystander)
	_board_zone.body_entered.emit(bystander)
	if _accepted_count != 0:
		return _fail("a non-player took a contract")

	# Player accepts the next contract at the board.
	_board_zone.body_entered.emit(_player)
	if _accepted_count != 1 or _accepted_reward <= 0:
		return _fail("accepting a contract did not fire with a reward (%d)" % _accepted_reward)

	return _run_complete()


func _run_complete() -> bool:
	# Travel to the mark, then reach the target: bank the reward + fire the shock.
	_player.position = TRAVEL_A
	_target_zone.body_entered.emit(_player)
	if _completed_count != 1 or _completed_reward != _accepted_reward:
		return _fail("completing the hit did not pay the accepted reward")
	if _stats.money != _accepted_reward:
		return _fail("reward not banked: money %d != reward %d" % [_stats.money, _accepted_reward])
	if int(_tracker.counts.get("hits_done", 0)) != 1:
		return _fail("hit not recorded on the stats tracker")
	return _assert_market()


func _assert_market() -> bool:
	if _market.shock_count != 1 or _market.last_company != _completed_company:
		return _fail(
			(
				"market shock company mismatch: got '%s', want '%s'"
				% [_market.last_company, _completed_company]
			)
		)
	if is_zero_approx(_market.last_magnitude):
		return _fail("market shock fired with zero magnitude")
	return _run_second_contract()


# A second cycle proves re-accepting picks a NEW contract (not a re-farm of the
# same one), pays ITS own reward on top, and fires its own shock — then a stray
# target entry with no active contract pays nothing.
func _run_second_contract() -> bool:
	var money_after_first := _stats.money
	var first_id := _last_accepted_id
	_player.position = TRAVEL_A
	_board_zone.body_entered.emit(_player)  # accept the next contract
	if _accepted_count != 2 or _last_accepted_id == first_id:
		return _fail("re-accept did not pick a new contract (id %s)" % _last_accepted_id)
	var reward_b := _accepted_reward
	_player.position = TRAVEL_B  # travel to the new mark
	_target_zone.body_entered.emit(_player)
	if _completed_count != 2 or _stats.money != money_after_first + reward_b:
		return _fail("second hit did not add its own reward (money %d)" % _stats.money)
	if _market.shock_count != 2 or int(_tracker.counts.get("hits_done", 0)) != 2:
		return _fail("second hit did not fire shock/tracker")
	var banked := _stats.money
	_target_zone.body_entered.emit(_player)  # no active contract -> no-op
	if _stats.money != banked or _completed_count != 2:
		return _fail("a target entry with no active contract paid out")
	return _pass()


func _pass() -> bool:
	print(
		(
			"hit contract probe: OK (reward $%d banked, market shock %s x%.2f, tracker +1, no double-pay)"
			% [_completed_reward, _completed_company, _market.last_magnitude]
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("hit contract probe FAIL :: %s" % message)
	print("hit contract probe: FAIL — %s" % message)
	quit(1)
	return true
