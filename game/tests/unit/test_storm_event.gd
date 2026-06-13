extends RefCounted
## Unit tests for StormEvent (runner contract: test_* methods return true).
##
## Covers the calm start, trigger, the intensity bump peaking at landfall, phase
## boundaries, passing after the duration, the consequence scalars at peak,
## flood-by-elevation, power-outage only in the strong half, and a save round-trip.


func _at(progress: float) -> StormEvent:
	# A storm of duration 100 advanced to an exact progress for deterministic reads.
	var s := StormEvent.new(100.0)
	s.trigger()
	s.advance(progress * 100.0)
	return s


func test_starts_calm() -> bool:
	var s := StormEvent.new()
	return (
		not s.is_active() and s.phase() == "calm" and s.intensity() == 0.0 and not s.is_dangerous()
	)


func test_trigger_activates_watch() -> bool:
	var s := StormEvent.new()
	s.trigger()
	return s.is_active() and s.phase() == "watch"


func test_landfall_peaks() -> bool:
	var s := _at(0.5)
	return absf(s.intensity() - 1.0) < 0.0001 and s.phase() == "landfall" and s.is_dangerous()


func test_intensity_bump() -> bool:
	# Rising then falling around the landfall peak.
	var early := _at(0.25).intensity()
	var peak := _at(0.5).intensity()
	var late := _at(0.75).intensity()
	return early < peak and late < peak and early > 0.0 and late > 0.0


func test_phase_boundaries() -> bool:
	return (
		_at(0.1).phase() == "watch"
		and _at(0.3).phase() == "warning"
		and _at(0.5).phase() == "landfall"
		and _at(0.7).phase() == "aftermath"
		and _at(0.9).phase() == "clearing"
	)


func test_passes_after_duration() -> bool:
	var s := StormEvent.new(100.0)
	s.trigger()
	s.advance(150.0)  # past the end
	return (
		not s.is_active()
		and s.progress() == 1.0
		and s.phase() == "calm"
		and absf(s.intensity()) < 0.0001
	)  # sin(PI)^2 is ~1e-32, not exactly 0


func test_consequences_at_peak() -> bool:
	var s := _at(0.5)  # intensity 1.0
	return (
		absf(s.visibility() - 0.2) < 0.0001  # 1 - 0.8
		and absf(s.road_grip() - 0.5) < 0.0001  # 1 - 0.5
		and absf(s.power_outage_chance() - 1.0) < 0.0001
		and absf(s.evacuation_pressure() - 1.0) < 0.0001
		and absf(s.looting_opportunity() - 1.0) < 0.0001
	)


func test_flood_risk_by_elevation() -> bool:
	var s := _at(0.5)  # intensity 1.0
	return (
		absf(s.flood_risk(0.0) - 1.0) < 0.0001
		and s.flood_risk(5.0) == 0.0
		and absf(s.flood_risk(2.5) - 0.5) < 0.0001
	)


func test_power_outage_only_when_strong() -> bool:
	# At watch-level intensity (~0.1 progress) the grid holds; at peak it drops.
	return _at(0.1).power_outage_chance() == 0.0 and _at(0.5).power_outage_chance() == 1.0


func test_save_round_trip() -> bool:
	var a := StormEvent.new(120.0)
	a.trigger()
	a.advance(48.0)  # progress 0.4
	var b := StormEvent.new()
	b.from_dict(a.to_dict())
	return (
		absf(b.progress() - a.progress()) < 0.0001
		and b.is_active() == a.is_active()
		and b.phase() == a.phase()
	)
