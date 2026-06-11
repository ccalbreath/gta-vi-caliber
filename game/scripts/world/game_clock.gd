class_name GameClock
extends RefCounted
## Pure time-of-day → sun + sky math for the day/night cycle. Hour is in [0, 24).
## Sun rises at 06:00, peaks at 12:00, sets at 18:00. Scene-free so it unit-tests
## headless (tests/unit/test_game_clock.gd); the DayNight node applies it.

const DAY_HOURS := 24.0


## Sun elevation in degrees: +90 at noon, 0 at sunrise/sunset, -90 at midnight.
static func sun_elevation_deg(hour: float) -> float:
	return 90.0 * sin((hour - 6.0) / 12.0 * PI)


## Sun azimuth in degrees, sweeping through the day.
static func sun_azimuth_deg(hour: float) -> float:
	return fmod(hour / DAY_HOURS * 360.0 + 90.0, 360.0)


static func is_daytime(hour: float) -> bool:
	return sun_elevation_deg(hour) > 0.0


## Directional-light energy: zero while the sun is below the horizon, ramping to
## full once it climbs ~30° — so dawn and dusk are soft, midday is bright.
static func light_energy(hour: float) -> float:
	var elevation := sun_elevation_deg(hour)
	if elevation <= 0.0:
		return 0.0
	return clampf(elevation / 30.0, 0.0, 1.0) * 1.2


## Horizon tint: dark blue at night, warm at dawn/dusk, pale blue at midday.
static func horizon_color(hour: float) -> Color:
	var elevation := sun_elevation_deg(hour)
	var night := Color(0.05, 0.06, 0.1)
	var dusk := Color(0.85, 0.45, 0.25)
	var day := Color(0.7, 0.72, 0.73)
	if elevation <= 0.0:
		return night
	if elevation < 12.0:
		return dusk.lerp(day, clampf(elevation / 12.0, 0.0, 1.0))
	return day
