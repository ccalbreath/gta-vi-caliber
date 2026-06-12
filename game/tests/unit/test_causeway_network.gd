extends RefCounted
## Unit tests for CausewayNetwork — the bay crossings that stitch the mainland
## districts to the beach districts into one drivable landmass.


func test_three_named_causeways() -> bool:
	var names := PackedStringArray()
	for c in CausewayNetwork.causeways():
		names.append(c["name"])
	return (
		names.size() == 3
		and names.has("macarthur")
		and names.has("julia_tuttle")
		and names.has("venetian")
	)


func test_every_causeway_crosses_the_bay() -> bool:
	# Each deck must start on the mainland (x small) and finish at the beaches
	# (x large) — otherwise it does not actually connect the two clusters.
	for c in CausewayNetwork.causeways():
		var pts: PackedVector2Array = c["points"]
		if pts.size() < 2:
			return false
		if pts[0].x > 1200.0:
			return false
		if pts[pts.size() - 1].x < 4500.0:
			return false
	return true


func test_centerline_lookup() -> bool:
	var mac := CausewayNetwork.centerline("macarthur")
	var missing := CausewayNetwork.centerline("nope")
	return mac.size() >= 2 and missing.is_empty()


func test_total_length_is_substantial() -> bool:
	# Three ~4.5 km spans → well over 12 km of brand-new drivable bay road.
	return CausewayNetwork.total_length() > 12000.0


func test_length_of_straight_line() -> bool:
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(30, 40)])
	return absf(CausewayNetwork.length_of(pts) - 50.0) < 0.001


func test_deck_arch_peaks_at_centre() -> bool:
	var mid := CausewayNetwork.deck_height(0.5, 16.0)
	var start := CausewayNetwork.deck_height(0.0, 16.0)
	var end := CausewayNetwork.deck_height(1.0, 16.0)
	# Shores settle to the base height; the centre lifts for boat clearance.
	return (
		absf(start - CausewayNetwork.DECK_BASE_Y) < 0.001
		and absf(end - CausewayNetwork.DECK_BASE_Y) < 0.001
		and mid > start + 15.0
	)


func test_deck_arch_is_symmetric() -> bool:
	var a := CausewayNetwork.deck_height(0.25, 16.0)
	var b := CausewayNetwork.deck_height(0.75, 16.0)
	return absf(a - b) < 0.001


func test_sample_hits_endpoints() -> bool:
	var pts := CausewayNetwork.centerline("macarthur")
	var first := CausewayNetwork.sample(pts, 0.0)
	var last := CausewayNetwork.sample(pts, CausewayNetwork.length_of(pts) + 10.0)
	return first.is_equal_approx(pts[0]) and last.is_equal_approx(pts[pts.size() - 1])


func test_sample_midpoint_on_path() -> bool:
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(100, 0)])
	var mid := CausewayNetwork.sample(pts, 50.0)
	return mid.is_equal_approx(Vector2(50, 0))


func test_pillars_are_spaced_and_interior() -> bool:
	var pts := CausewayNetwork.centerline("macarthur")
	var spacing := 60.0
	var pillars := CausewayNetwork.pillar_points(pts, spacing)
	if pillars.size() < 10:
		return false
	# No pillar sits on a shore endpoint (those are on land).
	if pillars[0].is_equal_approx(pts[0]):
		return false
	# Consecutive pillars are ~spacing apart along the path.
	var step := pillars[0].distance_to(pillars[1])
	return step > spacing * 0.5 and step < spacing * 1.6
