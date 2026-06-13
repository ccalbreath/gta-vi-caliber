extends SceneTree
## Headless gate for the boot cinematic. Instances intro_sequence.tscn, lets the
## clock run (time-accelerated), and asserts the full chain works without input:
##   1. the expected layer nodes exist,
##   2. the hero title actually ignites (TitleMaster alpha > 0 at some point),
##   3. the cinematic auto-advances and hands off to the main menu scene.
## This guards against a scene/script edit silently breaking the entry flow.
## Run: godot --headless --path game --script res://tests/intro_probe.gd

const SCENE_PATH: String = "res://scenes/ui/intro_sequence.tscn"
const MENU_NODE_NAME: String = "MainMenu"
const REQUIRED_NODES: PackedStringArray = [
	"Backdrop", "BehindTitle", "TitleMaster", "Foreground", "Fade"
]
const MAX_FRAMES: int = 2000

var _intro: Node = null
var _frames: int = 0
var _max_title_alpha: float = 0.0
var _failed: bool = false


func _initialize() -> void:
	# Accelerate the ~9.2s timeline so the probe finishes fast, while keeping
	# enough per-frame granularity to observe the title igniting.
	Engine.time_scale = 4.0
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("could not load %s" % SCENE_PATH)
		return
	_intro = packed.instantiate()
	_intro.set("enable_audio", false)
	root.add_child(_intro)


func _process(_delta: float) -> bool:
	if _failed:
		return true
	_frames += 1

	if _frames == 1:
		for node_name in REQUIRED_NODES:
			if _intro.get_node_or_null(NodePath(node_name)) == null:
				_fail("intro is missing node '%s'" % node_name)
				return true

	if is_instance_valid(_intro):
		var title := _intro.get_node_or_null("TitleMaster") as CanvasItem
		if title != null:
			_max_title_alpha = maxf(_max_title_alpha, title.modulate.a)

	# The handoff swaps the SceneTree's current scene to the menu.
	if current_scene != null and current_scene.name == MENU_NODE_NAME:
		if _max_title_alpha <= 0.01:
			_fail("title never ignited before handoff (max alpha %.3f)" % _max_title_alpha)
			return true
		print(
			(
				"INTRO_PROBE PASS: title ignited (alpha %.2f), auto-advanced to %s in %d frames"
				% [_max_title_alpha, MENU_NODE_NAME, _frames]
			)
		)
		quit(0)
		return true

	if _frames >= MAX_FRAMES:
		_fail(
			(
				"intro did not auto-advance to %s within %d frames (max title alpha %.3f)"
				% [MENU_NODE_NAME, MAX_FRAMES, _max_title_alpha]
			)
		)
		return true
	return false


func _fail(message: String) -> void:
	_failed = true
	push_error("INTRO_PROBE FAIL: %s" % message)
	quit(1)
