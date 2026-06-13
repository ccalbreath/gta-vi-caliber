class_name IntroSequence
extends Control
## "Sunset Sting" — the GTA-VI-style boot cinematic, the game's entry scene.
##
## A premium open-world game powers on: black, an original studio emblem writes
## itself in neon, a beat of dark, then the dusk bay blooms up as NEON BAY
## ignites with the signature pink->amber gradient and a single light-sweep
## rakes the letters, before the camera parks on PRESS ANY KEY and crossfades
## through black straight into the main menu.
##
## The whole sequence is driven by one accumulating clock (`_clock`): every
## animated value is a pure function of time, so it auto-advances unattended
## (attract-mode / CI capture), is trivially skippable (just move the clock or
## start the fade), and is deterministic frame-to-frame. The dusk sky is the
## real MenuBackdrop instanced directly, so the intro literally IS the menu's
## world; the fade-to-black handoff lands on MainMenu, which already fades UP
## from black, giving a seamless crossfade-through-black with no new menu wiring.
##
## The layer nodes (BehindTitle / TitleMaster / Foreground) are dumb renderers:
## they read the public animation state below in their _draw. Only this script
## owns the timeline. No gameplay logic lives here.

## Scene loaded once the cinematic (or a skip) reaches the handoff.
const MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

# --- Beat durations (seconds), in play order --------------------------------
const D_BLACK := 0.5
const D_STING := 1.6
const D_DARK := 0.5
const D_IGNITE := 3.2
const D_SWEEP := 1.2
const D_SETTLE := 1.6
const D_HANDOFF := 0.6

# --- Cumulative beat start times --------------------------------------------
const T_STING := D_BLACK
const T_DARK := T_STING + D_STING
const T_IGNITE := T_DARK + D_DARK
const T_SWEEP := T_IGNITE + D_IGNITE
const T_SETTLE := T_SWEEP + D_SWEEP
const T_HANDOFF := T_SETTLE + D_SETTLE
const T_END := T_HANDOFF + D_HANDOFF

# --- Copy -------------------------------------------------------------------
const TITLE_TEXT := "NEON BAY"
const TITLE_FONT_SIZE := 150
const TITLE_RISE := 0.06  # title centre lifted this fraction of height above middle
const SUBTITLE_TEXT := "an open world, built in the open"
const SUBTITLE_FONT_SIZE := 22
const PROMPT_TEXT := "PRESS ANY KEY"
const PROMPT_FONT_SIZE := 24
const STUDIO_TEXT := "HYPERCHO COLLECTIVE"
const STUDIO_FONT_SIZE := 26

# --- Palette (the project's dusk-neon identity) -----------------------------
const PINK := Color(1.0, 0.18, 0.62)
const CYAN := Color(0.2, 0.95, 1.0)
const VIOLET := Color(0.7, 0.3, 1.0)
const AMBER := Color(1.0, 0.6, 0.1)
const WARM_WHITE := Color(0.92, 0.88, 0.82)
const SWEEP_CORE := Color(1.0, 0.95, 0.85)

## Procedural-audio mixer rate.
const MIX_RATE := 22050.0

## Set false to ship a guaranteed-silent intro; audio is also auto-skipped when
## headless or when no playback stream is available, so this never gates boot.
@export var enable_audio: bool = true

# --- Public animation state (read by the layer scripts in their _draw) ------
var emblem_progress := 0.0  # 0..1 arc-length draw-on of the studio badge
var emblem_alpha := 0.0  # studio badge group alpha
var emblem_word_alpha := 0.0  # studio wordmark alpha
var emblem_split := 3.0  # px chromatic split on the emblem, converges to 0
var godray_alpha := 0.0  # 0..~0.18 god-ray wedge alpha
var godray_sway := 0.0  # radians, slow sway
var glow_alpha := 0.0  # title violet glow + chroma fringe alpha
var glow_breath := 0.0  # 0..1 slow breath on the glow
var chroma_offset := 5.0  # px diagonal chromatic fringe, relaxes 5->2
var sweep_pos := -0.2  # normalised light-sweep position across the title
var sweep_strength := 0.0  # 0..1 sweep visibility
var subtitle_alpha := 0.0
var prompt_alpha := 0.0
var prompt_pulse := 1.0  # multiplied into prompt alpha for the heartbeat
var vignette_amount := 0.0
var letterbox_amount := 0.0

var _clock := 0.0
var _fast_forward := false
var _handoff_active := false
var _handoff_t := 0.0
var _handoff_dur := D_HANDOFF
var _finished := false
var _font: Font

# Guarded procedural audio.
var _audio_ok := false
var _playback: AudioStreamGeneratorPlayback
var _phase_sub := 0.0
var _phase_root := 0.0
var _phase_fifth := 0.0
var _phase_shimmer := 0.0

@onready var _backdrop: Control = $Backdrop
@onready var _behind: Control = $BehindTitle
@onready var _title: Control = $TitleMaster
@onready var _foreground: Control = $Foreground
@onready var _fade: ColorRect = $Fade


func _ready() -> void:
	# Boot-time: honour saved audio/display settings before any gameplay, exactly
	# as the menu used to when it was the entry scene.
	SettingsPanel.apply(SettingsPanel.load_settings())

	_font = ThemeDB.fallback_font
	_backdrop.modulate.a = 0.0
	_title.modulate.a = 0.0
	_fade.color = Color(0, 0, 0, 0)
	_recentre_pivots()
	resized.connect(_recentre_pivots)

	if enable_audio:
		_setup_audio()


func _recentre_pivots() -> void:
	_backdrop.pivot_offset = _backdrop.size * 0.5
	_title.pivot_offset = _title.size * 0.5


func _process(delta: float) -> void:
	if _finished:
		return
	_clock += delta
	# A pre-ignite skip fast-forwards the clock (instead of teleporting it) so the
	# studio emblem rides its fade-out curve down smoothly rather than hard-cutting.
	if _fast_forward:
		_clock += delta * 7.0
		if _clock >= T_IGNITE:
			_clock = T_IGNITE
			_fast_forward = false
	_update_state()
	_apply_to_nodes()
	if _audio_ok:
		_fill_audio()

	if not _handoff_active and _clock >= T_HANDOFF:
		_begin_handoff(D_HANDOFF)
	if _handoff_active:
		_advance_handoff(delta)


# --- Timeline: every value is a pure function of the clock -------------------
func _update_state() -> void:
	var t := _clock

	# Beat 01 — studio sting.
	emblem_progress = _ease_out_cubic(_seg(T_STING, 0.55))
	var sting_in := _ease_out_sine(_seg(T_STING, 0.3))
	var sting_out := _ease_in_sine(_seg(T_DARK - 0.35, 0.35))
	emblem_alpha = sting_in * (1.0 - sting_out)
	emblem_word_alpha = emblem_alpha * _ease_out_sine(_seg(T_STING + 0.4, 0.45))
	emblem_split = lerp(3.0, 0.0, _ease_out_cubic(_seg(T_STING, 0.55)))

	# Beat 03 — world bloom + title ignite.
	glow_breath = 0.5 + 0.5 * sin(t * 1.4)
	glow_alpha = _ease_out_sine(_seg(T_IGNITE + 0.35, 0.4))
	chroma_offset = lerp(5.0, 2.0, _ease_out_sine(_seg(T_IGNITE, 0.6)))
	godray_alpha = _ease_in_out_sine(_seg(T_IGNITE, 0.6)) * 0.18
	godray_sway = deg_to_rad(2.0) * sin(t * 0.5)
	vignette_amount = _ease_out_sine(_seg(T_IGNITE, 0.5))
	letterbox_amount = _ease_out_sine(_seg(T_IGNITE, 0.5))

	# Beat 04 — single light-sweep across the title.
	sweep_pos = lerp(-0.18, 1.18, _ease_in_out_quart(_seg(T_SWEEP, 1.0)))
	sweep_strength = clampf(_seg(T_SWEEP, 0.12) - _seg(T_SWEEP + 0.95, 0.22), 0.0, 1.0)

	# Beat 05 — settle: subtitle + pulsing prompt.
	subtitle_alpha = _ease_out_sine(_seg(T_SETTLE, 0.45)) * 0.7
	prompt_alpha = _ease_out_sine(_seg(T_SETTLE, 0.45))
	prompt_pulse = 0.78 + 0.22 * sin(t * 3.0)


func _apply_to_nodes() -> void:
	# World bloom + slow sky dolly (push-in). Applied to the backdrop only so the
	# title's per-glyph gradient and the sweep stay in stable pixel space.
	_backdrop.modulate.a = _ease_out_sine(_seg(T_IGNITE, 0.5))
	var push := _ease_in_out_sine(_seg(T_IGNITE, (T_SETTLE + 0.5) - T_IGNITE))
	_backdrop.scale = Vector2.ONE * lerp(1.0, 1.05, push)
	_backdrop.pivot_offset = _backdrop.size * 0.5

	# Title fade-up + the ignite scale-punch (1.18 -> 1.0 with a touch of overshoot).
	_title.modulate.a = _ease_out_sine(_seg(T_IGNITE + 0.1, 0.4))
	_title.scale = Vector2.ONE * lerp(1.18, 1.0, _ease_out_back(_seg(T_IGNITE, 0.45)))
	_title.pivot_offset = _title.size * 0.5

	# The draw layers recompute from the state above.
	_behind.queue_redraw()
	_foreground.queue_redraw()


# --- Skip + handoff ----------------------------------------------------------
func _input(event: InputEvent) -> void:
	if _finished or _handoff_active:
		return
	if not _is_skip_event(event):
		return
	if _clock < T_IGNITE and not _fast_forward:
		# First press during the sting/darkness: rush smoothly to the title ignite.
		_fast_forward = true
	else:
		# Title already showing (or already rushing): bail to the menu.
		_begin_handoff(0.3)
	get_viewport().set_input_as_handled()


func _is_skip_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventJoypadButton:
		return event.pressed
	return false


func _begin_handoff(dur: float) -> void:
	if _handoff_active:
		return
	_handoff_active = true
	_handoff_t = 0.0
	_handoff_dur = maxf(dur, 0.01)


func _advance_handoff(delta: float) -> void:
	_handoff_t += delta
	var a := clampf(_handoff_t / _handoff_dur, 0.0, 1.0)
	_fade.color.a = _ease_in_sine(a)
	if a >= 1.0 and not _finished:
		_finished = true
		get_tree().change_scene_to_file(MENU_SCENE)


# --- Shared title layout (used by every title layer for pixel-perfect registr.)
func intro_font() -> Font:
	return _font


## Returns {pos, dims, center} for the hero title centred in a `ctrl_size` rect.
## `pos` is the left baseline draw_string expects.
func title_metrics(ctrl_size: Vector2) -> Dictionary:
	var dims := _font.get_string_size(TITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_FONT_SIZE)
	var center := ctrl_size * 0.5
	center.y -= ctrl_size.y * TITLE_RISE
	var pos := Vector2(
		center.x - dims.x * 0.5, center.y - dims.y * 0.5 + _font.get_ascent(TITLE_FONT_SIZE)
	)
	return {"pos": pos, "dims": dims, "center": center}


# --- Easing (pure) -----------------------------------------------------------
## Normalised 0..1 progress of the clock through `dur` seconds starting at `t0`.
func _seg(t0: float, dur: float) -> float:
	return clampf((_clock - t0) / maxf(dur, 0.0001), 0.0, 1.0)


static func _ease_out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


static func _ease_out_sine(x: float) -> float:
	return sin(clampf(x, 0.0, 1.0) * PI * 0.5)


static func _ease_in_sine(x: float) -> float:
	return 1.0 - cos(clampf(x, 0.0, 1.0) * PI * 0.5)


static func _ease_in_out_sine(x: float) -> float:
	return -(cos(PI * clampf(x, 0.0, 1.0)) - 1.0) * 0.5


static func _ease_in_out_quart(x: float) -> float:
	var t := clampf(x, 0.0, 1.0)
	if t < 0.5:
		return 8.0 * t * t * t * t
	return 1.0 - pow(-2.0 * t + 2.0, 4.0) * 0.5


static func _ease_out_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var t := clampf(x, 0.0, 1.0) - 1.0
	return 1.0 + c3 * pow(t, 3.0) + c1 * pow(t, 2.0)


# --- Guarded procedural audio ------------------------------------------------
## A warm low pad (root + fifth) over a sub-bass bed that powers on with the
## emblem, swells as the title ignites, sustains under the sweep, and fades on
## the handoff, plus a single bright shimmer timed to the sweep crossing centre.
## Fully optional: headless and stream-less runs stay silent and never touch a
## buffer. Respects the saved master volume (a muted bus simply hears nothing).
func _setup_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.2
	var player := AudioStreamPlayer.new()
	player.stream = gen
	add_child(player)
	player.play()
	var pb := player.get_stream_playback()
	if pb == null:
		return
	_playback = pb as AudioStreamGeneratorPlayback
	_audio_ok = _playback != null


func _fill_audio() -> void:
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	var step := 1.0 / MIX_RATE
	for i in frames:
		var t := _clock + float(i) * step
		var master := _audio_master_gain(t)
		var sub := sin(_phase_sub) * 0.32 * _audio_bed_gain(t)
		var pad := (sin(_phase_root) * 0.5 + sin(_phase_fifth) * 0.32) * 0.3 * _audio_pad_gain(t)
		var shimmer := sin(_phase_shimmer) * 0.18 * _audio_shimmer_gain(t)
		var s := clampf((sub + pad + shimmer) * master, -1.0, 1.0)
		_playback.push_frame(Vector2(s, s))
		_phase_sub += TAU * 55.0 * step
		_phase_root += TAU * 110.0 * step
		_phase_fifth += TAU * 165.0 * step
		_phase_shimmer += TAU * 1500.0 * step
	_phase_sub = fmod(_phase_sub, TAU)
	_phase_root = fmod(_phase_root, TAU)
	_phase_fifth = fmod(_phase_fifth, TAU)
	_phase_shimmer = fmod(_phase_shimmer, TAU)


func _audio_master_gain(_t: float) -> float:
	if not _handoff_active:
		return 1.0
	return clampf(1.0 - _handoff_t / _handoff_dur, 0.0, 1.0)


func _audio_bed_gain(t: float) -> float:
	return _ease_out_sine(clampf(t / (T_STING + 0.6), 0.0, 1.0))


func _audio_pad_gain(t: float) -> float:
	return _ease_out_sine(clampf((t - (T_DARK - 0.2)) / 1.2, 0.0, 1.0))


func _audio_shimmer_gain(t: float) -> float:
	var center := T_SWEEP + 0.5
	if t < center:
		return 0.0
	return exp(-(t - center) * 6.0)
