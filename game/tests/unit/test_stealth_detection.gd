extends RefCounted
## Unit tests for StealthDetection (see tests/run_tests.gd: test_* methods return
## true to pass). Deterministic — fixed deltas, no randomness.


func test_starts_unaware_at_zero() -> bool:
	var d := StealthDetection.new(0.5, 0.25)
	return (
		is_equal_approx(d.awareness(), 0.0)
		and d.state() == StealthDetection.State.UNAWARE
		and not d.is_alerted()
		and not d.is_suspicious()
	)


func test_seeing_fills_awareness() -> bool:
	var d := StealthDetection.new(0.5, 0.25)
	d.update(true, 1.0, 1.0)
	return is_equal_approx(d.awareness(), 0.5)


func test_fill_scaled_by_visibility() -> bool:
	var d := StealthDetection.new(0.5, 0.25)
	d.update(true, 0.5, 1.0)
	return is_equal_approx(d.awareness(), 0.25)


func test_crossing_threshold_is_suspicious() -> bool:
	var d := StealthDetection.new(0.5, 0.25, 0.4)
	d.update(true, 1.0, 1.0)  # 0.5, above 0.4 threshold, below 1.0
	return d.state() == StealthDetection.State.SUSPICIOUS and d.is_suspicious()


func test_below_threshold_stays_unaware() -> bool:
	var d := StealthDetection.new(0.5, 0.25, 0.4)
	d.update(true, 1.0, 0.5)  # 0.25, below 0.4
	return d.state() == StealthDetection.State.UNAWARE


func test_reaching_one_alerts() -> bool:
	var d := StealthDetection.new(0.5, 0.25)
	d.update(true, 1.0, 2.0)  # fill 0.5/s * 2s = 1.0
	return (
		is_equal_approx(d.awareness(), 1.0)
		and d.is_alerted()
		and d.state() == StealthDetection.State.ALERTED
	)


func test_alerted_is_sticky_after_sight_lost() -> bool:
	var d := StealthDetection.new(0.5, 0.25)
	d.update(true, 1.0, 2.0)  # -> alerted
	d.update(false, 0.0, 10.0)  # lots of no-sight time
	return d.is_alerted() and is_equal_approx(d.awareness(), 1.0)


func test_alerted_not_suspicious() -> bool:
	var d := StealthDetection.new(0.5, 0.25)
	d.update(true, 1.0, 2.0)
	return d.is_alerted() and not d.is_suspicious()


func test_not_seen_decays_awareness() -> bool:
	var d := StealthDetection.new(0.5, 0.25)
	d.update(true, 1.0, 1.0)  # 0.5
	d.update(false, 0.0, 1.0)  # -0.25 -> 0.25
	return is_equal_approx(d.awareness(), 0.25)


func test_decays_back_to_unaware() -> bool:
	var d := StealthDetection.new(0.5, 0.25, 0.4)
	d.update(true, 1.0, 1.0)  # 0.5, suspicious
	d.update(false, 0.0, 10.0)  # decays to 0
	return is_equal_approx(d.awareness(), 0.0) and d.state() == StealthDetection.State.UNAWARE


func test_decay_floors_at_zero() -> bool:
	var d := StealthDetection.new(0.5, 0.25)
	d.update(true, 1.0, 0.5)  # 0.25
	d.update(false, 0.0, 100.0)  # would go negative
	return is_equal_approx(d.awareness(), 0.0)


func test_visibility_zero_does_not_fill() -> bool:
	var d := StealthDetection.new(0.5, 0.25)
	d.update(true, 0.0, 5.0)  # can see, but can't make out
	return is_equal_approx(d.awareness(), 0.0) and d.state() == StealthDetection.State.UNAWARE


func test_awareness_clamped_at_one() -> bool:
	var d := StealthDetection.new(0.5, 0.25)
	d.update(true, 1.0, 100.0)  # massively over 1.0
	return is_equal_approx(d.awareness(), 1.0)


func test_negative_delta_ignored() -> bool:
	var d := StealthDetection.new(0.5, 0.25)
	d.update(true, 1.0, 1.0)  # 0.5
	d.update(true, 1.0, -5.0)  # ignored
	d.update(false, 0.0, -5.0)  # ignored
	return is_equal_approx(d.awareness(), 0.5)


func test_detection_speed_falls_with_distance() -> bool:
	var d := StealthDetection.new(0.5, 0.25)
	var near := d.detection_speed(2.0, 10.0, false, false)
	var far := d.detection_speed(8.0, 10.0, false, false)
	return near > far and is_equal_approx(near, 0.8) and is_equal_approx(far, 0.2)


func test_detection_speed_out_of_range_zero() -> bool:
	var d := StealthDetection.new(0.5, 0.25)
	return (
		is_equal_approx(d.detection_speed(10.0, 10.0, false, false), 0.0)
		and is_equal_approx(d.detection_speed(15.0, 10.0, false, false), 0.0)
		and is_equal_approx(d.detection_speed(1.0, 0.0, false, false), 0.0)
	)


func test_detection_speed_crouch_lowers() -> bool:
	var d := StealthDetection.new(0.5, 0.25)
	var standing := d.detection_speed(2.0, 10.0, false, false)
	var crouched := d.detection_speed(2.0, 10.0, true, false)
	return crouched < standing and is_equal_approx(crouched, 0.8 * 0.45)


func test_detection_speed_moving_raises_and_clamps() -> bool:
	var d := StealthDetection.new(0.5, 0.25)
	var still := d.detection_speed(5.0, 10.0, false, false)
	var moving := d.detection_speed(5.0, 10.0, false, true)
	# still = 0.5, moving = 0.5 * 1.4 = 0.7 (in range, not clamped)
	var near_moving := d.detection_speed(1.0, 10.0, false, true)  # 0.9 * 1.4 = 1.26 -> 1.0
	return moving > still and is_equal_approx(moving, 0.7) and is_equal_approx(near_moving, 1.0)


func test_reset_clears_everything() -> bool:
	var d := StealthDetection.new(0.5, 0.25)
	d.update(true, 1.0, 2.0)  # alerted
	d.reset()
	return (
		is_equal_approx(d.awareness(), 0.0)
		and not d.is_alerted()
		and d.state() == StealthDetection.State.UNAWARE
	)
