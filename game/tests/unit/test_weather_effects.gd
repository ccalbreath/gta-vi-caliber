extends RefCounted
## Unit tests for WeatherEffects (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).


func test_grip_dry_is_neutral() -> bool:
	return is_equal_approx(WeatherEffects.grip_multiplier(0.0), 1.0)


func test_grip_soaked_is_low() -> bool:
	return is_equal_approx(WeatherEffects.grip_multiplier(1.0), 0.7)


func test_grip_monotonic_decreasing() -> bool:
	var dry := WeatherEffects.grip_multiplier(0.0)
	var mid := WeatherEffects.grip_multiplier(0.5)
	var wet := WeatherEffects.grip_multiplier(1.0)
	return dry > mid and mid > wet and is_equal_approx(mid, 0.85)


func test_grip_clamps_out_of_range() -> bool:
	return (
		is_equal_approx(WeatherEffects.grip_multiplier(-2.0), 1.0)
		and is_equal_approx(WeatherEffects.grip_multiplier(5.0), 0.7)
	)


func test_brake_dry_is_neutral() -> bool:
	return is_equal_approx(WeatherEffects.brake_distance_multiplier(0.0), 1.0)


func test_brake_longer_when_wet() -> bool:
	var dry := WeatherEffects.brake_distance_multiplier(0.0)
	var wet := WeatherEffects.brake_distance_multiplier(1.0)
	return wet > dry and is_equal_approx(wet, 1.6) and wet >= 1.0


func test_brake_monotonic_increasing() -> bool:
	return (
		WeatherEffects.brake_distance_multiplier(0.5)
		> WeatherEffects.brake_distance_multiplier(0.1)
	)


func test_visibility_full_at_fog_zero() -> bool:
	return is_equal_approx(WeatherEffects.visibility_range(100.0, 0.0), 100.0)


func test_visibility_reduced_at_fog_one() -> bool:
	# 100 * (1 - 1.0 * 0.6) = 40
	return is_equal_approx(WeatherEffects.visibility_range(100.0, 1.0), 40.0)


func test_visibility_floored() -> bool:
	# Even at full fog with a tiny base, never drops below the 5.0 floor.
	return is_equal_approx(WeatherEffects.visibility_range(6.0, 1.0), 5.0)


func test_visibility_floor_on_negative_base() -> bool:
	return is_equal_approx(WeatherEffects.visibility_range(-50.0, 0.0), 5.0)


func test_ai_sight_clear_is_neutral() -> bool:
	return is_equal_approx(WeatherEffects.ai_sight_multiplier(0.0, 0.0), 1.0)


func test_ai_sight_lower_in_weather() -> bool:
	var clear := WeatherEffects.ai_sight_multiplier(0.0, 0.0)
	var rainy := WeatherEffects.ai_sight_multiplier(0.5, 0.0)
	var foggy := WeatherEffects.ai_sight_multiplier(0.0, 0.5)
	# rain bite 0.25, fog bite 0.55 -> fog hurts sight more than rain
	return clear > rainy and rainy > foggy and is_equal_approx(foggy, 0.725)


func test_ai_sight_floored() -> bool:
	return is_equal_approx(WeatherEffects.ai_sight_multiplier(1.0, 1.0), 0.3)


func test_traffic_speed_dry_is_neutral() -> bool:
	return is_equal_approx(WeatherEffects.traffic_speed_multiplier(0.0), 1.0)


func test_traffic_speed_slower_wet() -> bool:
	var wet := WeatherEffects.traffic_speed_multiplier(1.0)
	return wet < 1.0 and is_equal_approx(wet, 0.75)


func test_hydroplane_zero_when_dry() -> bool:
	return is_equal_approx(WeatherEffects.hydroplane_risk(0.0, 100.0, 20.0), 0.0)


func test_hydroplane_zero_below_threshold() -> bool:
	return is_equal_approx(WeatherEffects.hydroplane_risk(1.0, 15.0, 20.0), 0.0)


func test_hydroplane_rises_with_wetness_and_speed() -> bool:
	# wet 1.0, speed 40, threshold 20 -> over 20, factor 1.0 -> risk 1.0
	var full := WeatherEffects.hydroplane_risk(1.0, 40.0, 20.0)
	# wet 0.5, speed 30, threshold 20 -> over 10, factor 0.5 -> 0.25
	var partial := WeatherEffects.hydroplane_risk(0.5, 30.0, 20.0)
	return is_equal_approx(full, 1.0) and is_equal_approx(partial, 0.25) and full > partial


func test_hydroplane_clamped() -> bool:
	var r := WeatherEffects.hydroplane_risk(5.0, 999.0, 20.0)
	return r >= 0.0 and r <= 1.0 and is_equal_approx(r, 1.0)


func test_headlights_true_in_fog() -> bool:
	return WeatherEffects.headlights_recommended(0.8, 0.0)


func test_headlights_true_at_night() -> bool:
	return WeatherEffects.headlights_recommended(0.0, 0.9)


func test_headlights_false_clear_day() -> bool:
	return not WeatherEffects.headlights_recommended(0.0, 0.0)
