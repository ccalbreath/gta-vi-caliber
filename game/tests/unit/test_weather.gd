extends RefCounted
## Unit tests for Weather — condition → rain/fog/wetness rules.


func test_clear_is_dry_and_rainless() -> bool:
	var w := Weather.new()
	return not w.is_raining() and w.rain_intensity() == 0.0


func test_storm_rains_hardest() -> bool:
	var w := Weather.new()
	w.set_condition(Weather.Condition.STORM)
	return w.is_raining() and w.rain_intensity() == 1.0


func test_fog_and_cloud_increase_with_severity() -> bool:
	var clear := Weather.new()
	var storm := Weather.new()
	storm.set_condition(Weather.Condition.STORM)
	return storm.fog_density() > clear.fog_density() and storm.cloud_cover() > clear.cloud_cover()


func test_rain_builds_wetness() -> bool:
	var w := Weather.new()
	w.set_condition(Weather.Condition.RAIN)
	for _i in 5:
		w.update(1.0)
	return w.is_wet() and w.wetness > 0.4


func test_wetness_clamps_at_one() -> bool:
	var w := Weather.new()
	w.set_condition(Weather.Condition.STORM)
	for _i in 100:
		w.update(1.0)
	return w.wetness == 1.0


func test_dry_conditions_dry_out() -> bool:
	var w := Weather.new()
	w.set_condition(Weather.Condition.RAIN)
	for _i in 5:
		w.update(1.0)
	w.set_condition(Weather.Condition.CLEAR)
	for _i in 20:
		w.update(1.0)
	return not w.is_wet()


func test_overcast_has_clouds_but_no_rain() -> bool:
	var w := Weather.new()
	w.set_condition(Weather.Condition.OVERCAST)
	return not w.is_raining() and w.cloud_cover() > 0.5
