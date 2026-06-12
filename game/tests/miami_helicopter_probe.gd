extends SceneTree
## Air-support probe for the main playable map.
##
## Proves the police helicopter deploys end to end in miami.tscn: pushing the
## wanted level to 3+ stars makes the PoliceHelicopter activate, fly in, and
## settle into its orbit above the player. Guards the HelicopterPursuit wiring.
## Run headless:
##   godot --headless --path game --script res://tests/miami_helicopter_probe.gd

const SCENE_PATH: String = "res://scenes/world/miami.tscn"
const WARMUP_FRAMES: int = 40
const CRIME_COUNT: int = 8
## Allow the chopper to ease from its fly-in height down onto the orbit band.
const SETTLE_FRAMES: int = 600

var _scene: Node = null
var _frames: int = 0
var _staged: bool = false
var _heli: Node3D = null
var _player: Node3D = null


func _initialize() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		push_error("miami helicopter probe: scene failed to load")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	if not _staged:
		return _stage()
	# Succeed once the chopper is active and has reached its orbit band above the
	# player (roughly orbit_radius out, near altitude up).
	if _heli.is_active() and _on_station():
		print("miami helicopter probe: OK (3+ stars -> chopper on station)")
		quit(0)
		return true
	if _frames >= WARMUP_FRAMES + SETTLE_FRAMES:
		return _fail("chopper never reached station (active=%s)" % str(_heli.is_active()))
	return false


func _stage() -> bool:
	_player = get_first_node_in_group("player") as Node3D
	var tracker := get_first_node_in_group("wanted")
	_heli = get_first_node_in_group("police_air") as Node3D
	if _player == null or tracker == null or _heli == null:
		return _fail("missing player / wanted / police_air node")
	if not tracker.has_method("report_crime"):
		return _fail("tracker has no report_crime()")
	for _i in CRIME_COUNT:
		tracker.report_crime(true)
	_staged = true
	return false


func _on_station() -> bool:
	var here := _heli.global_position
	var center := _player.global_position
	var planar := Vector2(here.x - center.x, here.z - center.z).length()
	var up := here.y - center.y
	# Within a generous tolerance of the orbit radius/altitude band.
	return planar > 12.0 and planar < 48.0 and up > 18.0


func _fail(message: String) -> bool:
	push_error("miami helicopter probe FAIL :: %s" % message)
	print("miami helicopter probe: FAIL")
	quit(1)
	return true
