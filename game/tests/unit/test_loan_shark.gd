extends RefCounted
## Unit tests for LoanShark (see tests/run_tests.gd for the runner contract: test_* methods
## return true to pass).
##
## Covers the clean start, borrowing + the credit limit, compounding interest, repayment
## (partial / capped / clearing), arrears after the grace window, default once the debt
## balloons, ctor clamping, and the save round-trip.


func test_starts_clean() -> bool:
	var ls := LoanShark.new()
	return (
		ls.owed() == 0
		and not ls.has_debt()
		and not ls.is_in_arrears()
		and not ls.is_defaulted()
		and ls.available_credit() == ls.credit_limit
	)


func test_borrow_increases_debt() -> bool:
	var ls := LoanShark.new()
	var r := ls.borrow(5000)
	return (
		bool(r["success"])
		and int(r["disbursed"]) == 5000
		and ls.owed() == 5000
		and ls.principal() == 5000
		and ls.has_debt()
	)


func test_borrow_rejects_nonpositive() -> bool:
	var ls := LoanShark.new()
	return (
		not bool(ls.borrow(0)["success"])
		and not bool(ls.borrow(-100)["success"])
		and ls.owed() == 0
	)


func test_borrow_respects_credit_limit() -> bool:
	var ls := LoanShark.new(0.05, 3.0, 10000, 3.0)
	var ok := bool(ls.borrow(8000)["success"])
	var over := ls.borrow(5000)  # 8000 + 5000 > 10000 -> fail
	var fill := bool(ls.borrow(2000)["success"])  # exactly 10000
	return ok and not bool(over["success"]) and fill and ls.available_credit() == 0


func test_accrue_compounds_monotonically() -> bool:
	var ls := LoanShark.new()
	ls.borrow(1000)
	var a := ls.owed()
	ls.accrue(5.0)
	var b := ls.owed()
	ls.accrue(5.0)
	var c := ls.owed()
	return a == 1000 and b > a and c > b


func test_accrue_noop_without_debt() -> bool:
	var ls := LoanShark.new()
	ls.accrue(10.0)
	return ls.owed() == 0


func test_repay_reduces_debt() -> bool:
	var ls := LoanShark.new()
	ls.borrow(5000)
	var r := ls.repay(2000)
	return (
		bool(r["success"])
		and int(r["paid"]) == 2000
		and not bool(r["cleared"])
		and ls.owed() == 3000
	)


func test_repay_clears_and_wipes_principal() -> bool:
	var ls := LoanShark.new()
	ls.borrow(5000)
	var r := ls.repay(5000)
	return bool(r["cleared"]) and ls.owed() == 0 and ls.principal() == 0 and not ls.has_debt()


func test_repay_caps_at_owed() -> bool:
	var ls := LoanShark.new()
	ls.borrow(1000)
	var r := ls.repay(5000)
	return int(r["paid"]) == 1000 and bool(r["cleared"]) and ls.owed() == 0


func test_repay_rejects_nonpositive_and_no_debt() -> bool:
	var ls := LoanShark.new()
	var no_debt := ls.repay(100)
	ls.borrow(1000)
	var nonpos := ls.repay(0)
	return not bool(no_debt["success"]) and not bool(nonpos["success"]) and ls.owed() == 1000


func test_arrears_after_grace_resets_on_payment() -> bool:
	var ls := LoanShark.new(0.05, 3.0, 100000, 3.0)
	ls.borrow(1000)
	ls.accrue(2.0)
	var before := ls.is_in_arrears()  # 2 days <= 3 grace
	ls.accrue(2.0)
	var after := ls.is_in_arrears()  # 4 days > 3 grace
	ls.repay(100)
	var cleared := ls.is_in_arrears()  # a payment resets the clock
	return not before and after and not cleared


func test_default_after_balloon() -> bool:
	var ls := LoanShark.new(0.05, 3.0, 100000, 2.0)
	ls.borrow(1000)
	ls.accrue(14.0)
	var safe := ls.is_defaulted()  # ~1980 < 2000
	ls.accrue(1.0)
	var blown := ls.is_defaulted()  # ~2079 >= 2000
	return not safe and blown


func test_ctor_clamps() -> bool:
	var ls := LoanShark.new(-1.0, -5.0, -100, 0.5)
	return (
		ls.daily_rate == LoanShark.MIN_RATE
		and ls.grace_days == 0.0
		and ls.credit_limit == 0
		and ls.default_multiple == 1.0
	)


func test_save_round_trip() -> bool:
	var ls := LoanShark.new()
	ls.borrow(8000)
	ls.accrue(6.0)
	ls.repay(1000)
	var clone := LoanShark.new()
	clone.from_dict(ls.to_dict())
	return clone.owed() == ls.owed() and clone.principal() == ls.principal()


func test_from_dict_rejects_non_dict() -> bool:
	var ls := LoanShark.new()
	ls.borrow(2000)
	ls.from_dict("not a dict")
	return ls.owed() == 2000
