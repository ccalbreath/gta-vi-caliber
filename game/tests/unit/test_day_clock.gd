extends RefCounted
## Unit tests for DayClock — the compressed day/night clock citizens plan against.
## Wrapping past midnight and the phase boundaries are what must stay exact.


func test_init_wraps_start_hour() -> bool:
	var c := DayClock.new(26.0)
	return absf(c.hour - 2.0) < 0.001


func test_advance_scales_real_seconds_to_hours() -> bool:
	# 24-second day -> 1 real second = 1 game hour.
	var c := DayClock.new(0.0, 24.0)
	c.advance(3.0)
	return absf(c.hour - 3.0) < 0.001


func test_advance_wraps_past_midnight() -> bool:
	var c := DayClock.new(23.0, 24.0)
	c.advance(2.0)  # 23 + 2 = 25 -> 1
	return absf(c.hour - 1.0) < 0.001


func test_phase_boundaries() -> bool:
	return (
		DayClock.new(3.0).phase() == "night"
		and DayClock.new(9.0).phase() == "morning"
		and DayClock.new(15.0).phase() == "afternoon"
		and DayClock.new(20.0).phase() == "evening"
		and DayClock.new(23.0).phase() == "night"
	)


func test_clock_text_formats_hh_mm() -> bool:
	return DayClock.new(8.5).clock_text() == "08:30"


func test_day_length_clamped_positive() -> bool:
	var c := DayClock.new(0.0, -5.0)  # nonsense length must not divide-by-zero
	c.advance(1.0)
	return c.hour >= 0.0 and c.hour < 24.0
