extends SceneTree
## Runtime probe for the STRENGTH -> burglary haul closure: a stronger crook carries more of
## the take out, so a maxed PlayerSkills.bonus("strength") scales the value lifted into the
## fence stash. Two identical break-ins: one untrained (base haul), one after training
## strength (a bigger haul), proving the gym's strength skill is consumed here. Run:
##   godot --headless --path game --script res://tests/burglary_strength_probe.gd

const WARMUP_FRAMES: int = 3
const LOOT: int = 1200

var _skills: PlayerSkillsController = null
var _fence: MockFence = null
var _wanted: MockWanted = null
var _zone_a: BurglaryZone = null
var _zone_b: BurglaryZone = null
var _player: StaticBody3D = null
var _frames: int = 0
var _burgled_count: int = 0
var _last_signal_value: int = -1


class MockFence:
	extends Node
	var hauls: Array = []
	var _counter: int = 0

	func _ready() -> void:
		add_to_group("fence")

	func add_loot(_category: String, value: int) -> String:
		hauls.append(value)
		_counter += 1
		return "loot_%d" % _counter


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
	_fence = MockFence.new()
	root.add_child(_fence)
	_wanted = MockWanted.new()
	root.add_child(_wanted)

	_zone_a = _make_zone()
	_zone_b = _make_zone()

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _make_zone() -> BurglaryZone:
	var zone := BurglaryZone.new()
	zone.loot_category = "jewelry"
	zone.loot_value = LOOT
	zone.burgled.connect(_on_burgled)
	root.add_child(zone)
	return zone


func _on_burgled(_category: String, value: int) -> void:
	_burgled_count += 1
	_last_signal_value = value


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _zone_a == null or _zone_b == null or _fence == null or _skills == null:
		return _fail("mock tree did not assemble")
	var err := _check_strength_hauls_more()
	if err != "":
		return _fail(err)
	return _pass()


func _check_strength_hauls_more() -> String:
	# Untrained burglar hauls the base take — into the fence AND on the burgled signal.
	_zone_a.body_entered.emit(_player)
	if _fence.hauls.size() != 1 or int(_fence.hauls[0]) != LOOT:
		return "an untrained burglary did not haul the base value (%s)" % str(_fence.hauls)
	if _wanted.crimes != 1 or _burgled_count != 1 or _last_signal_value != LOOT:
		return (
			"the base break-in did not draw heat / emit the base haul (crimes %d, signal %d)"
			% [_wanted.crimes, _last_signal_value]
		)
	# Train STRENGTH, then an identical place yields a bigger haul.
	_skills.train("strength", 100.0)
	var bonus := _skills.bonus("strength")
	_zone_b.body_entered.emit(_player)
	if _fence.hauls.size() != 2:
		return "the second burglary did not register"
	var strong_haul: int = int(_fence.hauls[1])
	if bonus <= 0.0 or strong_haul <= LOOT:
		return (
			"training strength did not increase the haul (bonus %f, haul %d)" % [bonus, strong_haul]
		)
	# The haul tracks the ACTUAL trained bonus (robust to the skill curve), and the burgled
	# signal must carry that same scaled haul — not the old unscaled loot_value.
	var expected := int(round(float(LOOT) * (1.0 + bonus * BurglaryZone.STRENGTH_HAUL_BONUS)))
	if strong_haul != expected or _last_signal_value != strong_haul:
		return (
			"the strong haul/signal mismatched the expected %d (haul %d, signal %d)"
			% [expected, strong_haul, _last_signal_value]
		)
	return ""


func _pass() -> bool:
	print(
		(
			(
				"burglary strength probe: OK (untrained haul $%d; a trained-strong crook carried "
				+ "more out of an identical place)"
			)
			% LOOT
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("burglary strength probe FAIL :: %s" % message)
	print("burglary strength probe: FAIL — %s" % message)
	quit(1)
	return true
