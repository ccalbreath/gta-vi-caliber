extends SceneTree
## Runtime facade-detail probe for the main playable map.
##
## The unit tests prove the facade-panel generator can produce windows from a
## footprint. This boots the main map and verifies streamed districts actually
## attach the batched dark glass and lit window MultiMeshes.
## Run headless:
##   godot --headless --path game --script res://tests/miami_facade_probe.gd

const SCENE_PATH: String = "res://scenes/world/miami.tscn"
const MIN_WARMUP_FRAMES: int = 30
const MAX_WAIT_MSEC: int = 30_000
const MIN_FACADE_ROOTS: int = 1
const MIN_DARK_PANELS: int = 1000
const MIN_LIT_PANELS: int = 250

var _scene: Node = null
var _frames: int = 0
var _started_msec: int = 0
var _facade_roots: int = 0
var _dark_panels: int = 0
var _lit_panels: int = 0


func _initialize() -> void:
	Engine.max_fps = 120
	_started_msec = Time.get_ticks_msec()
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		push_error("miami facade probe: scene failed to load")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < MIN_WARMUP_FRAMES:
		return false
	_facade_roots = 0
	_dark_panels = 0
	_lit_panels = 0
	_scan(_scene)
	if (
		_facade_roots >= MIN_FACADE_ROOTS
		and _dark_panels >= MIN_DARK_PANELS
		and _lit_panels >= MIN_LIT_PANELS
	):
		return _finish()
	if Time.get_ticks_msec() - _started_msec >= MAX_WAIT_MSEC:
		return _finish()
	return false


func _scan(node: Node) -> void:
	if node.name == "FacadePanels":
		_facade_roots += 1
	if node is MultiMeshInstance3D and node.multimesh != null:
		if node.name == "DarkGlassPanels":
			_dark_panels += node.multimesh.instance_count
		elif node.name == "LitWindowPanels":
			_lit_panels += node.multimesh.instance_count
	for child in node.get_children():
		_scan(child)


func _finish() -> bool:
	var failures := PackedStringArray()
	if _facade_roots < MIN_FACADE_ROOTS:
		failures.append("expected at least %d FacadePanels roots" % MIN_FACADE_ROOTS)
	if _dark_panels < MIN_DARK_PANELS:
		failures.append(
			"expected at least %d dark facade panels, found %d" % [MIN_DARK_PANELS, _dark_panels]
		)
	if _lit_panels < MIN_LIT_PANELS:
		failures.append(
			"expected at least %d lit facade panels, found %d" % [MIN_LIT_PANELS, _lit_panels]
		)
	if failures.is_empty():
		print(
			(
				"miami facade probe: OK (%d roots, %d dark panels, %d lit panels)"
				% [_facade_roots, _dark_panels, _lit_panels]
			)
		)
		quit(0)
	else:
		for failure in failures:
			push_error("miami facade probe FAIL :: %s" % failure)
		print("miami facade probe: FAIL")
		quit(1)
	return true
