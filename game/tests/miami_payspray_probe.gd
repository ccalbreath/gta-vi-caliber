extends SceneTree
## Pay-n-spray probe: proves the in-world respray shop clears a wanted level.
##
## Commits crimes (stars rise), removes the officers so the shop entrance is
## unseen, then drives the player rig into the PaySprayShop zone and asserts the
## wanted level cleared AND the fee was deducted. Guards the PaySpray wiring.
## Run headless:
##   godot --headless --path game --script res://tests/miami_payspray_probe.gd

const SCENE_PATH: String = "res://scenes/world/miami.tscn"
const WARMUP_FRAMES: int = 40
const CRIME_COUNT: int = 6
const ENTER_FRAMES: int = 90
## The PaySprayShop transform in miami.tscn.
const SHOP_POS := Vector3(-46, 1, 28)

var _scene: Node = null
var _player: Node3D = null
var _tracker: Node = null
var _stats: Node = null
var _money_before: int = 0
var _frames: int = 0
var _entered_at: int = 0
var _phase: String = "warmup"


func _initialize() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		push_error("miami payspray probe: scene failed to load")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_frames += 1
	match _phase:
		"warmup":
			if _frames >= WARMUP_FRAMES:
				return _commit_and_clear_witnesses()
		"driving":
			_player.global_position = SHOP_POS
			if not _tracker.is_wanted():
				return _pass()
			if _frames >= _entered_at + ENTER_FRAMES:
				return _fail("entered the shop but the wanted level never cleared")
	return false


func _commit_and_clear_witnesses() -> bool:
	_player = get_first_node_in_group("player") as Node3D
	_tracker = get_first_node_in_group("wanted")
	_stats = get_first_node_in_group("player_stats")
	if _player == null or _tracker == null or not _tracker.has_method("report_crime"):
		return _fail("missing player or WantedTracker")
	if _stats == null or not ("money" in _stats):
		return _fail("missing PlayerStats")
	for _i in CRIME_COUNT:
		_tracker.report_crime(true)
	if not _tracker.is_wanted():
		return _fail("crimes did not raise a wanted level")
	# Clear sightlines so the respray isn't traced.
	var spawner := _scene.find_child("PoliceSpawner", true, false)
	if spawner != null:
		spawner.queue_free()
	for cop in get_nodes_in_group("police"):
		(cop as Node).queue_free()
	_money_before = int(_stats.money)
	_entered_at = _frames
	_phase = "driving"
	return false


func _pass() -> bool:
	var paid := _money_before - int(_stats.money)
	if paid <= 0:
		return _fail("wanted cleared but no fee was charged")
	print("miami payspray probe: OK (resprayed, lost the cops, paid $%d)" % paid)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("miami payspray probe FAIL :: %s" % message)
	print("miami payspray probe: FAIL — %s" % message)
	quit(1)
	return true
