class_name IntroVideo
extends Control
## Boot intro — plays the studio sting video full-screen, then hands off to the
## main menu. This is the game's entry scene (set as run/main_scene), replacing
## the engine boot splash and any prior procedural cinematic.
##
## Flow: the video plays edge-to-edge; when it finishes (or the player skips with
## any key/click/tap) we crossfade through black straight into MainMenu, which
## already fades UP from black for a seamless handoff. Boot-time display/audio
## settings are applied here since this is now the first scene to run.

## Scene loaded once the video finishes or is skipped.
const MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

## Seconds for the fade-to-black handoff into the menu.
const FADE_TIME: float = 0.5

var _handing_off: bool = false

@onready var _video: VideoStreamPlayer = $Video
@onready var _fade: ColorRect = $Fade


func _ready() -> void:
	# Boot-time: honour saved audio/display settings before anything else, exactly
	# as the menu does when it is the entry scene.
	SettingsPanel.apply(SettingsPanel.load_settings(), get_tree())

	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_video.finished.connect(_begin_handoff)
	# Headless/CI or a missing stream: skip straight to the menu rather than hang.
	if _video.stream == null or DisplayServer.get_name() == "headless":
		_begin_handoff()
		return
	_video.play()


func _input(event: InputEvent) -> void:
	if _handing_off:
		return
	if _is_skip_event(event):
		_begin_handoff()
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


func _begin_handoff() -> void:
	if _handing_off:
		return
	_handing_off = true
	if _video.is_playing():
		_video.stop()
	var tween := create_tween()
	tween.tween_property(_fade, "color", Color(0, 0, 0, 1), FADE_TIME)
	tween.tween_callback(_go_to_menu)


func _go_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
