extends SceneTree
## Property-hub probe: proves the playable property loop runs in miami — drive
## into the BuyZone to purchase, let it earn passive income, then drive into the
## CollectZone to bank the takings. Asserts money drops on purchase and rises
## again after collecting accrued income. Run headless:
##   godot --headless --path game --script res://tests/miami_property_probe.gd

const SCENE_PATH: String = "res://scenes/world/miami.tscn"
const WARMUP_FRAMES: int = 36
const DWELL_FRAMES: int = 14
const ACCRUE_FRAMES: int = 260
const BUY_POS := Vector3(-30, 1, 40)
const COLLECT_POS := Vector3(-30, 1, 56)
const ARMOR_POS := Vector3(-14, 1, 44)

var _scene: Node = null
var _player: Node3D = null
var _stats: Node = null
var _hub: Node = null
var _money_start: int = 0
var _money_after_buy: int = -1
var _money_pre_armor: int = 0
var _frames: int = 0
var _t: int = 0
var _phase: String = "warmup"


func _initialize() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		push_error("miami property probe: scene failed to load")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_frames += 1
	match _phase:
		"warmup":
			if _frames >= WARMUP_FRAMES:
				return _resolve()
		"buy":
			return _phase_buy()
		"accrue":
			_phase_accrue()
		"collect":
			return _phase_collect()
		"armor":
			return _phase_armor()
	return false


func _phase_buy() -> bool:
	_player.global_position = BUY_POS
	_t += 1
	if _hub.owns_property() and _money_after_buy < 0:
		_money_after_buy = int(_stats.money)
	if _t < DWELL_FRAMES:
		return false
	if _money_after_buy < 0:
		return _fail("entered BuyZone but the property was not purchased")
	if _money_after_buy >= _money_start:
		return _fail("property bought but money was not charged")
	_t = 0
	_phase = "accrue"
	return false


func _phase_accrue() -> void:
	_t += 1
	if _t >= ACCRUE_FRAMES:
		_t = 0
		_phase = "collect"


func _phase_collect() -> bool:
	_player.global_position = COLLECT_POS
	_t += 1
	if int(_stats.money) > _money_after_buy:
		_money_pre_armor = int(_stats.money)
		_t = 0
		_phase = "armor"
		return false
	if _t >= DWELL_FRAMES * 3:
		return _fail("entered CollectZone but no income was banked")
	return false


func _phase_armor() -> bool:
	_player.global_position = ARMOR_POS
	_t += 1
	if float(_stats.armor) > 0.0:
		if int(_stats.money) >= _money_pre_armor:
			return _fail("armor granted but not charged")
		return _pass()
	if _t >= DWELL_FRAMES * 3:
		return _fail("entered ArmorShop but no armor was bought")
	return false


func _resolve() -> bool:
	_player = get_first_node_in_group("player") as Node3D
	_stats = get_first_node_in_group("player_stats")
	_hub = get_first_node_in_group("property_hub")
	if _player == null:
		return _fail("no player rig")
	if _stats == null or not ("money" in _stats):
		return _fail("no PlayerStats")
	if _hub == null or not _hub.has_method("owns_property"):
		return _fail("no PropertyHub in group 'property_hub'")
	# Properties cost tens of thousands; front the player enough to buy one so the
	# probe exercises the purchase + income path (not the can't-afford branch).
	if _stats.has_method("add_money"):
		_stats.add_money(200000)
	_money_start = int(_stats.money)
	_phase = "buy"
	return false


func _pass() -> bool:
	var spent := _money_start - _money_after_buy
	print(
		(
			"miami property probe: OK (property $%d, income banked, armor bought to %d)"
			% [spent, int(_stats.armor)]
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("miami property probe FAIL :: %s" % message)
	print("miami property probe: FAIL — %s" % message)
	quit(1)
	return true
