class_name LoanShark
extends RefCounted
## Pure loan-shark debt ledger — the LIABILITY side of the economy, the mirror of every
## earning system: you BORROW quick cash you don't have, and the debt COMPOUNDS daily at a
## brutal rate. Miss payments past a grace window and you're in ARREARS; let the balance
## balloon past a multiple of what you borrowed and you DEFAULT — the shark sends his muscle.
##
## No nodes, no wallet coupling: borrow() reports the cash to hand the player, repay() the
## cash to take, and the caller applies both against PlayerStats (like PropertyOwnership.buy).
## accrue() compounds the interest on an in-game-day tick fed by a controller. Deterministic,
## unit-tested headless (tests/unit/test_loan_shark.gd).

const MIN_RATE: float = 0.0
## Capped well below 1.0 so even a misconfigured rate can't compound the balance to a float
## infinity over a long session (the game default is a mere 5%/day).
const MAX_RATE: float = 0.5
const DEFAULT_DAILY_RATE: float = 0.05  # 5%/day — sharks are brutal
const DEFAULT_GRACE_DAYS: float = 3.0
const DEFAULT_CREDIT_LIMIT: int = 100000
## Debt at/above principal * this multiple = defaulted (the enforcers come).
const DEFAULT_DEFAULT_MULTIPLE: float = 3.0

var daily_rate: float
var grace_days: float
var credit_limit: int
var default_multiple: float

## Lifetime principal of the CURRENT debt episode (resets to 0 when cleared).
var _principal: int = 0
## Current amount owed (grows with interest); the source of truth.
var _balance: float = 0.0
## In-game days since the last payment (drives arrears).
var _days_unpaid: float = 0.0


func _init(
	rate: float = DEFAULT_DAILY_RATE,
	grace: float = DEFAULT_GRACE_DAYS,
	limit: int = DEFAULT_CREDIT_LIMIT,
	multiple: float = DEFAULT_DEFAULT_MULTIPLE
) -> void:
	daily_rate = clampf(rate, MIN_RATE, MAX_RATE)
	grace_days = maxf(grace, 0.0)
	credit_limit = maxi(limit, 0)
	default_multiple = maxf(multiple, 1.0)


# --- Queries -----------------------------------------------------------------


## Whole-money amount currently owed (rounded up — the shark never rounds in your favour).
func owed() -> int:
	return int(ceil(_balance))


func principal() -> int:
	return _principal


func has_debt() -> bool:
	return _balance > 0.0


## Headroom left to borrow before hitting the credit limit.
func available_credit() -> int:
	return maxi(credit_limit - owed(), 0)


## Behind on payments past the grace window (the warning before default).
func is_in_arrears() -> bool:
	return has_debt() and _days_unpaid > grace_days


## The debt has ballooned past the default multiple — the shark sends enforcers.
func is_defaulted() -> bool:
	return has_debt() and _balance >= float(_principal) * default_multiple


# --- Mutations ---------------------------------------------------------------


## Take a loan: adds to the outstanding balance (repaid later WITH interest). Fails for a
## non-positive amount or a draw that would breach the credit limit. Returns
## {success, disbursed, owed, reason}.
func borrow(amount: int) -> Dictionary:
	if amount <= 0:
		return _borrow_fail("non-positive amount")
	if owed() + amount > credit_limit:
		return _borrow_fail("over the credit limit")
	_principal += amount
	_balance += float(amount)
	return {"success": true, "disbursed": amount, "owed": owed(), "reason": ""}


## Compound the interest over `delta_days` and age the unpaid clock. No-op with no debt or a
## non-positive span.
func accrue(delta_days: float) -> void:
	if delta_days <= 0.0 or _balance <= 0.0:
		return
	_balance *= pow(1.0 + daily_rate, delta_days)
	_days_unpaid += delta_days


## Pay down the debt with `amount` (never overpaying the balance), resetting the arrears
## clock. Clearing it wipes the principal. Returns {success, paid, owed, cleared, reason}.
func repay(amount: int) -> Dictionary:
	if amount <= 0:
		return _repay_fail("non-positive amount")
	if _balance <= 0.0:
		return _repay_fail("no debt to repay")
	var paid := mini(amount, owed())
	_balance -= float(paid)
	_days_unpaid = 0.0
	if _balance <= 0.0:
		_balance = 0.0
		_principal = 0
		return {"success": true, "paid": paid, "owed": 0, "cleared": true, "reason": ""}
	return {"success": true, "paid": paid, "owed": owed(), "cleared": false, "reason": ""}


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	return {"principal": _principal, "balance": _balance, "days_unpaid": _days_unpaid}


func from_dict(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = data
	_principal = maxi(int(d.get("principal", 0)), 0)
	_balance = maxf(float(d.get("balance", 0.0)), 0.0)
	_days_unpaid = maxf(float(d.get("days_unpaid", 0.0)), 0.0)


# --- Internal ----------------------------------------------------------------


func _borrow_fail(reason: String) -> Dictionary:
	return {"success": false, "disbursed": 0, "owed": owed(), "reason": reason}


func _repay_fail(reason: String) -> Dictionary:
	return {"success": false, "paid": 0, "owed": owed(), "cleared": false, "reason": reason}
