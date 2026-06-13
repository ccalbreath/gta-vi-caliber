extends RefCounted
## Unit tests for SocialClout (runner contract: test_* methods return true).
##
## Covers the unknown start, init clamping, a flop vs a viral clip (reach math,
## follower gain, heat tip), fame amplifying reach, flashiness scaling, the heat
## cap, fame tiers, sponsorship income, recognizability, follower decay, and a
## save round-trip.


func test_starts_unknown() -> bool:
	var sc := SocialClout.new()
	return sc.followers() == 0 and sc.fame_tier() == "unknown"


func test_init_clamps_negative() -> bool:
	return SocialClout.new(-50).followers() == 0


func test_petty_act_flops() -> bool:
	var sc := SocialClout.new()
	var r := sc.record_act(2.0, 1, 1.0)  # reach 2*2*1*1 = 4 < 80
	return (
		r["viral"] == false
		and r["followers_gained"] == 0
		and r["heat_tip"] == 0
		and sc.followers() == 0
	)


func test_big_witnessed_act_goes_viral() -> bool:
	var sc := SocialClout.new()
	var r := sc.record_act(10.0, 9, 1.0)  # reach 10*10*1*1 = 100 >= 80
	var reach: float = r["reach"]
	return (
		r["viral"] == true
		and absf(reach - 100.0) < 0.0001
		and r["followers_gained"] == 300  # floor(100*3)
		and r["heat_tip"] == 2  # min(floor(100*0.02), 10)
		and sc.followers() == 300
	)


func test_existing_fame_amplifies_reach() -> bool:
	var famous := SocialClout.new(30000)  # amp = 1 + 30000/10000 = 4
	var nobody := SocialClout.new(0)  # amp = 1
	var r_famous := famous.record_act(5.0, 3, 1.0)  # 5*4*1*4 = 80 -> viral
	var r_nobody := nobody.record_act(5.0, 3, 1.0)  # 5*4*1*1 = 20 -> flop
	return r_famous["viral"] == true and r_nobody["viral"] == false


func test_flashiness_scales_reach() -> bool:
	var flashy := SocialClout.new()
	var dull := SocialClout.new()
	var r_flashy := flashy.record_act(10.0, 3, 2.0)  # 10*4*2 = 80 -> viral
	var r_dull := dull.record_act(10.0, 3, 0.5)  # 10*4*0.5 = 20 -> flop
	return r_flashy["viral"] == true and r_dull["viral"] == false


func test_heat_tip_capped() -> bool:
	var sc := SocialClout.new()
	var r := sc.record_act(100.0, 20, 2.0)  # reach 100*21*2 = 4200; heat floor(84) -> cap 10
	return r["heat_tip"] == 10


func test_fame_tiers() -> bool:
	return (
		SocialClout.new(0).fame_tier() == "unknown"
		and SocialClout.new(1000).fame_tier() == "local"
		and SocialClout.new(10000).fame_tier() == "trending"
		and SocialClout.new(100000).fame_tier() == "star"
		and SocialClout.new(1000000).fame_tier() == "icon"
	)


func test_sponsorship_income() -> bool:
	return (
		SocialClout.new(500).sponsorship_income() == 0
		and SocialClout.new(1000).sponsorship_income() == 10
		and SocialClout.new(25000).sponsorship_income() == 250
	)


func test_recognizability() -> bool:
	return (
		SocialClout.new(0).recognizability() == 0.0
		and absf(SocialClout.new(50000).recognizability() - 0.25) < 0.0001
		and SocialClout.new(200000).recognizability() == 1.0
		and SocialClout.new(400000).recognizability() == 1.0
	)


func test_decay_bleeds_followers() -> bool:
	var sc := SocialClout.new(10000)
	sc.decay(1.0)  # lose floor(10000*0.01) = 100
	var empty := SocialClout.new(0)
	empty.decay(5.0)
	return sc.followers() == 9900 and empty.followers() == 0


func test_save_round_trip() -> bool:
	var a := SocialClout.new()
	a.record_act(10.0, 9, 1.0)  # viral -> 300 followers
	var b := SocialClout.new()
	b.from_dict(a.to_dict())
	return b.followers() == a.followers() and b.fame_tier() == a.fame_tier()
