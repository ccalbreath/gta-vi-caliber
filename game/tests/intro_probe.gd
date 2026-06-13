extends SceneTree
## Boot-intro probe: the branded intro must build, run its two-beat timeline on
## the clock, and reach its exit so the player is never stranded on it. Run:
##   godot --headless --path game --script res://tests/intro_probe.gd
##
## The intro's scene change is suppressed (test seam) so this verifies the whole
## sequence WITHOUT loading the menu scene — keeping the probe independent of any
## in-flight UI work. The intro is added in _initialize but only driven from the
## first _process frame: a node added in _initialize has its _ready deferred, so
## its @onready nodes aren't wired until a frame has passed. From that frame we
## take manual control of its clock (set_process(false) + explicit _process
## steps) so the run is deterministic rather than wall-clock dependent.

const SCENE_PATH: String = "res://scenes/ui/intro.tscn"
const STEP: float = 0.1

var _packed: PackedScene = null
var _intro: IntroSequence = null
var _done: bool = false


func _initialize() -> void:
	_packed = load(SCENE_PATH)
	if _packed == null:
		push_error("intro probe: scene failed to load: %s" % SCENE_PATH)
		quit(1)
		return
	_intro = _packed.instantiate()
	_intro.suppress_scene_change = true
	root.add_child(_intro)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	# _ready has now fired, so the intro's @onready nodes are wired. Take the
	# clock off the engine so only our explicit steps advance the timeline.
	_intro.set_process(false)
	_report(_run_checks())
	return true


func _run_checks() -> PackedStringArray:
	var failures: PackedStringArray = []

	# Structure: the beats (incl. the studio emblem), the cinematic bars, and the
	# black handoff overlay.
	for node_name in ["Card", "Emblem", "Title", "TopBar", "BottomBar", "Grain", "Fade"]:
		if _intro.find_child(node_name) == null:
			failures.append("missing node '%s'" % node_name)
	var card: Control = _intro.find_child("Card")
	var title: Control = _intro.find_child("Title")
	var wordmark: Label = _intro.find_child("Wordmark")
	if wordmark == null or wordmark.text.strip_edges().is_empty():
		failures.append("wordmark label missing or empty")
	if not failures.is_empty():
		return failures

	# Boot applied saved settings from frame one: the master bus already sits at
	# the loaded/default volume, so the player never hears a wrong-volume intro.
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		var saved_volume: float = SettingsPanel.load_settings()["volume"]
		var want_db := SettingsPanel.volume_to_db(saved_volume)
		var got_db := AudioServer.get_bus_volume_db(bus)
		if absf(got_db - want_db) > 0.5:
			failures.append(
				"boot did not apply audio settings (%.2f dB vs %.2f)" % [got_db, want_db]
			)

	# Beat 1 — the studio card peaks first while the title is still hidden.
	_advance(_intro, 1.0)
	if card.modulate.a < 0.9:
		failures.append("card not visible at its peak (a=%.2f)" % card.modulate.a)
	if title.modulate.a > 0.1:
		failures.append("title showing during the card beat (a=%.2f)" % title.modulate.a)

	# Beat 2 — by t~4s the card has gone and the wordmark is fully revealed.
	_advance(_intro, 3.0)
	if title.modulate.a < 0.9:
		failures.append("title not visible at its peak (a=%.2f)" % title.modulate.a)
	if card.modulate.a > 0.1:
		failures.append("card lingering into the title beat (a=%.2f)" % card.modulate.a)
	# Neon ignition has settled to steady by now, so the wordmark reads solid.
	if wordmark.modulate.a < 0.5:
		failures.append("wordmark not lit at the title peak (neon a=%.2f)" % wordmark.modulate.a)
	# Letterbox bars have slid in (only assertable when the viewport has height).
	var top_bar: Control = _intro.find_child("TopBar")
	if _intro.size.y > 0.0 and top_bar.offset_bottom <= 0.0:
		failures.append("letterbox did not slide in (top bar h=%.1f)" % top_bar.offset_bottom)

	# Exit — past the end of the timeline the intro must hand off, never hang.
	_advance(_intro, 3.0)
	if not _intro.is_finishing():
		failures.append("intro did not auto-finish past the timeline end")

	# Skip — a fresh intro must exit immediately on request.
	var skipped: IntroSequence = _packed.instantiate()
	skipped.suppress_scene_change = true
	root.add_child(skipped)
	skipped.skip()
	if not skipped.is_finishing():
		failures.append("skip() did not begin the exit")

	return failures


## Step the intro's own clock in fixed increments (deterministic, frame-free).
func _advance(intro: IntroSequence, seconds: float) -> void:
	var steps := int(round(seconds / STEP))
	for _i in range(steps):
		intro._process(STEP)


func _report(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("intro probe: OK")
		quit(0)
	else:
		for failure in failures:
			push_error("intro probe: %s" % failure)
		quit(1)
