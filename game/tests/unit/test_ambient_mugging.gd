extends RefCounted
## Unit tests for AmbientMugging (see tests/run_tests.gd for the runner contract).


func test_starts_active() -> bool:
	var m := AmbientMugging.new()
	m.start(10.0)
	return m.is_active() and m.outcome() == ""


func test_mugger_dead_saves() -> bool:
	var m := AmbientMugging.new()
	m.start(0.0)
	m.tick(1.0, true, false, false)
	return m.outcome() == "saved" and not m.is_active()


func test_mugger_fled_saves() -> bool:
	var m := AmbientMugging.new()
	m.start(0.0)
	m.tick(1.0, false, true, false)
	return m.outcome() == "saved"


func test_expires_after_duration() -> bool:
	var m := AmbientMugging.new()
	m.start(0.0)
	m.tick(AmbientMugging.DURATION, false, false, false)
	return m.outcome() == "expired" and not m.is_active()


func test_reward_only_on_save() -> bool:
	var saved := AmbientMugging.reward_for("saved")
	var expired := AmbientMugging.reward_for("expired")
	return saved == AmbientMugging.SAVED_REWARD and expired == 0
