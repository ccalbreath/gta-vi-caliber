class_name ProtagonistBondController
extends Node
## Brings the EXISTING (but previously unwired) ProtagonistBond model to life — GTA VI's
## headline Lucia + Jason dynamic, made into a playable closed loop. Self-wires by group
## ("protagonist_bond") and CONSUMES the heist_board node's `heist_resolved` signal: a
## score pulled off together (success) raises the bond, a botched one breeds conflict.
## It then FEEDS the bond back out — a successful heist pays a CO-OP PREMIUM on top of the
## base take, sized by the bond's payout_multiplier (a tighter crew splits a bigger cut),
## so each shared score makes the next one pay better. Also runs the day-drift clock and
## exposes backup_available()/switch_cooldown_scale() for the backup-call and
## CharacterSwitcher seams. Owns ONE ProtagonistBond (tests/unit/test_protagonist_bond.gd);
## verified in tests/protagonist_bond_probe.gd.

signal bond_changed(bond: float, tier: String)
signal coop_bonus_paid(bonus: int)

## Floor on the day period and cap on days advanced per frame, so a tiny seconds_per_day
## or a lag-spike delta can't run thousands of drift ticks in one frame.
const MIN_SECONDS_PER_DAY: float = 1.0
const MAX_DAYS_PER_FRAME: float = 10.0

## Co-op intensity a successful heist contributes, and the conflict a botched one breeds.
@export_range(0.0, 1.0) var heist_coop_intensity: float = 0.6
@export_range(0.0, 1.0) var heist_fail_conflict: float = 0.3
## Real seconds per in-game day for the bond's drift-to-neutral clock (<=0 pauses it).
@export var seconds_per_day: float = 90.0
## Starting bond (defaults to the model's neutral baseline).
@export var start_bond: float = ProtagonistBond.BOND_START

var _bond: ProtagonistBond
var _day_accum: float = 0.0
## Weak ref to the heist source we listen to; re-binds if it's freed/replaced.
var _heist_ref: WeakRef = null


func _ready() -> void:
	_bond = ProtagonistBond.new(start_bond)
	add_to_group("protagonist_bond")


func _process(delta: float) -> void:
	_bind_heist()
	if seconds_per_day <= 0.0 or _bond == null:
		return
	var period := maxf(seconds_per_day, MIN_SECONDS_PER_DAY)
	_day_accum = minf(_day_accum + delta, period * MAX_DAYS_PER_FRAME)
	while _day_accum >= period:
		_day_accum -= period
		var before := _bond.bond()
		_bond.drift(1.0)
		if not is_equal_approx(before, _bond.bond()):
			_emit_changed()


## Connect to the heist source whenever it appears, and RE-connect if the node we were
## bound to has been freed/replaced (works in any spawn order).
func _bind_heist() -> void:
	if _heist_ref != null and is_instance_valid(_heist_ref.get_ref()):
		return
	var heist := get_tree().get_first_node_in_group("heist_board")
	if heist != null and heist.has_signal("heist_resolved"):
		if not heist.is_connected("heist_resolved", _on_heist_resolved):
			heist.connect("heist_resolved", _on_heist_resolved)
		_heist_ref = weakref(heist)


func _on_heist_resolved(success: bool, take: int) -> void:
	if _bond == null:
		return
	if success:
		_bond.record_coop(heist_coop_intensity)
		_pay_coop_bonus(take)
	else:
		_bond.record_conflict(heist_fail_conflict)
	_emit_changed()


## Pay the co-op premium on a shared take: the slice ABOVE the base the bond earns. Clamped
## non-negative so a weak bond never claws back pay the heist already banked.
func _pay_coop_bonus(take: int) -> void:
	var premium := maxf(_bond.payout_multiplier() - 1.0, 0.0)
	var bonus := int(round(float(maxi(take, 0)) * premium))
	if bonus <= 0:
		return
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats != null and stats.has_method("add_money"):
		stats.add_money(bonus)
		coop_bonus_paid.emit(bonus)


func _emit_changed() -> void:
	bond_changed.emit(_bond.bond(), _bond.tier())


# --- Passthroughs / direct hooks ---------------------------------------------


func bond() -> float:
	return _bond.bond() if _bond != null else 0.0


func tier() -> String:
	return _bond.tier() if _bond != null else ""


## True once the leads are close enough that one answers a backup call.
func backup_available() -> bool:
	return _bond != null and _bond.backup_available()


func payout_multiplier() -> float:
	return _bond.payout_multiplier() if _bond != null else 1.0


## CharacterSwitcher cooldown scale (closer leads swap snappier) — the switch seam reads
## this; exposed here so it stays a passthrough rather than a second bond instance.
func switch_cooldown_scale() -> float:
	return _bond.switch_cooldown_scale() if _bond != null else 1.0


## One lead saved the other under fire — a strong bond gain from a non-heist source.
func record_rescue(weight: float = 1.0) -> void:
	if _bond == null:
		return
	_bond.record_rescue(weight)
	_emit_changed()


## A real betrayal (abandoning a partner, taking their cut) — a hard bond hit.
func record_betrayal(severity: float = 1.0) -> void:
	if _bond == null:
		return
	_bond.record_betrayal(severity)
	_emit_changed()
