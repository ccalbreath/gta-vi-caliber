extends RefCounted
## Unit tests for StreamingHudFormat — the streaming debug HUD's text layout.


func test_counts_and_names_sorted() -> bool:
	var text := StreamingHudFormat.format_lines(["venice", "downtown"], 18, 256.0, 8.33, 120)
	return text.contains("2/18 resident") and text.contains("downtown, venice")


func test_empty_residents_reads_none() -> bool:
	return StreamingHudFormat.format_lines([], 18, 0.0, 8.33, 0).contains("(none)")


func test_fps_derived_from_frame_ms() -> bool:
	return StreamingHudFormat.format_lines([], 1, 0.0, 10.0, 0).contains("(100 FPS)")


func test_zero_frame_ms_is_safe() -> bool:
	return StreamingHudFormat.format_lines([], 1, 0.0, 0.0, 0).contains("(0 FPS)")


func test_vram_line_present() -> bool:
	return StreamingHudFormat.format_lines([], 1, 512.4, 8.0, 1).contains("VRAM 512 MB")
