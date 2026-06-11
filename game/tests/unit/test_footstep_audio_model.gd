extends RefCounted
## Unit tests for FootstepAudioModel (see tests/run_tests.gd for the runner
## contract: test_* methods return true to pass).

const RATE: int = 22050


func test_params_known_surface() -> bool:
	return FootstepAudioModel.params_for("metal")["tone_hz"] == 2100.0


func test_params_unknown_falls_back_to_concrete() -> bool:
	var unknown := FootstepAudioModel.params_for("lava")
	return unknown == FootstepAudioModel.SURFACES["concrete"]


func test_step_frames_has_expected_length() -> bool:
	var frames := FootstepAudioModel.step_frames(RATE, "concrete", 1)
	return frames.size() == int(RATE * FootstepAudioModel.DURATION)


func test_step_frames_bounded() -> bool:
	var frames := FootstepAudioModel.step_frames(RATE, "metal", 7)
	for v in frames:
		if absf(v) > 1.0:
			return false
	return true


func test_step_frames_normalized_to_peak() -> bool:
	# Peak should reach ~0.9 (the normalisation target), proving a real signal.
	var frames := FootstepAudioModel.step_frames(RATE, "concrete", 3)
	var peak := 0.0
	for v in frames:
		peak = maxf(peak, absf(v))
	return absf(peak - 0.9) < 0.01


func test_step_frames_deterministic_for_seed() -> bool:
	var a := FootstepAudioModel.step_frames(RATE, "grass", 42)
	var b := FootstepAudioModel.step_frames(RATE, "grass", 42)
	return a == b


func test_surfaces_differ_in_timbre() -> bool:
	# Different surfaces should not produce identical waveforms at the same seed.
	var grass := FootstepAudioModel.step_frames(RATE, "grass", 5)
	var metal := FootstepAudioModel.step_frames(RATE, "metal", 5)
	return grass != metal


func test_wav16_packs_two_bytes_per_frame() -> bool:
	var frames := FootstepAudioModel.step_frames(RATE, "wood", 9)
	return FootstepAudioModel.frames_to_wav16(frames).size() == frames.size() * 2


func test_wav16_clamps_out_of_range() -> bool:
	var frames := PackedFloat32Array([2.0, -2.0])
	var bytes := FootstepAudioModel.frames_to_wav16(frames)
	return bytes.decode_s16(0) == 32767 and bytes.decode_s16(2) == -32767
