extends SceneTree
## Runtime wiring probe for the SmugglingRoute gauntlet AND the gym->smuggling tie:
## loading at the Pickup zone then reaching the Dropoff runs the route — interdictions
## seize cargo (less delivered, more heat) unless your EVASION is high, and a trained
## DRIVER (PlayerSkills bonus) evades better. So an unskilled run loses cargo while an
## identical run by a maxed driver brings it all home. Run:
##   godot --headless --path game --script res://tests/smuggling_route_probe.gd

const WARMUP_FRAMES: int = 3
const CARGO: int = 20
const UNIT_VALUE: int = 500
const FULL_VALUE: int = CARGO * UNIT_VALUE  # a clean run's take

var _skills: PlayerSkillsController = null
var _route_a: SmugglingRoute = null
var _pick_a: Area3D = null
var _drop_a: Area3D = null
var _route_b: SmugglingRoute = null
var _pick_b: Area3D = null
var _drop_b: Area3D = null
var _stats: MockStats = null
var _wanted: MockWanted = null
var _player: StaticBody3D = null
var _frames: int = 0
var _delivered_count: int = 0
var _last_value: int = -1


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
	_skills = PlayerSkillsController.new()
	root.add_child(_skills)
	_stats = MockStats.new()
	root.add_child(_stats)
	_wanted = MockWanted.new()
	root.add_child(_wanted)

	var a := _make_route()
	_route_a = a[0]
	_pick_a = a[1]
	_drop_a = a[2]
	var b := _make_route()
	_route_b = b[0]
	_pick_b = b[1]
	_drop_b = b[2]

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _make_route() -> Array:
	var route := SmugglingRoute.new()
	route.cargo_units = CARGO
	route.unit_value = UNIT_VALUE
	route.leg_risks = PackedFloat32Array([0.5, 0.5])
	route.base_evasion = 0.0  # so the driving skill is the whole evasion
	var pickup := Area3D.new()
	pickup.name = "Pickup"
	route.add_child(pickup)
	var dropoff := Area3D.new()
	dropoff.name = "Dropoff"
	route.add_child(dropoff)
	route.run_delivered.connect(_on_delivered)
	root.add_child(route)
	return [route, pickup, dropoff]


func _on_delivered(value: int, _seized: int) -> void:
	_delivered_count += 1
	_last_value = value


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _route_a == null or _route_b == null or _stats == null or _skills == null:
		return _fail("mock tree did not assemble")

	# Can't deliver before loading: reaching the dropoff with no cargo does nothing.
	_drop_a.body_entered.emit(_player)
	if _delivered_count != 0 or _stats.money != 0:
		return _fail("delivered without loading the cargo")

	# Unskilled run: load, then run the gauntlet — interdictions seize cargo.
	_pick_a.body_entered.emit(_player)
	_drop_a.body_entered.emit(_player)
	if _delivered_count != 1 or _stats.money != _last_value:
		return _fail("the run did not deliver / pay (value %d)" % _last_value)
	if _last_value <= 0 or _last_value >= FULL_VALUE or _wanted.crimes < 1:
		return _fail("an unskilled run was not chipped away (value %d)" % _last_value)

	return _run_skilled(_last_value, _wanted.crimes)


func _run_skilled(unskilled_value: int, heat_after_a: int) -> bool:
	# Max the driving skill, then run an IDENTICAL route: a clean driver evades every
	# leg and brings the whole load home.
	_skills.train("driving", 100.0)
	# Isolate the layers: a maxed skill must report a full 1.0 bonus, else the clean-run
	# assertion below would fail without telling us the skills system regressed.
	if _skills.bonus("driving") < 1.0:
		return _fail("driving maxed but bonus < 1.0 (got %f)" % _skills.bonus("driving"))
	_pick_b.body_entered.emit(_player)
	var money_before := _stats.money
	_drop_b.body_entered.emit(_player)
	var skilled_value := _stats.money - money_before
	if _delivered_count != 2 or skilled_value <= unskilled_value:
		return _fail(
			"a trained driver did not deliver more (%d vs %d)" % [skilled_value, unskilled_value]
		)
	if skilled_value != FULL_VALUE or _wanted.crimes != heat_after_a:
		return _fail("a clean run did not bring the full load home (value %d)" % skilled_value)
	return _assert_no_replay(unskilled_value, skilled_value)


func _assert_no_replay(unskilled_value: int, skilled_value: int) -> bool:
	# A consumed route ignores re-entry: stepping back through the spent route's Pickup
	# then Dropoff must NOT re-load or pay again (the _ran guard blocks both zones). This
	# guards against a future refactor opening a double-run / restock window.
	var money_snap := _stats.money
	var delivered_snap := _delivered_count
	_pick_a.body_entered.emit(_player)  # re-load the spent route — no-op
	_drop_a.body_entered.emit(_player)  # re-run the spent route — no-op
	if _stats.money != money_snap or _delivered_count != delivered_snap:
		return _fail("a consumed route paid out again on re-entry")
	return _pass(unskilled_value, skilled_value)


func _pass(unskilled: int, skilled: int) -> bool:
	print(
		(
			"smuggling route probe: OK (unskilled run $%d chipped away; trained driver runs clean for $%d)"
			% [unskilled, skilled]
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("smuggling route probe FAIL :: %s" % message)
	print("smuggling route probe: FAIL — %s" % message)
	quit(1)
	return true
