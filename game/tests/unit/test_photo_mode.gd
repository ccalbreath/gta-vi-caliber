extends RefCounted
## Unit tests for PhotoMode (runner contract: test_* methods return true).
##
## Covers the composition score (great vs flop, weights, landmark bonus,
## clamping), album auto-curation (keep good, drop junk), best_quality, posting
## reach/likes scaling with quality + followers, lifetime likes, and save round-trip.

const GREAT := {"rarity": 1.0, "framing": 1.0, "lighting": 1.0, "action": 1.0, "landmark": true}
const FLOP := {"rarity": 0.0, "framing": 0.0, "lighting": 0.0, "action": 0.0}


func test_great_shot_maxes_quality() -> bool:
	return PhotoMode.new().quality(GREAT) == 100


func test_flop_scores_zero() -> bool:
	return PhotoMode.new().quality(FLOP) == 0


func test_weighted_midshot() -> bool:
	# All factors 0.5, no landmark -> base 0.5 -> 50.
	var pm := PhotoMode.new()
	return pm.quality({"rarity": 0.5, "framing": 0.5, "lighting": 0.5, "action": 0.5}) == 50


func test_landmark_bonus() -> bool:
	var shot := {"rarity": 0.8, "framing": 0.8, "lighting": 0.8, "action": 0.8}
	var pm := PhotoMode.new()
	var without := pm.quality(shot)  # base 0.8 -> 80
	shot["landmark"] = true
	var with_landmark := pm.quality(shot)  # 0.9 -> 90
	return without == 80 and with_landmark == 90


func test_quality_clamps_out_of_range_inputs() -> bool:
	# Over-range factors are clamped, so quality never exceeds 100.
	return (
		PhotoMode.new().quality(
			{"rarity": 5.0, "framing": 9.0, "lighting": 2.0, "action": 3.0, "landmark": true}
		)
		== 100
	)


func test_album_curates() -> bool:
	var pm := PhotoMode.new()
	var kept := pm.capture(GREAT)  # 100 -> kept
	var dropped := pm.capture(FLOP)  # 0 -> dropped
	return kept["kept"] == true and dropped["kept"] == false and pm.album_size() == 1


func test_best_quality() -> bool:
	var pm := PhotoMode.new()
	pm.capture({"rarity": 0.6, "framing": 0.6, "lighting": 0.6, "action": 0.6})  # 60
	pm.capture(GREAT)  # 100
	return pm.best_quality() == 100


func test_post_reach_and_likes() -> bool:
	var pm := PhotoMode.new()
	var r := pm.post(GREAT, 0)  # quality 100, amp 1 -> reach 100, likes 1000
	var reach: float = r["reach"]
	return r["quality"] == 100 and absf(reach - 100.0) < 0.0001 and r["likes"] == 1000


func test_followers_amplify_post() -> bool:
	var pm := PhotoMode.new()
	var r := pm.post(GREAT, 10000)  # amp 2 -> reach 200, likes 2000
	var reach: float = r["reach"]
	return absf(reach - 200.0) < 0.0001 and r["likes"] == 2000


func test_total_likes_accumulates() -> bool:
	var pm := PhotoMode.new()
	pm.post(GREAT, 0)  # 1000
	pm.post(GREAT, 0)  # +1000
	return pm.total_likes() == 2000


func test_save_round_trip() -> bool:
	var a := PhotoMode.new()
	a.capture(GREAT)
	a.capture({"rarity": 0.6, "framing": 0.6, "lighting": 0.6, "action": 0.6})  # 60
	a.post(GREAT, 5000)
	var b := PhotoMode.new()
	b.from_dict(a.to_dict())
	return (
		b.album_size() == a.album_size()
		and b.best_quality() == a.best_quality()
		and b.total_likes() == a.total_likes()
	)
