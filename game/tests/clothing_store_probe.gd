extends SceneTree
## Runtime wiring probe for the ClothingStore -> DisguiseController loop — the
## "duck into a clothes shop to shake the cops" staple, proven through the live
## node graph in a mock tree (no scene file, like the other systems-wiring probes).
##
## Drives the store's real body_entered path and the shared-Wardrobe ownership
## model:
##   * a non-player body is ignored (the group gate),
##   * the player enters store 1 -> buys + wears the disguise outfit (charging a
##     live PlayerStats node) and recognition drops / evasion speeds up,
##   * re-entering store 1 charges nothing (already wearing it all),
##   * entering a SECOND store re-wears an already-owned piece for FREE (ownership
##     lives on the controller, not per-store — no double charge).
## Physics overlap is the scene author's job (a CollisionShape3D child + layer 2);
## this probe verifies everything downstream of the entry. Run:
##   godot --headless --path game --script res://tests/clothing_store_probe.gd

const WARMUP_FRAMES: int = 3
const START_MONEY: int = 5000
# track_suit 400 + blonde_dye 300 + ski_mask 250.
const EXPECTED_SPEND: int = 950

var _store: ClothingStore = null
var _store2: ClothingStore = null
var _dc: DisguiseController = null
var _stats: MockStats = null
var _player: StaticBody3D = null
var _frames: int = 0


class MockStats:
	extends Node
	var money: int = 0

	func _ready() -> void:
		add_to_group("player_stats")

	func add_money(amount: int) -> void:
		money += amount

	func spend_money(amount: int) -> void:
		money -= amount


func _initialize() -> void:
	_stats = MockStats.new()
	root.add_child(_stats)

	_dc = DisguiseController.new()
	root.add_child(_dc)

	_store = ClothingStore.new()
	root.add_child(_store)

	# A second boutique selling the same disguise outfit, to prove ownership is
	# shared (the player isn't charged twice for clothes they already own).
	_store2 = ClothingStore.new()
	root.add_child(_store2)

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _stats == null or _dc == null or _store == null or _store2 == null or _player == null:
		return _fail("mock tree did not assemble")

	_stats.add_money(START_MONEY)
	# The cops get a clean look at the player's current (default) appearance.
	_dc.log_sighting()
	var recognition_before := _dc.recognition()
	if not is_equal_approx(recognition_before, 1.0):
		return _fail("expected full recognition after sighting, got %f" % recognition_before)

	# Group gate: a random non-player body wandering in must do nothing.
	var bystander := Node.new()
	root.add_child(bystander)
	_store.body_entered.emit(bystander)
	if _dc.changed_slots() != 0 or _stats.money != START_MONEY:
		return _fail("a non-player body changed the disguise / spent money")

	# The player walks in: the store kits them out and re-skins the Disguise.
	_store.body_entered.emit(_player)
	return _assert_disguised(recognition_before)


func _assert_disguised(recognition_before: float) -> bool:
	var spent := START_MONEY - _stats.money
	if spent != EXPECTED_SPEND:
		return _fail("expected to spend %d on the outfit, spent %d" % [EXPECTED_SPEND, spent])
	if _dc.changed_slots() != 3:
		return _fail("expected 3 appearance slots changed, got %d" % _dc.changed_slots())
	var after := _dc.recognition()
	if after >= recognition_before:
		return _fail("recognition did not drop (%f -> %f)" % [recognition_before, after])
	if _dc.evasion_speedup() <= 2.0:
		return _fail("evasion speed-up too low after disguise: %f" % _dc.evasion_speedup())
	return _assert_no_double_charge(recognition_before, after, spent)


func _assert_no_double_charge(recognition_before: float, after: float, spent: int) -> bool:
	var banked := _stats.money

	# Re-enter the same store: everything is already worn, so nothing is bought.
	_store.body_entered.emit(_player)
	if _stats.money != banked:
		return _fail("re-entering the store charged again (%d -> %d)" % [banked, _stats.money])

	# Take the jacket off, then visit a DIFFERENT store selling the same outfit:
	# the track suit is already owned, so re-wearing it must be free.
	_dc.wardrobe().wear("street_casual")
	_store2.body_entered.emit(_player)
	if _stats.money != banked:
		return _fail(
			"a second store re-charged for an owned item (%d -> %d)" % [banked, _stats.money]
		)

	return _pass(spent, recognition_before, after)


func _pass(spent: int, recognition_before: float, after: float) -> bool:
	print(
		(
			"clothing store probe: OK (spent $%d once, recognition %.2f -> %.2f, evasion x%.2f)"
			% [spent, recognition_before, after, _dc.evasion_speedup()]
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("clothing store probe FAIL :: %s" % message)
	print("clothing store probe: FAIL — %s" % message)
	quit(1)
	return true
