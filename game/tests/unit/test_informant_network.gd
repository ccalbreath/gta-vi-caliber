extends RefCounted
## Unit tests for InformantNetwork (see tests/run_tests.gd for the runner contract: test_*
## methods return true to pass).
##
## Covers the roster + malformed drops, retainers building trust (capped), a low-trust ask being
## a dud, a trusted ask paying tip_base*trust and spending the intel (trust drops below reliable
## again), unknown informants, ctor clamping, and the save round-trip. Default: trust 0.0001/$,
## reliable at 0.5, decay 0.3 — fixer's tip_base is 20000.


func test_default_roster_loaded() -> bool:
	var n := InformantNetwork.new()
	return n.informant_count() == 3 and n.has_informant("fixer") and n.trust_of("fixer") == 0.0


func test_malformed_dropped() -> bool:
	var n := (
		InformantNetwork
		. new(
			[
				{"id": "a", "tip_base": 1000},
				{"id": "", "tip_base": 1000},  # empty id
				{"id": "no_base"},  # missing tip_base
				{"id": "zero", "tip_base": 0},  # non-positive
				{"id": "a", "tip_base": 2000},  # duplicate
			]
		)
	)
	return n.informant_count() == 1 and n.has_informant("a")


func test_starts_untrusted() -> bool:
	var n := InformantNetwork.new()
	return n.trust_of("fixer") == 0.0 and not n.is_reliable("fixer")


func test_retainer_builds_trust() -> bool:
	var n := InformantNetwork.new()
	var t := n.pay_retainer("fixer", 2500)  # 2500 * 0.0001
	return is_equal_approx(t, 0.25) and is_equal_approx(n.trust_of("fixer"), 0.25)


func test_pay_retainer_zero_is_noop() -> bool:
	var n := InformantNetwork.new()
	n.from_dict({"trust": {"fixer": 0.4}})
	var t := n.pay_retainer("fixer", 0)  # non-positive -> no change
	return is_equal_approx(t, 0.4) and is_equal_approx(n.trust_of("fixer"), 0.4)


func test_exact_threshold_is_reliable() -> bool:
	var n := InformantNetwork.new()
	n.from_dict({"trust": {"fixer": 0.5}})  # exactly reliable_at (inclusive >=)
	var tip := n.request_tip("fixer")
	return bool(tip["reliable"]) and int(tip["value"]) == 10000  # round(20000 * 0.5)


func test_trust_caps_at_one() -> bool:
	var n := InformantNetwork.new()
	n.pay_retainer("fixer", 50000)  # far past full
	return is_equal_approx(n.trust_of("fixer"), 1.0)


func test_low_trust_tip_is_dud() -> bool:
	var n := InformantNetwork.new()
	n.from_dict({"trust": {"fixer": 0.3}})  # below reliable_at 0.5
	var tip := n.request_tip("fixer")
	return (
		not bool(tip["reliable"])
		and int(tip["value"]) == 0
		and is_equal_approx(n.trust_of("fixer"), 0.3)
	)


func test_trusted_tip_pays_and_decays() -> bool:
	var n := InformantNetwork.new()
	n.from_dict({"trust": {"fixer": 0.6}})
	var tip := n.request_tip("fixer")
	return (
		bool(tip["reliable"])
		and int(tip["value"]) == 12000  # 20000 * 0.6
		and is_equal_approx(n.trust_of("fixer"), 0.3)  # 0.6 - 0.3 decay
		and not n.is_reliable("fixer")
	)  # the tip spent their intel


func test_unknown_informant() -> bool:
	var n := InformantNetwork.new()
	return (
		not bool(n.request_tip("nobody")["reliable"])
		and is_equal_approx(n.pay_retainer("nobody", 5000), 0.0)
	)


func test_ctor_clamps() -> bool:
	var n := InformantNetwork.new([], -1.0, 2.0, -1.0)
	return n.trust_per_dollar == 0.0 and n.reliable_at <= 1.0 and n.tip_decay == 0.0


func test_save_round_trip() -> bool:
	var n := InformantNetwork.new()
	n.pay_retainer("fixer", 7000)
	n.pay_retainer("barfly", 3000)
	var clone := InformantNetwork.new()
	clone.from_dict(n.to_dict())
	return (
		is_equal_approx(clone.trust_of("fixer"), n.trust_of("fixer"))
		and is_equal_approx(clone.trust_of("barfly"), n.trust_of("barfly"))
	)
