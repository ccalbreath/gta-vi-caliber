extends RefCounted
## Unit tests for StreetlightSwitch.lamp_energy (see tests/run_tests.gd contract).


func test_dark_in_full_day() -> bool:
	return StreetlightSwitch.lamp_energy(0.0, 2.5) == 0.0


func test_full_at_night() -> bool:
	return absf(StreetlightSwitch.lamp_energy(1.0, 2.5) - 2.5) < 0.0001


func test_ramps_at_dusk() -> bool:
	return absf(StreetlightSwitch.lamp_energy(0.5, 2.5) - 1.25) < 0.0001


func test_clamps_out_of_range() -> bool:
	return (
		StreetlightSwitch.lamp_energy(-0.3, 2.5) == 0.0
		and absf(StreetlightSwitch.lamp_energy(1.4, 2.5) - 2.5) < 0.0001
	)
