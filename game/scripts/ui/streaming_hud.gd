class_name StreamingHud
extends CanvasLayer
## Streaming debug overlay (M3): which districts are resident, frame budget,
## draw calls, VRAM. Reads the DistrictStreamer through its group so world
## scenes stay self-contained; renders blank when no streamer exists.

@export var update_interval: float = 0.5

var _accum := 0.0
var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(16.0, 64.0)
	_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.8))
	_label.add_theme_font_size_override("font_size", 13)
	add_child(_label)


func _process(delta: float) -> void:
	_accum += delta
	if _accum < update_interval:
		return
	_accum = 0.0
	var streamer := get_tree().get_first_node_in_group("district_streamer")
	if streamer == null:
		_label.text = ""
		return
	var frame_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_label.text = StreamingHudFormat.format_lines(
		streamer.resident_names(),
		streamer.district_count(),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		frame_ms,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	)
