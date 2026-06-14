extends SceneTree
## Runtime wiring probe for the burgle->fence loop: a BurglaryZone lifts valuables
## into the shared FenceController (drawing police heat), and a FenceCounter sells
## the stash for cash — paying LESS for hot goods, so letting them cool over days
## fetches more. Drives the cool clock manually for a deterministic run. Run:
##   godot --headless --path game --script res://tests/fence_loop_probe.gd

const WARMUP_FRAMES: int = 3
const LOOT_VALUE: int = 1200

var _fence: FenceController = null
var _burgle_a: BurglaryZone = null
var _burgle_b: BurglaryZone = null
var _counter: FenceCounter = null
var _stats: MockStats = null
var _wanted: MockWanted = null
var _player: StaticBody3D = null
var _frames: int = 0
var _last_proceeds: int = -1


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

	_fence = FenceController.new()
	_fence.seconds_per_day = 1.0
	root.add_child(_fence)

	_burgle_a = _make_burglary()
	_burgle_b = _make_burglary()

	_counter = FenceCounter.new()
	_counter.fenced.connect(_on_fenced)
	root.add_child(_counter)

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _make_burglary() -> BurglaryZone:
	var zone := BurglaryZone.new()
	zone.loot_category = "jewelry"
	zone.loot_value = LOOT_VALUE
	root.add_child(zone)
	return zone


func _on_fenced(proceeds: int) -> void:
	_last_proceeds = proceeds


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _fence == null or _burgle_a == null or _counter == null or _wanted == null:
		return _fail("mock tree did not assemble")
	_fence.set_process(false)  # drive the cool clock manually

	# Empty stash: fencing pays nothing (no signal, no cash).
	_counter.body_entered.emit(_player)
	if _last_proceeds != -1 or _stats.money != 0:
		return _fail("fencing an empty stash paid out")

	# Group gate: a non-player can't burgle.
	var bystander := StaticBody3D.new()
	root.add_child(bystander)
	_burgle_a.body_entered.emit(bystander)
	if _fence.inventory_count() != 0 or _wanted.crimes != 0:
		return _fail("a non-player burgled the place")

	# Break in: the loot enters the stash and the crime draws heat.
	_burgle_a.body_entered.emit(_player)
	if _fence.inventory_count() != 1 or _wanted.crimes != 1:
		return _fail(
			"burglary did not stash loot / draw heat (count %d)" % _fence.inventory_count()
		)

	return _run_fence_hot()


func _run_fence_hot() -> bool:
	# Fence it immediately while HOT: pays out, but discounted.
	_counter.body_entered.emit(_player)
	if _last_proceeds <= 0 or _stats.money != _last_proceeds or _fence.inventory_count() != 0:
		return _fail("hot fence did not pay out / clear the stash (proceeds %d)" % _last_proceeds)

	# One haul per break-in: re-entering the cleaned-out place lifts nothing more.
	_burgle_a.body_entered.emit(_player)
	if _fence.inventory_count() != 0 or _wanted.crimes != 1:
		return _fail("re-burgling a cleaned-out place stashed more loot / drew heat")

	return _run_cool_clean(_last_proceeds)


func _run_cool_clean(hot_proceeds: int) -> bool:
	# Steal an identical piece, then let it COOL for several days before fencing.
	_burgle_b.body_entered.emit(_player)
	if _fence.inventory_count() != 1:
		return _fail("second burglary did not stash loot")
	_fence._process(10.0)  # ~10 in-game days -> fully cooled

	var money_before := _stats.money
	_counter.body_entered.emit(_player)
	var clean_proceeds := _stats.money - money_before
	if clean_proceeds <= hot_proceeds:
		return _fail(
			"cooled goods did not fetch more than hot (%d vs %d)" % [clean_proceeds, hot_proceeds]
		)
	return _pass(hot_proceeds, clean_proceeds)


func _pass(hot_proceeds: int, clean_proceeds: int) -> bool:
	print(
		(
			"fence loop probe: OK (burgle -> heat + stash; hot fence $%d < cooled fence $%d)"
			% [hot_proceeds, clean_proceeds]
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("fence loop probe FAIL :: %s" % message)
	print("fence loop probe: FAIL — %s" % message)
	quit(1)
	return true
