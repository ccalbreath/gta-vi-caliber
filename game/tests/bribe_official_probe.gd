extends SceneTree
## Runtime wiring probe for BribeOfficial — the integration the pure-model unit tests
## (test_bribery.gd) can't make: stepping up to a crooked official reads the LIVE wanted stars,
## prices the bribe off them, slips them offer_fraction of it, and resolves against the world —
## a full bribe charges PlayerStats and CLEARS the heat, an insulting lowball raises it
## (report_crime), a short offer is quietly refused, and a clean sheet is a no-op. Run:
##   godot --headless --path game --script res://tests/bribe_official_probe.gd

const WARMUP_FRAMES: int = 3
const STARS: int = 3
const PRICE: int = 5500  # base 1000 + 1500*3
const START_MONEY: int = 10000

var _backfire: BribeOfficial = null
var _refuse: BribeOfficial = null
var _bribe: BribeOfficial = null
var _stats: MockStats = null
var _wanted: MockWanted = null
var _player: StaticBody3D = null
var _frames: int = 0
var _last_outcome: String = ""


class MockStats:
	extends Node
	var money: int = 0

	func _ready() -> void:
		add_to_group("player_stats")

	func spend_money(amount: int) -> bool:
		if amount <= 0 or money < amount:
			return false
		money -= amount
		return true


class MockWanted:
	extends Node
	var star_value: int = 0
	var crimes: int = 0
	var cleared: bool = false

	func _ready() -> void:
		add_to_group("wanted")

	func stars() -> int:
		return star_value

	func report_crime(_killed: bool) -> void:
		crimes += 1

	func clear() -> void:
		cleared = true
		star_value = 0


func _initialize() -> void:
	_stats = MockStats.new()
	_stats.money = START_MONEY
	root.add_child(_stats)
	_wanted = MockWanted.new()
	_wanted.star_value = STARS
	root.add_child(_wanted)

	_backfire = _make_official(0.2)  # an insulting lowball
	_refuse = _make_official(0.7)  # short but not insulting
	_bribe = _make_official(1.0)  # the full ask

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _make_official(fraction: float) -> BribeOfficial:
	var official := BribeOfficial.new()
	official.offer_fraction = fraction
	official.bribe_resolved.connect(_on_resolved)
	root.add_child(official)
	return official


func _on_resolved(outcome: String, _spent: int) -> void:
	_last_outcome = outcome


func _visit(official: BribeOfficial) -> void:
	_last_outcome = ""
	official.body_entered.emit(_player)
	official.body_exited.emit(_player)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _bribe == null or _wanted == null or _stats == null:
		return _fail("mock tree did not assemble")
	var checks: Array[Callable] = [
		_check_backfire, _check_refused, _check_cant_afford, _check_bribed, _check_no_heat
	]
	for check in checks:
		var err: String = check.call()
		if err != "":
			return _fail(err)
	return _pass()


func _check_backfire() -> String:
	# An insulting lowball books you: more heat, no charge.
	var crimes_before := _wanted.crimes
	var money_before := _stats.money
	_visit(_backfire)
	if _last_outcome != "backfired" or _wanted.crimes <= crimes_before:
		return "an insulting lowball did not backfire into more heat (%s)" % _last_outcome
	if _stats.money != money_before:
		return "a backfired bribe still charged the wallet (money %d)" % _stats.money
	return ""


func _check_refused() -> String:
	# Short but not insulting: waved off, no effect either way.
	var money_before := _stats.money
	_visit(_refuse)
	if _last_outcome != "refused" or _stats.money != money_before or _wanted.star_value != STARS:
		return "a short-but-not-insulting offer was not quietly refused (%s)" % _last_outcome
	return ""


func _check_cant_afford() -> String:
	# The model says "bribed" on a full offer, but an empty wallet must NOT clear the heat — the
	# spend-before-clear safety net (the only path where model "bribed" → activity "refused").
	var saved := _stats.money
	_stats.money = PRICE - 1  # just short of the going price
	_visit(_bribe)
	var refused := _last_outcome == "refused"
	var untouched := (
		_stats.money == PRICE - 1 and _wanted.star_value == STARS and not _wanted.cleared
	)
	_stats.money = saved  # restore for the real bribe in the next check
	if not refused or not untouched:
		return "a bribe the player couldn't afford still cleared the heat (%s)" % _last_outcome
	return ""


func _check_bribed() -> String:
	# The full ask buys your way out: charged the going price, heat cleared.
	var money_before := _stats.money
	_visit(_bribe)
	if _last_outcome != "bribed":
		return "a full-price bribe was not accepted (%s)" % _last_outcome
	if _stats.money != money_before - PRICE:
		return "the bribe did not charge the going price (money %d)" % _stats.money
	if not _wanted.cleared or _wanted.star_value != 0:
		return "a successful bribe did not clear the heat"
	return ""


func _check_no_heat() -> String:
	# The sheet is clean now — there's nothing left to buy off, so a visit is a no-op.
	var money_before := _stats.money
	_visit(_bribe)
	if _stats.money != money_before or _last_outcome != "":
		return "bribed an official with no heat to clear (%s)" % _last_outcome
	return ""


func _pass() -> bool:
	print(
		(
			(
				"bribe official probe: OK (a lowball backfired into more heat, a short offer was "
				+ "refused, the full ask cleared the heat for $%d, a clean sheet was a no-op)"
			)
			% PRICE
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("bribe official probe FAIL :: %s" % message)
	print("bribe official probe: FAIL — %s" % message)
	quit(1)
	return true
