class_name LoanSharkController
extends Node
## Brings the LoanShark model to life: owns the player's ONE running debt, compounds the
## interest on an in-game-day clock, resolves borrow/repay against PlayerStats, and when the
## debt DEFAULTS sends the shark's muscle — a violent enforcer visit that draws police heat
## (reported to the wanted system). Self-wires by group ("loan_shark"); a LoanSharkDen takes
## loans / makes payments against this one shared debt. Owns ONE LoanShark
## (tests/unit/test_loan_shark.gd); verified loan_shark_probe.gd.

signal borrowed(amount: int, owed: int)
signal repaid(amount: int, owed: int, cleared: bool)
signal loan_defaulted(owed: int)

## Floor on the day period and cap on days advanced per frame, so a tiny seconds_per_day or a
## lag-spike delta can't compound thousands of days in one frame.
const MIN_SECONDS_PER_DAY: float = 1.0
const MAX_DAYS_PER_FRAME: float = 10.0
## Crime reports a default's enforcer visit slams the wanted system with.
const ENFORCER_HEAT_REPORTS: int = 3

@export_range(0.0, 0.5) var daily_rate: float = LoanShark.DEFAULT_DAILY_RATE
@export var credit_limit: int = LoanShark.DEFAULT_CREDIT_LIMIT
## Real seconds per in-game day for the interest clock (<=0 pauses it).
@export var seconds_per_day: float = 90.0

var _loan: LoanShark
var _day_accum: float = 0.0
## True once the current default episode's enforcers have been sent, so they come ONCE per
## default (not every day). Cleared when the debt drops back out of default.
var _defaulted_fired: bool = false


func _ready() -> void:
	_loan = LoanShark.new(
		daily_rate, LoanShark.DEFAULT_GRACE_DAYS, credit_limit, LoanShark.DEFAULT_DEFAULT_MULTIPLE
	)
	add_to_group("loan_shark")


func _process(delta: float) -> void:
	if seconds_per_day <= 0.0 or _loan == null:
		return
	var period := maxf(seconds_per_day, MIN_SECONDS_PER_DAY)
	_day_accum = minf(_day_accum + delta, period * MAX_DAYS_PER_FRAME)
	while _day_accum >= period:
		_day_accum -= period
		_on_day()


## A day passes: compound the interest, then send enforcers ONCE if the debt has defaulted.
func _on_day() -> void:
	_loan.accrue(1.0)
	if _loan.is_defaulted():
		if not _defaulted_fired:
			_defaulted_fired = true
			loan_defaulted.emit(_loan.owed())
			_send_enforcers()
	else:
		_defaulted_fired = false


## Take a loan: the cash is added to PlayerStats and the debt recorded. Returns the amount
## disbursed (0 on failure — over the limit / no wallet).
func borrow(amount: int) -> int:
	var stats := _stats()
	if stats == null or not stats.has_method("add_money"):
		return 0
	var result := _loan.borrow(amount)
	if not result["success"]:
		return 0
	var disbursed := int(result["disbursed"])
	stats.add_money(disbursed)
	borrowed.emit(disbursed, _loan.owed())
	return disbursed


## Pay down the debt with up to `amount` from PlayerStats (only what the wallet holds and the
## debt needs). The wallet is charged BEFORE the model mutates, so a short wallet can't desync
## the books. Returns the amount actually paid (0 if nothing).
func repay(amount: int) -> int:
	var stats := _stats()
	if stats == null or not stats.has_method("spend_money") or not _loan.has_debt():
		return 0
	var payable := mini(mini(maxi(amount, 0), int(stats.money)), _loan.owed())
	if payable <= 0:
		return 0
	if not stats.spend_money(payable):
		return 0
	var result := _loan.repay(payable)
	# Re-arm the default's once-fire whenever a payment drops the debt out of default, so a
	# later re-balloon sends the enforcers again. (The _on_day else-branch alone can miss the
	# narrow band where one day's interest jumps the balance back over the threshold before it
	# ever reads as not-defaulted.)
	if not _loan.is_defaulted():
		_defaulted_fired = false
	repaid.emit(payable, _loan.owed(), bool(result["cleared"]))
	return payable


# --- Queries (passthroughs for the den / HUD) --------------------------------


func owed() -> int:
	return _loan.owed() if _loan != null else 0


func has_debt() -> bool:
	return _loan != null and _loan.has_debt()


func available_credit() -> int:
	return _loan.available_credit() if _loan != null else 0


func is_in_arrears() -> bool:
	return _loan != null and _loan.is_in_arrears()


func is_defaulted() -> bool:
	return _loan != null and _loan.is_defaulted()


# --- Internal ----------------------------------------------------------------


func _stats() -> Node:
	return get_tree().get_first_node_in_group("player_stats")


## A default sends the shark's muscle — a violent visit the cops notice.
func _send_enforcers() -> void:
	var wanted := get_tree().get_first_node_in_group("wanted")
	if wanted == null or not wanted.has_method("report_crime"):
		return
	for _i in ENFORCER_HEAT_REPORTS:
		wanted.report_crime(true)
