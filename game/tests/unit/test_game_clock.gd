extends RefCounted
## Unit tests for GameClock — the day/night sun + sky math.


func test_sun_high_at_noon() -> bool:
	return absf(GameClock.sun_elevation_deg(12.0) - 90.0) < 0.001


func test_sun_below_horizon_at_midnight() -> bool:
	return GameClock.sun_elevation_deg(0.0) < -89.0


func test_sun_at_horizon_at_sunrise_and_sunset() -> bool:
	return (
		absf(GameClock.sun_elevation_deg(6.0)) < 0.001
		and absf(GameClock.sun_elevation_deg(18.0)) < 0.001
	)


func test_daytime_flag() -> bool:
	return GameClock.is_daytime(12.0) and not GameClock.is_daytime(0.0)


func test_no_light_at_night_full_at_noon() -> bool:
	return (
		GameClock.light_energy(2.0) == 0.0
		and GameClock.light_energy(0.0) == 0.0
		and GameClock.light_energy(12.0) > 1.0
	)


func test_horizon_is_dark_at_night_pale_at_noon() -> bool:
	var night := GameClock.horizon_color(0.0)
	var noon := GameClock.horizon_color(12.0)
	return night.v < 0.2 and noon.v > 0.6
