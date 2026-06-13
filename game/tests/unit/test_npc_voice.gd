extends RefCounted
## Unit tests for NpcVoice (see tests/run_tests.gd: test_* methods return true to
## pass). Pure — no DisplayServer / scene access — so it runs headless.


func test_params_index_in_range() -> bool:
	var p := NpcVoice.params_for("doomsday", 4)
	var idx: int = p["voice_index"]
	return idx >= 0 and idx < 4


func test_params_handle_zero_voices() -> bool:
	# voice_count 0 must still yield a valid index, never a divide-by-zero.
	return int(NpcVoice.params_for("intern", 0)["voice_index"]) == 0


func test_params_deterministic() -> bool:
	var a := NpcVoice.params_for("yogi", 8)
	var b := NpcVoice.params_for("yogi", 8)
	return (
		a["voice_index"] == b["voice_index"] and a["pitch"] == b["pitch"] and a["rate"] == b["rate"]
	)


func test_distinct_archetypes_differ() -> bool:
	# Two characterful archetypes should not collapse to identical delivery.
	var a := NpcVoice.params_for("doomsday", 12)
	var b := NpcVoice.params_for("intern", 12)
	return a["voice_index"] != b["voice_index"] or a["pitch"] != b["pitch"]


func test_unknown_voice_gets_stable_character() -> bool:
	var a := NpcVoice.params_for("generic", 6)
	var b := NpcVoice.params_for("generic", 6)
	return a["voice_index"] == b["voice_index"] and a["pitch"] == b["pitch"]


func test_pitch_rate_clamped() -> bool:
	var p := NpcVoice.params_for("intern", 5)
	var pitch: float = p["pitch"]
	var rate: float = p["rate"]
	return (
		pitch >= NpcVoice.PITCH_MIN
		and pitch <= NpcVoice.PITCH_MAX
		and rate >= NpcVoice.RATE_MIN
		and rate <= NpcVoice.RATE_MAX
	)


func test_mime_is_muted() -> bool:
	return bool(NpcVoice.params_for("mime", 8)["mute"])


func test_non_mime_not_muted() -> bool:
	return not bool(NpcVoice.params_for("doomsday", 8)["mute"])


func test_speakable_passes_words() -> bool:
	return NpcVoice.speakable("Lovely day for it.") == "Lovely day for it."


func test_speakable_strips_stage_direction() -> bool:
	return NpcVoice.speakable("(gestures at an invisible wall, deeply moved)") == ""


func test_speakable_strips_ellipsis() -> bool:
	return NpcVoice.speakable("...") == ""


func test_speakable_drops_inline_parenthetical() -> bool:
	var said := NpcVoice.speakable("Enjoy the sunlight (I have seen things).")
	return said.contains("Enjoy the sunlight") and not said.contains("seen things")


func test_should_speak_allows_near_idle_channel() -> bool:
	return NpcVoice.should_speak(10.0, 28.0, 5.0, 1.5, false)


func test_should_speak_blocks_when_channel_busy() -> bool:
	return not NpcVoice.should_speak(10.0, 28.0, 5.0, 1.5, true)


func test_should_speak_blocks_when_far() -> bool:
	return not NpcVoice.should_speak(40.0, 28.0, 5.0, 1.5, false)


func test_should_speak_blocks_during_cooldown() -> bool:
	return not NpcVoice.should_speak(10.0, 28.0, 0.5, 1.5, false)
