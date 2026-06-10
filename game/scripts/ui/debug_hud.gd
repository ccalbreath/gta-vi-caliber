class_name DebugHud
extends CanvasLayer
## Always-on development HUD: FPS plus control hints.
##
## UI observes and emits — it must never drive gameplay (docs/ARCHITECTURE.md).

const HINTS: String = "WASD move · Shift sprint · Space jump · mouse look · Esc cursor"

@onready var _label: Label = $InfoLabel


func _process(_delta: float) -> void:
	_label.text = "%d FPS\n%s" % [Engine.get_frames_per_second(), HINTS]
