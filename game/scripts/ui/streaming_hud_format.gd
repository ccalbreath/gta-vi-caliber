class_name StreamingHudFormat
extends RefCounted
## Pure text formatting for the streaming debug HUD (M3). Scene-free so the
## layout — the part that silently rots — stays unit-tested.


## One line per metric, residents sorted for a stable read.
static func format_lines(
	resident: Array, total: int, vram_mb: float, frame_ms: float, draw_calls: int
) -> String:
	var names := resident.duplicate()
	names.sort()
	var fps := 1000.0 / frame_ms if frame_ms > 0.0 else 0.0
	return (
		"\n"
		. join(
			PackedStringArray(
				[
					"districts %d/%d resident" % [names.size(), total],
					", ".join(PackedStringArray(names)) if not names.is_empty() else "(none)",
					"frame %.2f ms (%.0f FPS) · %d draw calls" % [frame_ms, fps, draw_calls],
					"VRAM %.0f MB" % vram_mb,
				]
			)
		)
	)
