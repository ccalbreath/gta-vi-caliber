extends SceneTree
## Runtime wiring probe for the StoreCounter stick-up: robbing the register pays cash
## to PlayerStats and draws police heat (a tripped silent alarm draws more), and the
## till refills over days. Drives the refill clock manually for a deterministic run.
## Run: godot --headless --path game --script res://tests/store_counter_probe.gd

const WARMUP_FRAMES: int = 3
# intim 0.7 -> take_frac lerp(0.4,1,0.7)=0.82 -> floor(800*0.82)=656, no alarm.
const QUIET_TAKE: int = 656
# intim 0.3 -> alarm; take_frac 0.58 -> floor(500*0.58)=290.
const ALARM_TAKE: int = 290

var _quiet: StoreCounter = null
var _alarm: StoreCounter = null
var _drainable: StoreCounter = null
var _stats: MockStats = null
var _wanted: MockWanted = null
var _player: StaticBody3D = null
var _frames: int = 0
var _last_alarm: bool = false


class MockStats:
	extends Node
	var money: int = 0

	func _ready() -> void:
		add_to_group("player_stats")

	func add_money(amount: int) -> void:
		money += amount


class MockWanted:
	extends Node
	var crimes: int = 0

	func _ready() -> void:
		add_to_group("wanted")

	func report_crime(_killed: bool) -> void:
		crimes += 1


func _initialize() -> void:
	_stats = MockStats.new()
	root.add_child(_stats)
	_wanted = MockWanted.new()
	root.add_child(_wanted)

	_quiet = StoreCounter.new()
	_quiet.register_cash = 800
	_quiet.refill_per_day = 400
	_quiet.intimidation = 0.7
	_quiet.seconds_per_day = 1.0
	_quiet.robbed.connect(_on_robbed)
	root.add_child(_quiet)

	_alarm = StoreCounter.new()
	_alarm.register_cash = 500
	_alarm.intimidation = 0.3  # below ALARM_THRESHOLD -> trips the alarm
	_alarm.robbed.connect(_on_robbed)
	root.add_child(_alarm)

	_drainable = StoreCounter.new()
	_drainable.register_cash = 200
	_drainable.intimidation = 1.0  # full take empties the till in one rob
	_drainable.seconds_per_day = 0.0  # no refill, so it stays empty for the guard test
	root.add_child(_drainable)

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _on_robbed(_took: int, alarm: bool) -> void:
	_last_alarm = alarm


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _quiet == null or _alarm == null or _stats == null or _wanted == null:
		return _fail("mock tree did not assemble")
	_quiet.set_process(false)  # drive the refill clock manually
	_alarm.set_process(false)

	# Group gate: a non-player can't rob the register.
	var bystander := StaticBody3D.new()
	root.add_child(bystander)
	_quiet.body_entered.emit(bystander)
	if _stats.money != 0 or _wanted.crimes != 0:
		return _fail("a non-player robbed the store")

	# Rob the quiet store: take scales with intimidation, no alarm, one crime.
	_quiet.body_entered.emit(_player)
	if _stats.money != QUIET_TAKE or _quiet.till() != 800 - QUIET_TAKE:
		return _fail("robbery take wrong (money %d, till %d)" % [_stats.money, _quiet.till()])
	if _wanted.crimes != 1 or _last_alarm:
		return _fail("a quiet robbery did not draw exactly one crime / tripped the alarm")

	return _run_refill_alarm()


func _run_refill_alarm() -> bool:
	# Two days pass: the till refills back toward its cap.
	_quiet._process(2.0)
	if _quiet.till() != 800:
		return _fail("the till did not refill over days (%d)" % _quiet.till())

	# Rob the alarm store (low intimidation): it trips the silent alarm -> a SECOND
	# crime (cops come harder) on top of the robbery.
	_alarm.body_entered.emit(_player)
	if _stats.money != QUIET_TAKE + ALARM_TAKE or not _last_alarm:
		return _fail("alarm robbery wrong (money %d, alarm %s)" % [_stats.money, _last_alarm])
	if _wanted.crimes != 3:
		return _fail("a tripped alarm did not add a second crime (crimes %d)" % _wanted.crimes)

	# A full-intimidation rob empties the till; a second entry on the empty till is
	# then a no-op (the register_balance<=0 guard) — no extra cash, no extra crime.
	_drainable.body_entered.emit(_player)
	if _drainable.till() != 0:
		return _fail("a full rob did not empty the till (%d)" % _drainable.till())
	var crimes_after_empty := _wanted.crimes
	var money_after_empty := _stats.money
	_drainable.body_entered.emit(_player)
	if _wanted.crimes != crimes_after_empty or _stats.money != money_after_empty:
		return _fail("robbing an empty till was not a no-op")
	return _pass()


func _pass() -> bool:
	print(
		"store counter probe: OK (rob -> cash + heat; till refills; soft rob trips the alarm = more heat)"
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("store counter probe FAIL :: %s" % message)
	print("store counter probe: FAIL — %s" % message)
	quit(1)
	return true
