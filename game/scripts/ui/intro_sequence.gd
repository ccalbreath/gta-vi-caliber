class_name IntroSequence
extends Control
## Branded boot intro — replaces Godot's default engine splash with a short,
## skippable cinematic that establishes the game's own Vice City identity before
## the main menu.
##
## A two-beat timeline (studio-credit card, then an animated wordmark reveal)
## plays over the same procedural dusk skyline the menu uses, so the visual
## language is continuous from the very first frame. The intro is deliberately
## SELF-CONTAINED — it carries its own brand colours and builds its own gradient
## bar rather than leaning on the optional [UiPalette] helper — so it always
## boots on a clean checkout regardless of in-flight UI work.
##
## Timing is driven from an accumulator in [method _process] (not a Tween) so a
## headless probe can step the whole sequence deterministically.

## Scene loaded when the intro finishes or the player skips.
const MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

# --- Brand palette (local copy of the Vice City sunset, see ui_palette.gd) ----
const _BG_DEEP := Color(0.016, 0.020, 0.039)
const _MAGENTA := Color(0.913, 0.098, 0.490)
const _PINK := Color(1.000, 0.302, 0.620)
const _ORANGE := Color(0.992, 0.643, 0.204)
const _CYAN := Color(0.220, 0.870, 0.960)

# --- Timeline beats (seconds) -------------------------------------------------
const _CARD_IN := 0.8
const _CARD_HOLD := 1.4
const _CARD_OUT := 0.7
const _TITLE_IN := 1.0
const _TITLE_HOLD := 2.2
const _TITLE_OUT := 0.8
# Absolute timestamps derived from the beats above.
const _CARD_END := _CARD_IN + _CARD_HOLD + _CARD_OUT  # 2.9
const _TITLE_START := _CARD_END
const _TITLE_END := _TITLE_START + _TITLE_IN + _TITLE_HOLD + _TITLE_OUT  # 6.7

# --- Cinematic framing + neon ignition ----------------------------------------
## Fraction of screen height each letterbox bar grows to (filmic 2.x:1 frame).
const _LETTERBOX_FRAC := 0.085
## Seconds for the letterbox bars to slide fully in.
const _LETTERBOX_IN := 1.0
## Seconds the wordmark "ignites" (neon flicker) once the title beat begins.
const _NEON_IGNITE := 0.75

## Seconds for the fade-to-black handoff into the menu (and the fade-up on boot).
@export var fade_time: float = 0.6

## Test seam: when set, the final [method change_scene_to_file] is suppressed so
## a probe can run the whole timeline without loading the menu scene.
var suppress_scene_change: bool = false

var _time: float = 0.0
var _finishing: bool = false
var _fade_tween: Tween = null

@onready var _card: Control = $Card
@onready var _title: Control = $Title
@onready var _wordmark: Label = $Title/Center/VBox/Wordmark
@onready var _kicker: Label = $Title/Center/VBox/Kicker
@onready var _underline: TextureRect = $Title/Center/VBox/Underline
@onready var _skip_hint: Label = $SkipHint
@onready var _top_bar: ColorRect = $TopBar
@onready var _bottom_bar: ColorRect = $BottomBar
@onready var _fade: ColorRect = $Fade


func _ready() -> void:
	# Boot-time: honour saved audio/display settings from the very first frame.
	# The intro is the boot scene now, so without this the player would hear the
	# whole intro at the default volume until the menu loaded and re-applied them.
	SettingsPanel.apply(SettingsPanel.load_settings())

	_underline.texture = _sunset_bar()
	_card.modulate.a = 0.0
	_title.modulate.a = 0.0
	# Open on black, then fade up into the dusk skyline.
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", 0.0, 0.5)


func _process(delta: float) -> void:
	_time += delta

	# Beat alphas: the card credit, then the wordmark, cross-fade on the clock.
	_card.modulate.a = _beat_alpha(_time, 0.0, _CARD_IN, _CARD_HOLD, _CARD_OUT)
	var title_a := _beat_alpha(_time, _TITLE_START, _TITLE_IN, _TITLE_HOLD, _TITLE_OUT)
	_title.modulate.a = title_a

	# Cinematic letterbox slides in over the opening second and holds.
	var bar_h := _letterbox_h()
	_top_bar.offset_bottom = bar_h
	_bottom_bar.offset_top = -bar_h

	# Continuous neon life on the wordmark + cyan kicker shimmer. The wordmark
	# also "ignites" — flickering on like a neon tube — as the title beat begins.
	var warm := _PINK.lerp(_ORANGE, 0.5 + 0.5 * sin(_time * 0.7))
	var lit := warm.lerp(Color(1, 1, 1), 0.35 + 0.2 * sin(_time * 1.6))
	lit.a = _neon_flicker()
	_wordmark.modulate = lit
	_kicker.modulate = _CYAN.lerp(Color(1, 1, 1), 0.3 + 0.3 * sin(_time * 1.1))
	_skip_hint.modulate.a = 0.30 + 0.18 * sin(_time * 2.4)

	if not _finishing and _time >= _TITLE_END:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if _finishing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		skip()
	elif event is InputEventMouseButton and event.pressed:
		skip()
	elif event is InputEventJoypadButton and event.pressed:
		skip()


## Begin the fade-to-black handoff to the menu immediately. Public so input and
## the probe can trigger it; idempotent once the intro is already finishing.
func skip() -> void:
	_finish()


## True once the intro has begun its exit (used by the probe).
func is_finishing() -> bool:
	return _finishing


func _finish() -> void:
	if _finishing:
		return
	_finishing = true
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", 1.0, fade_time)
	_fade_tween.tween_callback(_go_to_menu)


func _go_to_menu() -> void:
	if suppress_scene_change:
		return
	get_tree().change_scene_to_file(MENU_SCENE)


## Standard symmetric in/hold/out envelope, returns 0..1 for the given clock.
func _beat_alpha(t: float, start: float, in_dur: float, hold: float, out_dur: float) -> float:
	var a := t - start
	if a <= 0.0:
		return 0.0
	if a < in_dur:
		return a / in_dur
	if a < in_dur + hold:
		return 1.0
	if a < in_dur + hold + out_dur:
		return 1.0 - (a - in_dur - hold) / out_dur
	return 0.0


## Letterbox bar height in pixels — slides 0→target over the opening second.
func _letterbox_h() -> float:
	var target := size.y * _LETTERBOX_FRAC
	return clampf((_time - 0.4) / _LETTERBOX_IN, 0.0, 1.0) * target


## Neon-tube ignition multiplier for the wordmark alpha: harsh, calming blinks
## over the first [constant _NEON_IGNITE] seconds of the title beat, then steady.
func _neon_flicker() -> float:
	var ign := _time - _TITLE_START
	if ign < 0.0 or ign >= _NEON_IGNITE:
		return 1.0
	var charge := ign / _NEON_IGNITE  # the tube "warming up", 0..1
	var blink := 0.5 + 0.5 * sin(ign * 47.0)
	var level := 1.0 if blink > (0.7 - charge * 0.6) else 0.22
	return lerpf(level, 1.0, charge)


## A horizontal magenta→pink→orange bar used as the wordmark underline.
func _sunset_bar() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([_MAGENTA, _PINK, _ORANGE])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 6
	tex.fill_from = Vector2.ZERO
	tex.fill_to = Vector2(1, 0)
	return tex
