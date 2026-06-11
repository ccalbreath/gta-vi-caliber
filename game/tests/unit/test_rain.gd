extends RefCounted
## Unit tests for Rain.drop_count — intensity scales and clamps the drop count.


func test_drop_count_scales_with_intensity() -> bool:
	return Rain.drop_count(0.5, 1000) == 500


func test_drop_count_clamps_above_one() -> bool:
	return Rain.drop_count(2.0, 1000) == 1000


func test_drop_count_clamps_below_zero() -> bool:
	return Rain.drop_count(-1.0, 1000) == 0


func test_dry_is_zero_drops() -> bool:
	return Rain.drop_count(0.0, 1400) == 0
