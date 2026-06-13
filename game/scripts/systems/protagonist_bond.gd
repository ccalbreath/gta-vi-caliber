class_name ProtagonistBond
extends RefCounted
## The Lucia + Jason relationship — GTA VI's headline dual-protagonist dynamic as
## a pure, persistent bond meter. Shared scores (co-op missions, rescuing each
## other, time together) raise the bond; betrayals, abandoning a partner in
## danger, and opposing choices lower it. The bond tier then scales co-op payouts,
## whether you can call the other lead for backup, and how snappy the
## CharacterSwitcher feels — the closer the pair, the more they fight as one.
##
## Distinct from CharacterRoster/CharacterSwitcher (which OWN the leads and the
## camera/wallet swap): this is the relationship LAYER on top. No scene access;
## deterministic; unit-tested headless (tests/unit/test_protagonist_bond.gd). A
## controller feeds record_*() from mission/combat events, reads the scalars at
## the relevant seams, and persists via to_dict()/from_dict().

const BOND_MIN: float = 0.0
const BOND_MAX: float = 100.0
## Partners start wary-but-willing, mid-meter.
const BOND_START: float = 50.0
## Bond at/above which a lead will answer a backup call.
const BACKUP_THRESHOLD: float = 55.0

# Tier thresholds (lower bound of each tier).
const TIER_WARY: float = 25.0
const TIER_PARTNERS: float = 50.0
const TIER_RIDE_OR_DIE: float = 80.0

# Event weights (per unit intensity/severity, clamped 0..1 by callers ideally).
const COOP_GAIN: float = 12.0
const RESCUE_GAIN: float = 18.0
const CONFLICT_LOSS: float = 10.0
const BETRAYAL_LOSS: float = 35.0
## Per in-game day the bond drifts back toward the neutral baseline.
const DRIFT_PER_DAY: float = 1.5

var _bond: float = BOND_START


func _init(start: float = BOND_START) -> void:
	_bond = clampf(start, BOND_MIN, BOND_MAX)


# --- Queries -----------------------------------------------------------------


func bond() -> float:
	return _bond


## Tier label for the current bond.
func tier() -> String:
	if _bond >= TIER_RIDE_OR_DIE:
		return "ride_or_die"
	if _bond >= TIER_PARTNERS:
		return "partners"
	if _bond >= TIER_WARY:
		return "wary"
	return "estranged"


## True once the pair are close enough that one will answer a backup call.
func backup_available() -> bool:
	return _bond >= BACKUP_THRESHOLD


## Co-op heist/mission payout multiplier: a tight crew nets a bigger shared cut.
## Maps bond 0..100 → 0.80x..1.30x (neutral 50 → ~1.05x).
func payout_multiplier() -> float:
	return 0.8 + (_bond / BOND_MAX) * 0.5


## CharacterSwitcher cooldown scale: the closer the leads, the snappier the swap.
## Bond 0 → 1.6x (sluggish), bond 100 → 0.6x (instant-ish). 1.0x near neutral.
func switch_cooldown_scale() -> float:
	return lerpf(1.6, 0.6, _bond / BOND_MAX)


# --- Mutations (return the new bond) -----------------------------------------


## A shared score/mission pulled off together. [param intensity] ~0..1.
func record_coop(intensity: float = 1.0) -> float:
	return _shift(COOP_GAIN * maxf(intensity, 0.0))


## One lead saved the other from death/capture. [param weight] ~0..1.
func record_rescue(weight: float = 1.0) -> float:
	return _shift(RESCUE_GAIN * maxf(weight, 0.0))


## A clash short of betrayal (opposing a choice, an argument). [param severity] ~0..1.
func record_conflict(severity: float = 1.0) -> float:
	return _shift(-CONFLICT_LOSS * maxf(severity, 0.0))


## A real betrayal — abandoning a partner under fire, taking their cut.
func record_betrayal(severity: float = 1.0) -> float:
	return _shift(-BETRAYAL_LOSS * maxf(severity, 0.0))


## Time apart pulls the bond gently back toward the neutral baseline.
func drift(days: float = 1.0) -> float:
	if days <= 0.0:
		return _bond
	var step := DRIFT_PER_DAY * days
	if _bond > BOND_START:
		_bond = maxf(_bond - step, BOND_START)
	elif _bond < BOND_START:
		_bond = minf(_bond + step, BOND_START)
	return _bond


func _shift(amount: float) -> float:
	_bond = clampf(_bond + amount, BOND_MIN, BOND_MAX)
	return _bond


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	return {"bond": _bond}


func from_dict(data: Dictionary) -> void:
	_bond = clampf(float(data.get("bond", BOND_START)), BOND_MIN, BOND_MAX)
