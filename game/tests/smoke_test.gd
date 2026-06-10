extends SceneTree
## Headless boot test: the main scene must instantiate and contain a working
## player rig. Run via:
##   godot --headless --path game --script res://tests/smoke_test.gd
##
## This is the "main stays playable" gate — if this fails, a clone won't run.
## Checks run on the first process frame: during _initialize the root is not
## live yet, so nodes haven't registered their groups with the tree.

const MAIN_SCENE: String = "res://scenes/world/sandbox.tscn"

var _checked := false


func _initialize() -> void:
	var packed: PackedScene = load(MAIN_SCENE)
	if packed == null:
		push_error("smoke test: main scene failed to load: %s" % MAIN_SCENE)
		quit(1)
		return
	root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	if _checked:
		return true
	_checked = true

	var failures: PackedStringArray = []
	var players := get_nodes_in_group("player")
	if players.size() != 1:
		failures.append("expected exactly 1 node in group 'player', found %d" % players.size())
	elif players[0] is not CharacterBody3D:
		failures.append("player root is not a CharacterBody3D")
	elif (players[0] as Node).find_children("*", "Camera3D", true).is_empty():
		failures.append("player has no Camera3D")

	if get_nodes_in_group("world").is_empty():
		failures.append("no node in group 'world'")
	if get_nodes_in_group("spawn_points").is_empty():
		failures.append("no spawn points (Marker3D in group 'spawn_points')")

	if failures.is_empty():
		print("smoke test: OK")
		quit(0)
	else:
		for failure in failures:
			push_error("smoke test: %s" % failure)
		quit(1)
	return false
