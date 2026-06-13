extends RefCounted
## Unit tests for PlayerBounty (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).
##
## Covers placing bounties (clamp + multi-placer sum), tier + hunter scaling, threat
## level, the three resolutions (claim / pay / appease), laying-low decay, and the
## save round-trip.


func test_starts_clear() -> bool:
	var pb := PlayerBounty.new()
	return (
		pb.total_bounty() == 0
		and not pb.is_active()
		and pb.tier() == "none"
		and pb.hunter_count() == 0
	)


func test_place_bounty_raises_total() -> bool:
	var pb := PlayerBounty.new()
	var b := pb.place_bounty("vice_kings", 3000.0)
	return b == 3000.0 and pb.total_bounty() == 3000 and pb.is_active()


func test_place_bounty_ignores_nonpositive_and_empty() -> bool:
	var pb := PlayerBounty.new()
	return (
		pb.place_bounty("", 1000.0) == 0.0
		and pb.place_bounty("x", -5.0) == 0.0
		and pb.total_bounty() == 0
	)


func test_bounty_accumulates_then_clamps() -> bool:
	var pb := PlayerBounty.new()
	pb.place_bounty("vice_kings", 40000.0)
	pb.place_bounty("vice_kings", 20000.0)  # 60000 -> re-clamped to the per-placer cap
	return pb.bounty_from("vice_kings") == PlayerBounty.MAX_PER_PLACER


func test_multiple_placers_sum() -> bool:
	var pb := PlayerBounty.new()
	pb.place_bounty("vice_kings", 3000.0)
	pb.place_bounty("marina_cartel", 4000.0)
	return pb.total_bounty() == 7000 and pb.placers().size() == 2


func test_placers_sorted() -> bool:
	var pb := PlayerBounty.new()
	pb.place_bounty("zed", 100.0)
	pb.place_bounty("alpha", 100.0)
	return pb.placers() == ["alpha", "zed"]


func test_bounty_from_unknown_zero() -> bool:
	var pb := PlayerBounty.new()
	return pb.bounty_from("nope") == 0.0


func test_tier_at_exact_thresholds() -> bool:
	var wanted := PlayerBounty.new()
	wanted.place_bounty("a", 1.0)  # exactly WANTED_AT
	var hunted := PlayerBounty.new()
	hunted.place_bounty("a", 5000.0)  # exactly HUNTED_AT
	var marked := PlayerBounty.new()
	marked.place_bounty("a", 20000.0)  # exactly MARKED_AT
	var legendary := PlayerBounty.new()
	legendary.place_bounty("a", 40000.0)  # exactly LEGENDARY_AT
	return (
		wanted.tier() == "wanted"
		and hunted.tier() == "hunted"
		and marked.tier() == "marked"
		and legendary.tier() == "legendary"
	)


func test_hunter_count_scales_with_tier() -> bool:
	var legendary := PlayerBounty.new()
	legendary.place_bounty("a", 45000.0)
	var marked := PlayerBounty.new()
	marked.place_bounty("a", 25000.0)
	var hunted := PlayerBounty.new()
	hunted.place_bounty("a", 6000.0)
	var wanted := PlayerBounty.new()
	wanted.place_bounty("a", 2000.0)
	return (
		legendary.hunter_count() == PlayerBounty.MAX_HUNTERS
		and marked.hunter_count() == 3
		and hunted.hunter_count() == 2
		and wanted.hunter_count() == 1
		and PlayerBounty.new().hunter_count() == 0
	)


func test_threat_level_scales_and_clamps() -> bool:
	var pb := PlayerBounty.new()
	pb.place_bounty("a", 50000.0)
	pb.place_bounty("b", 50000.0)  # total 100000 > saturation -> clamp 1.0
	return is_equal_approx(pb.threat_level(), 1.0) and PlayerBounty.new().threat_level() == 0.0


func test_claim_returns_payout_and_clears() -> bool:
	var pb := PlayerBounty.new()
	pb.place_bounty("a", 3000.0)
	pb.place_bounty("b", 2000.0)
	var payout := pb.claim()
	return payout == 5000 and pb.total_bounty() == 0 and not pb.is_active()


func test_claim_empty_zero() -> bool:
	var pb := PlayerBounty.new()
	return pb.claim() == 0


func test_pay_clears_bounty() -> bool:
	var pb := PlayerBounty.new()
	pb.place_bounty("a", 4000.0)
	var r := pb.pay(10000)
	return (
		r["success"] and r["cost"] == 4000 and r["new_balance"] == 6000 and pb.total_bounty() == 0
	)


func test_pay_insufficient_fails() -> bool:
	var pb := PlayerBounty.new()
	pb.place_bounty("a", 4000.0)
	var r := pb.pay(3000)
	return (
		r["success"] == false
		and r["new_balance"] == 3000
		and "insufficient" in r["reason"]
		and pb.total_bounty() == 4000
	)


func test_pay_nothing_fails() -> bool:
	var pb := PlayerBounty.new()
	var r := pb.pay(1000)
	return r["success"] == false and r["new_balance"] == 1000


func test_pay_exact_balance_succeeds() -> bool:
	var pb := PlayerBounty.new()
	pb.place_bounty("a", 4000.0)
	var r := pb.pay(4000)  # balance == owed
	return r["success"] and r["new_balance"] == 0 and pb.total_bounty() == 0


func test_appease_unknown_placer_noop() -> bool:
	var pb := PlayerBounty.new()
	pb.place_bounty("vice_kings", 3000.0)
	var r := pb.appease("nope", 1000.0)
	return r == 0.0 and pb.total_bounty() == 3000


func test_appease_reduces_one_placer() -> bool:
	var pb := PlayerBounty.new()
	pb.place_bounty("vice_kings", 5000.0)
	pb.place_bounty("marina_cartel", 3000.0)
	var left := pb.appease("vice_kings", 2000.0)
	return left == 3000.0 and pb.total_bounty() == 6000


func test_appease_clears_placer_when_zero() -> bool:
	var pb := PlayerBounty.new()
	pb.place_bounty("vice_kings", 2000.0)
	var left := pb.appease("vice_kings", 5000.0)  # over -> dropped
	return left == 0.0 and pb.bounty_from("vice_kings") == 0.0 and pb.placers().size() == 0


func test_decay_fades_bounty() -> bool:
	var pb := PlayerBounty.new()
	pb.place_bounty("a", 3000.0)  # DECAY_PER_DAY 500
	pb.decay(2.0)  # -1000 -> 2000
	return pb.total_bounty() == 2000


func test_decay_drops_to_zero() -> bool:
	var pb := PlayerBounty.new()
	pb.place_bounty("a", 1000.0)
	pb.decay(10.0)  # huge -> dropped
	return pb.total_bounty() == 0 and pb.placers().size() == 0


func test_decay_nonpositive_noop() -> bool:
	var pb := PlayerBounty.new()
	pb.place_bounty("a", 3000.0)
	pb.decay(0.0)
	pb.decay(-2.0)
	return pb.total_bounty() == 3000


func test_serialize_restore_roundtrip() -> bool:
	var pb := PlayerBounty.new()
	pb.place_bounty("vice_kings", 3000.0)
	pb.place_bounty("marina_cartel", 7000.0)
	var fresh := PlayerBounty.new()
	fresh.restore(pb.serialize())
	return (
		fresh.total_bounty() == pb.total_bounty()
		and fresh.bounty_from("vice_kings") == 3000.0
		and fresh.tier() == pb.tier()
	)


func test_restore_drops_malformed() -> bool:
	var pb := PlayerBounty.new()
	pb.restore({"placed": {"vice_kings": 4000.0, "bad": "lots", "neg": -100.0, "huge": 99999.0}})
	return (
		pb.bounty_from("vice_kings") == 4000.0
		and pb.bounty_from("bad") == 0.0
		and pb.bounty_from("neg") == 0.0
		and pb.bounty_from("huge") == PlayerBounty.MAX_PER_PLACER
	)
