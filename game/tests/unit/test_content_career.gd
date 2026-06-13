extends RefCounted
## Unit tests for ContentCareer (runner contract: test_* methods return true).
##
## Exercises the photo → follower flywheel: a banger grows the following, a bigger
## following amplifies the next post's reach (and thus its follower gain), a flop
## grows nothing, the two models are owned, and a save round-trip.

const GREAT := {"rarity": 1.0, "framing": 1.0, "lighting": 1.0, "action": 1.0, "landmark": true}
const FLOP := {"rarity": 0.0, "framing": 0.0, "lighting": 0.0, "action": 0.0}


func test_packages_photo_and_clout() -> bool:
	var c := ContentCareer.new()
	return c.photos() is PhotoMode and c.clout() is SocialClout and c.followers() == 0


func test_banger_grows_following() -> bool:
	var c := ContentCareer.new()
	var r := c.post(GREAT)  # quality 100, 0 followers -> reach 100 -> 100*5 = 500 followers
	var reach: float = r["reach"]
	return (
		r["quality"] == 100
		and absf(reach - 100.0) < 0.0001
		and r["followers_gained"] == 500
		and r["followers"] == 500
		and c.followers() == 500
	)


func test_following_amplifies_next_post() -> bool:
	var c := ContentCareer.new()
	c.post(GREAT)  # -> 500 followers
	var r := c.post(GREAT)  # amp 1.05 -> reach 105 -> floor(105*5)=525 -> 1025 total
	var reach: float = r["reach"]
	return absf(reach - 105.0) < 0.0001 and r["followers_gained"] == 525 and c.followers() == 1025


func test_flop_grows_nothing() -> bool:
	var c := ContentCareer.new()
	var r := c.post(FLOP)
	return r["followers_gained"] == 0 and c.followers() == 0


func test_save_round_trip() -> bool:
	var a := ContentCareer.new()
	a.post(GREAT)
	a.photos().capture(GREAT)
	var b := ContentCareer.new()
	b.from_dict(a.to_dict())
	return b.followers() == a.followers() and b.photos().album_size() == a.photos().album_size()
