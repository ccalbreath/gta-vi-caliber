extends SceneTree
## Runtime wiring probe for PawnShop — the integration the pure-model unit tests
## (test_haggle.gd) can't make: stepping into a pawn shop runs the haggle to its configured
## persistence and banks the agreed price to PlayerStats. Three shops pawn an IDENTICAL item:
## one takes the opening lowball (persistence 0), one squeezes to the buyer's PEAK (persistence
## = patience), one OVER-PLAYS it (persistence well past patience). Proves haggling up beats the
## opening AND that over-playing your hand backfires. Run:
##   godot --headless --path game --script res://tests/pawn_shop_probe.gd

const WARMUP_FRAMES: int = 3
const ITEM: int = 5000
const PATIENCE: int = 4  # Haggle.DEFAULT_PATIENCE
const OVER: int = 8

var _low: PawnShop = null
var _peak: PawnShop = null
var _over: PawnShop = null
var _stats: MockStats = null
var _player: StaticBody3D = null
var _frames: int = 0
var _last_price: int = -1


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

	_low = _make_shop(0)
	_peak = _make_shop(PATIENCE)
	_over = _make_shop(OVER)

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _make_shop(persistence: int) -> PawnShop:
	var shop := PawnShop.new()
	shop.item_value = ITEM
	shop.haggle_persistence = persistence
	shop.pawned.connect(_on_pawned)
	root.add_child(shop)
	return shop


func _on_pawned(_item_value: int, price: int) -> void:
	_last_price = price


func _visit(shop: PawnShop) -> void:
	shop.body_entered.emit(_player)
	shop.body_exited.emit(_player)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _low == null or _peak == null or _over == null or _stats == null:
		return _fail("mock tree did not assemble")
	var err := _check_haggle_curve()
	if err != "":
		return _fail(err)
	return _pass()


func _check_haggle_curve() -> String:
	var m0 := _stats.money
	_visit(_low)
	var price_low := _stats.money - m0
	var m1 := _stats.money
	_visit(_peak)
	var price_peak := _stats.money - m1
	var m2 := _stats.money
	_visit(_over)
	var price_over := _stats.money - m2
	if price_low <= 0 or price_peak <= price_low:
		return (
			"haggling to the peak did not beat the opening lowball (%d vs %d)"
			% [price_peak, price_low]
		)
	if price_over >= price_peak:
		return "over-playing the haggle did not backfire (%d vs peak %d)" % [price_over, price_peak]
	if _last_price != price_over:
		return (
			"the pawned signal price %d did not match the last deal %d" % [_last_price, price_over]
		)
	# The peak deal must match the model's exact computed peak.
	var reference := Haggle.new(ITEM)
	for _i in PATIENCE:
		reference.push()
	if price_peak != reference.accept():
		return "the peak deal did not match the model (%d)" % price_peak
	# One item per shop: a second visit pays nothing more.
	var m3 := _stats.money
	_visit(_peak)
	if _stats.money != m3:
		return "a sold-out pawn shop paid again on re-visit (money %d)" % _stats.money
	return ""


func _pass() -> bool:
	print(
		(
			"pawn shop probe: OK (opening lowball < squeezed-to-peak deal; over-playing the "
			+ "haggle backfired below the peak — the model curve drives the payout)"
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("pawn shop probe FAIL :: %s" % message)
	print("pawn shop probe: FAIL — %s" % message)
	quit(1)
	return true
