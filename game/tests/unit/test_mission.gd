extends RefCounted
## Unit tests for Mission (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).


func test_starts_active() -> bool:
	var m := Mission.new("Rampage", "Take down targets", 5)
	return m.is_active() and m.progress == 0


func test_record_advances_progress() -> bool:
	var m := Mission.new("Rampage", "Take down targets", 5)
	m.record()
	m.record(2)
	return m.progress == 3 and m.is_active()


func test_completes_at_required() -> bool:
	var m := Mission.new("Rampage", "Take down targets", 3)
	m.record(3)
	return m.status == Mission.Status.COMPLETE and not m.is_active()


func test_progress_does_not_overflow() -> bool:
	var m := Mission.new("Rampage", "Take down targets", 3)
	m.record(10)
	return m.progress == 3


func test_no_progress_after_complete() -> bool:
	var m := Mission.new("Rampage", "Take down targets", 1)
	m.record()
	m.record()
	return m.progress == 1 and m.status == Mission.Status.COMPLETE


func test_timer_fails_when_elapsed() -> bool:
	var m := Mission.new("Rampage", "Take down targets", 5, 10.0)
	m.tick(11.0)
	return m.status == Mission.Status.FAILED


func test_timer_does_not_fail_early() -> bool:
	var m := Mission.new("Rampage", "Take down targets", 5, 10.0)
	m.tick(4.0)
	return m.is_active() and is_equal_approx(m.time_left, 6.0)


func test_untimed_never_fails() -> bool:
	var m := Mission.new("Rampage", "Take down targets", 5, 0.0)
	m.tick(9999.0)
	return m.is_active()


func test_no_record_after_failure() -> bool:
	var m := Mission.new("Rampage", "Take down targets", 5, 1.0)
	m.tick(2.0)
	m.record(3)
	return m.status == Mission.Status.FAILED and m.progress == 0


func test_fraction() -> bool:
	var m := Mission.new("Rampage", "Take down targets", 4)
	m.record(1)
	return is_equal_approx(m.fraction(), 0.25)


func test_reset_reactivates() -> bool:
	var m := Mission.new("Rampage", "Take down targets", 2, 5.0)
	m.record(2)
	m.reset()
	return m.is_active() and m.progress == 0 and is_equal_approx(m.time_left, 5.0)
