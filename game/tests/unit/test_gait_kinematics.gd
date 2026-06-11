extends RefCounted
## Unit tests for the articulated-gait flexion math added to Locomotion
## (knee/ankle/elbow). These feed the two-bone limbs, so the joint angles have
## to stay in anatomically sane ranges and peak in the right part of the cycle.

const HALF_PI: float = PI * 0.5
const THREE_HALF_PI: float = PI * 1.5


func test_knee_never_hyperextends() -> bool:
	# A knee only folds forward: flexion must stay >= 0 across the whole cycle.
	for i in 64:
		var phase: float = float(i) / 64.0 * TAU
		if Locomotion.knee_flex(phase, 1.2) < 0.0:
			return false
	return true


func test_knee_keeps_a_stance_bend() -> bool:
	# Mid-stance (phase = PI/2) the swing term is zero, leaving only stance_flex.
	return absf(Locomotion.knee_flex(HALF_PI, 1.2, 0.15) - 0.15) < 0.001


func test_knee_peaks_during_swing() -> bool:
	# The big bend lands in swing (~3*PI/2), not in stance (~PI/2).
	var swing := Locomotion.knee_flex(THREE_HALF_PI, 1.0)
	var stance := Locomotion.knee_flex(HALF_PI, 1.0)
	return swing > stance + 0.5


func test_knee_swing_peak_value() -> bool:
	# At the swing peak the bend is stance_flex + amplitude.
	return absf(Locomotion.knee_flex(THREE_HALF_PI, 1.0, 0.1) - 1.1) < 0.001


func test_ankle_pitch_is_bounded() -> bool:
	for i in 64:
		var phase: float = float(i) / 64.0 * TAU
		if absf(Locomotion.ankle_pitch(phase, 0.4)) > 0.4 + 0.001:
			return false
	return true


func test_ankle_pitch_zero_amplitude_is_flat() -> bool:
	return is_equal_approx(Locomotion.ankle_pitch(1.3, 0.0), 0.0)


func test_elbow_keeps_a_base_bend() -> bool:
	# Arms never straighten past the relaxed base bend.
	for i in 32:
		var phase: float = float(i) / 32.0 * TAU
		if Locomotion.elbow_flex(phase, 0.3, 0.35) < 0.35 - 0.001:
			return false
	return true


func test_elbow_deepens_on_forward_swing() -> bool:
	# Forward drive (sin > 0, peak at PI/2) bends more than the back swing.
	var fwd := Locomotion.elbow_flex(HALF_PI, 0.3, 0.35)
	var back := Locomotion.elbow_flex(THREE_HALF_PI, 0.3, 0.35)
	return fwd > back
