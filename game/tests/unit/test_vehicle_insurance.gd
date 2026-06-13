extends RefCounted
## Unit tests for VehicleInsurance (runner contract: test_* methods return true).
##
## Covers insuring (premium, dupes, bad value), cancel, destroy (insured vs not),
## claim (deductible, resets the car, claims counter), claiming when not eligible,
## and a save round-trip.


func test_insure_charges_premium() -> bool:
	var v := VehicleInsurance.new()
	var r := v.insure("infernus", 40000)  # premium 5% = 2000
	return (
		r["success"] == true
		and r["premium"] == 2000
		and v.is_insured("infernus")
		and v.coverage_value("infernus") == 40000
	)


func test_insure_rejects_dupes_and_bad_value() -> bool:
	var v := VehicleInsurance.new()
	v.insure("a", 10000)
	return (
		v.insure("a", 9999)["success"] == false  # already insured
		and v.insure("b", 0)["success"] == false  # non-positive value
		and v.coverage_count() == 1
	)


func test_cancel() -> bool:
	var v := VehicleInsurance.new()
	v.insure("a", 10000)
	return v.cancel("a") and not v.is_insured("a") and v.cancel("ghost") == false


func test_destroy_insured_vs_uninsured() -> bool:
	var v := VehicleInsurance.new()
	v.insure("a", 10000)
	var insured := v.destroy("a")
	var uninsured := v.destroy("b")
	return insured["claimable"] == true and v.is_destroyed("a") and uninsured["claimable"] == false


func test_claim_pays_deductible_and_resets() -> bool:
	var v := VehicleInsurance.new()
	v.insure("infernus", 40000)
	v.destroy("infernus")
	var c := v.claim("infernus")  # deductible 10% = 4000
	return (
		c["success"] == true
		and c["deductible"] == 4000
		and not v.is_destroyed("infernus")  # back in service
		and v.is_insured("infernus")
		and v.claims_filed() == 1
	)


func test_claim_requires_destroyed() -> bool:
	var v := VehicleInsurance.new()
	v.insure("a", 10000)  # insured but not destroyed
	var c := v.claim("a")
	var ghost := v.claim("nope")  # not even insured
	return c["success"] == false and ghost["success"] == false and v.claims_filed() == 0


func test_save_round_trip() -> bool:
	var a := VehicleInsurance.new()
	a.insure("a", 40000)
	a.insure("b", 20000)
	a.destroy("b")
	a.claim("b")  # 1 claim, b back in service
	a.destroy("a")  # a left destroyed
	var b := VehicleInsurance.new()
	b.from_dict(a.to_dict())
	return (
		b.coverage_count() == 2
		and b.is_destroyed("a")
		and not b.is_destroyed("b")
		and b.claims_filed() == 1
	)
