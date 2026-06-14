extends SceneTree
## Scene-free probe for the live WardrobeShop -> DisguiseTracker link.
##
## The wardrobe already buys and wears clothes. This proves the worn look now
## reaches the player's live Disguise model, lowering recognition after police
## have logged the starter outfit.
## Run headless:
##   godot --headless --path game --script res://tests/wardrobe_disguise_probe.gd

const SETTLE_FRAMES: int = 3
const DISGUISE_TRACKER_SCRIPT := preload("res://scripts/systems/disguise_tracker.gd")

var _stats: PlayerStats = null
var _tracker: Node = null
var _shop: WardrobeShop = null
var _player: Node3D = null
var _frames: int = 0
var _updated: bool = false


func _initialize() -> void:
	_stats = PlayerStats.new()
	_stats.starting_money = 5000
	root.add_child(_stats)
	_tracker = DISGUISE_TRACKER_SCRIPT.new()
	root.add_child(_tracker)
	_player = Node3D.new()
	root.add_child(_player)
	_shop = WardrobeShop.new()
	root.add_child(_shop)
	_shop.disguise_updated.connect(func(_looks: Dictionary) -> void: _updated = true)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return false
	return _run()


func _run() -> bool:
	if _tracker.current("outfit") != "casual" or _tracker.current("hair") != "buzz":
		return _fail("starter wardrobe looks did not reach DisguiseTracker")
	_tracker.log_sighting()
	var before: float = _tracker.recognition()
	_shop.interact(_player)
	if not _updated:
		return _fail("WardrobeShop did not emit disguise_updated")
	if _stats.money != 3500:
		return _fail("wallet was not charged for sharp_suit (money=%d)" % _stats.money)
	if _tracker.current("outfit") != "suit":
		return _fail("sharp_suit did not update disguise outfit")
	if not is_equal_approx(before, 1.0) or _tracker.recognition() >= before:
		return _fail("recognition did not drop after outfit change")
	return _pass(before, _tracker.recognition())


func _pass(before: float, after: float) -> bool:
	print("wardrobe disguise probe: OK (recognition %.2f -> %.2f)" % [before, after])
	quit(0)
	return true


func _fail(reason: String) -> bool:
	push_error("wardrobe disguise probe FAIL: %s" % reason)
	quit(1)
	return true
