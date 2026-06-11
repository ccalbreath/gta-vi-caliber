class_name DebugHud
extends CanvasLayer
## Always-on development HUD: FPS plus control hints.
##
## UI observes and emits — it must never drive gameplay (docs/ARCHITECTURE.md).

const HINTS: String = (
	"WASD move · Shift sprint · Space jump/brake · E enter/exit car"
	+ " · C look behind · mouse look · Esc cursor"
)

var _native_status: String = ""

@onready var _label: Label = $InfoLabel


## Native modules are optional accelerators (docs/ARCHITECTURE.md): report
## once whether the GDExtension loaded so absence is visible, not silent.
func _ready() -> void:
	if ClassDB.class_exists("NativeBench"):
		var bench: Variant = ClassDB.instantiate("NativeBench")
		_native_status = "native: %s" % bench.ping()
	else:
		_native_status = "native: absent — GDScript fallbacks (engine/README.md)"


func _process(_delta: float) -> void:
	_label.text = "%d FPS\n%s\n%s" % [Engine.get_frames_per_second(), HINTS, _native_status]
