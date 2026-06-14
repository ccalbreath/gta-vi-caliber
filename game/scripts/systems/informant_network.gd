class_name InformantNetwork
extends RefCounted
## Pure paid-intel network — cultivate criminal informants for cash leads. Pay a RETAINER to
## build an informant's TRUST; once they trust you enough they hand over a reliable TIP worth a
## cut scaled by that trust, and cashing it spends down their current intel (trust drops) so you
## have to keep them on the payroll. A recurring pay-to-cultivate loop, distinct from FriendCircle
## (activity-built rapport → one-shot perks) and the one-shot haggle/bribe. No nodes, no wallet
## coupling (the caller spends the retainer + banks the tip). Unit-tested headless
## (tests/unit/test_informant_network.gd).

const MIN_TRUST: float = 0.0
const MAX_TRUST: float = 1.0
## Trust gained per money unit of retainer ($10000 -> full trust at the default).
const DEFAULT_TRUST_PER_DOLLAR: float = 0.0001
## Trust at/above which tips are reliable (below it they know nothing useful yet).
const DEFAULT_RELIABLE_AT: float = 0.5
## Trust spent when a reliable tip is cashed (their current intel is used up).
const DEFAULT_TIP_DECAY: float = 0.3

var trust_per_dollar: float
var reliable_at: float
var tip_decay: float

## id -> {name, tip_base, trust}. Insertion-ordered.
var _informants: Dictionary = {}


func _init(
	informants: Array = [],
	per_dollar: float = DEFAULT_TRUST_PER_DOLLAR,
	reliable: float = DEFAULT_RELIABLE_AT,
	decay: float = DEFAULT_TIP_DECAY
) -> void:
	trust_per_dollar = maxf(per_dollar, 0.0)
	reliable_at = clampf(reliable, 0.0, 1.0)
	tip_decay = maxf(decay, 0.0)
	if trust_per_dollar == 0.0:
		push_warning("InformantNetwork: trust_per_dollar is 0 — retainers will never build trust")
	var source: Array = informants if not informants.is_empty() else default_informants()
	for entry: Variant in source:
		_register(entry)


## Built-in roster — bigger tips from better-connected (and pricier-to-cultivate) sources.
static func default_informants() -> Array:
	return [
		{"id": "barfly", "name": "The Barfly", "tip_base": 8000},
		{"id": "fixer", "name": "Street Fixer", "tip_base": 20000},
		{"id": "dirty_cop", "name": "Dirty Cop", "tip_base": 35000},
	]


# --- Queries -----------------------------------------------------------------


func informant_count() -> int:
	return _informants.size()


func has_informant(id: String) -> bool:
	return _informants.has(id)


func trust_of(id: String) -> float:
	return float(_informants[id]["trust"]) if _informants.has(id) else 0.0


func tip_base_of(id: String) -> int:
	return int(_informants[id]["tip_base"]) if _informants.has(id) else 0


## True once trust is high enough that this informant's next tip pays out.
func is_reliable(id: String) -> bool:
	return _informants.has(id) and float(_informants[id]["trust"]) >= reliable_at


# --- Mutations ---------------------------------------------------------------


## Pay a retainer to build trust (capped at MAX_TRUST). Non-positive amounts are ignored.
## Returns the new trust.
func pay_retainer(id: String, amount: int) -> float:
	if not _informants.has(id) or amount <= 0:
		return trust_of(id)
	var t := clampf(
		float(_informants[id]["trust"]) + float(amount) * trust_per_dollar, MIN_TRUST, MAX_TRUST
	)
	_informants[id]["trust"] = t
	return t


## Ask for a tip. A trusted informant (trust >= reliable_at) hands over a cash lead worth
## tip_base * trust and spends tip_decay of their trust; a low-trust ask is a DUD (no value, no
## decay). Returns {reliable, value, trust}.
func request_tip(id: String) -> Dictionary:
	if not _informants.has(id):
		return {"reliable": false, "value": 0, "trust": 0.0}
	var t := float(_informants[id]["trust"])
	if t < reliable_at:
		return {"reliable": false, "value": 0, "trust": t}
	var value := int(round(float(_informants[id]["tip_base"]) * t))
	var after := maxf(t - tip_decay, MIN_TRUST)
	_informants[id]["trust"] = after
	return {"reliable": true, "value": value, "trust": after}


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	var trusts: Dictionary = {}
	for id: String in _informants:
		trusts[id] = _informants[id]["trust"]
	return {"trust": trusts}


func from_dict(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var stored: Variant = (data as Dictionary).get("trust")
	if not (stored is Dictionary):
		return
	var trusts: Dictionary = stored
	for key: Variant in trusts:
		var id: String = str(key)
		if _informants.has(id):
			_informants[id]["trust"] = clampf(float(trusts[key]), MIN_TRUST, MAX_TRUST)


# --- Internal ----------------------------------------------------------------


func _register(entry: Variant) -> void:
	if not (entry is Dictionary):
		return
	var row: Dictionary = entry
	if not row.has("id"):
		return
	var id: String = str(row["id"])
	if id.is_empty() or _informants.has(id):
		return
	var tip_base: int = int(row.get("tip_base", 0))
	if tip_base <= 0:
		return
	_informants[id] = {"name": str(row.get("name", id)), "tip_base": tip_base, "trust": 0.0}
