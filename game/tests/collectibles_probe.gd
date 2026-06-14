extends SceneTree
## Runtime wiring probe for CollectiblesController + Collectible — the integration the pure-model
## unit tests (test_collection_set.gd) can't make: walking into a hidden package reports the find
## to the shared set and banks its bounty to PlayerStats, the find that COMPLETES the set pays the
## big set bonus, and a grabbed package goes dormant (re-walking it pays nothing). Run:
##   godot --headless --path game --script res://tests/collectibles_probe.gd

const WARMUP_FRAMES: int = 3
const REWARD: int = 250
const BONUS: int = 25000

var _ctrl: CollectiblesController = null
var _a: Collectible = null
var _b: Collectible = null
var _c: Collectible = null
var _stats: MockStats = null
var _player: StaticBody3D = null
var _frames: int = 0
var _set_bonus_paid: int = -1
var _last_count: int = -1
var _last_total: int = -1


class MockStats:
	extends Node
	var money: int = 0

	func _ready() -> void:
		add_to_group("player_stats")

	func add_money(amount: int) -> void:
		money += amount


func _initialize() -> void:
	_stats = MockStats.new()
	root.add_child(_stats)

	_ctrl = CollectiblesController.new()
	# A small fixed set so the run completes in three finds.
	_ctrl.items = [
		{"id": "a", "reward": REWARD}, {"id": "b", "reward": REWARD}, {"id": "c", "reward": REWARD}
	]
	_ctrl.set_bonus = BONUS
	_ctrl.set_completed.connect(_on_set_completed)
	_ctrl.collected.connect(_on_collected)
	root.add_child(_ctrl)

	_a = _make_collectible("a")
	_b = _make_collectible("b")
	_c = _make_collectible("c")

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _make_collectible(id: String) -> Collectible:
	var item := Collectible.new()
	item.collectible_id = id
	root.add_child(item)
	return item


func _on_set_completed(bonus: int) -> void:
	_set_bonus_paid = bonus


func _on_collected(_id: String, _reward: int, found_count: int, total: int) -> void:
	_last_count = found_count
	_last_total = total


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _ctrl == null or _a == null or _stats == null:
		return _fail("mock tree did not assemble")
	var checks: Array[Callable] = [
		_check_no_wallet, _check_progress, _check_complete, _check_refind
	]
	for check in checks:
		var err: String = check.call()
		if err != "":
			return _fail(err)
	return _pass()


func _check_no_wallet() -> String:
	# With no wallet to bank into, a grab must NOT consume the package — it stays grabbable.
	_stats.remove_from_group("player_stats")
	_a.body_entered.emit(_player)
	var untouched := not _ctrl.is_found("a") and _ctrl.found_count() == 0
	_stats.add_to_group("player_stats")  # restore for the real grabs
	if not untouched:
		return "a package was consumed with no wallet to pay into"
	return ""


func _check_progress() -> String:
	var m0 := _stats.money
	_a.body_entered.emit(_player)
	var signal_ok := _last_count == 1 and _last_total == 3
	if (
		_stats.money != m0 + REWARD
		or _ctrl.found_count() != 1
		or _ctrl.is_complete()
		or not signal_ok
	):
		return "the first package did not pay its bounty / progress (money %d)" % _stats.money
	_b.body_entered.emit(_player)
	if _stats.money != m0 + 2 * REWARD or _ctrl.found_count() != 2:
		return "the second package did not pay / progress (found %d)" % _ctrl.found_count()
	return ""


func _check_complete() -> String:
	var m0 := _stats.money
	_c.body_entered.emit(_player)  # the last one -> completes the set
	if _ctrl.found_count() != 3 or not _ctrl.is_complete():
		return "the final package did not complete the set (found %d)" % _ctrl.found_count()
	if _stats.money != m0 + REWARD + BONUS or _set_bonus_paid != BONUS:
		return (
			"the set-complete bonus was not paid (money +%d, bonus %d)"
			% [_stats.money - m0, _set_bonus_paid]
		)
	return ""


func _check_refind() -> String:
	var m0 := _stats.money
	_a.body_entered.emit(_player)  # already grabbed -> dormant, no-op
	if _stats.money != m0 or _ctrl.found_count() != 3:
		return "re-grabbing a collected package paid again (money %d)" % _stats.money
	return ""


func _pass() -> bool:
	print(
		(
			(
				"collectibles probe: OK (each package paid its bounty + progressed the hunt, the last "
				+ "completed the set for the $%d bonus, a grabbed package stayed dormant)"
			)
			% BONUS
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("collectibles probe FAIL :: %s" % message)
	print("collectibles probe: FAIL — %s" % message)
	quit(1)
	return true
