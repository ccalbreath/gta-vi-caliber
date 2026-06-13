class_name MoneyLaundering
extends RefCounted
## Pure dirty-money laundering ledger — the criminal-economy counterpart to the
## clean wallet. Crime proceeds (contraband sales, heist cuts, robberies) arrive
## as DIRTY cash that can't be spent safely; the player routes it through front
## businesses that each take a cut and have a per-cycle throughput cap, turning it
## into CLEAN cash the caller adds to the wallet (like PropertyOwnership.buy —
## the model never touches a scene or a wallet directly).
##
## Laundering raises SUSPICION proportional to the volume pushed; let it build past
## the audit threshold and an audit() can seize a slice of the remaining dirty pile.
## tick() opens a fresh laundering window (resets per-front usage) and cools
## suspicion over time, so steady trickling is safe while dumping a fortune at once
## is risky — the classic wash-it-slow tension.
##
## No scene access; deterministic; unit-tested headless (tests/unit/test_money_laundering.gd).
## A controller feeds add_dirty() from the crime systems, calls launder()/tick() and
## applies the returned clean amount + any seizure/heat through existing seams.
##
## Front row: {id, name, capacity, cut}. Rows with a missing/empty id, a
## non-positive capacity, a cut outside [0, 1), or a duplicate id are dropped.

## Suspicion added per dirty dollar laundered (so ~$50k in one window flags you).
const SUSPICION_PER_DOLLAR: float = 1.0 / 50000.0
## Suspicion shed per tick() cycle as the heat dies down.
const SUSPICION_COOL_PER_CYCLE: float = 0.06
## At/above this suspicion the operation is flagged and an audit can land.
const AUDIT_THRESHOLD: float = 0.7
## Fraction of the remaining dirty pile seized by a successful audit.
const SEIZE_FRACTION: float = 0.4
## Suspicion remaining after an audit clears the books.
const POST_AUDIT_SUSPICION: float = 0.25

var _fronts: Array = []
var _used: Dictionary = {}  # front id -> dirty $ pushed this cycle
var _dirty: int = 0
var _suspicion: float = 0.0
var _clean_total: int = 0


func _init(fronts: Array = []) -> void:
	var rows: Array = fronts if not fronts.is_empty() else _default_fronts()
	for row in rows:
		_add_front(row)


func _default_fronts() -> Array:
	return [
		{"id": "laundromat", "name": "Suds & Sun Laundromat", "capacity": 2000, "cut": 0.10},
		{"id": "nightclub", "name": "Neon Pulse Nightclub", "capacity": 8000, "cut": 0.18},
		{"id": "marina", "name": "Bayfront Marina", "capacity": 20000, "cut": 0.25},
	]


func _add_front(row: Variant) -> void:
	if typeof(row) != TYPE_DICTIONARY:
		return
	var id: String = str(row.get("id", "")).strip_edges()
	var capacity: int = int(row.get("capacity", 0))
	var cut: float = float(row.get("cut", -1.0))
	if id.is_empty() or capacity <= 0 or cut < 0.0 or cut >= 1.0 or has_front(id):
		return
	_fronts.append({"id": id, "name": str(row.get("name", id)), "capacity": capacity, "cut": cut})
	_used[id] = 0


# --- Queries -----------------------------------------------------------------


func front_count() -> int:
	return _fronts.size()


func has_front(id: String) -> bool:
	for f in _fronts:
		if f["id"] == id:
			return true
	return false


func dirty_balance() -> int:
	return _dirty


func clean_laundered_total() -> int:
	return _clean_total


func suspicion_level() -> float:
	return _suspicion


func is_flagged() -> bool:
	return _suspicion >= AUDIT_THRESHOLD


## Dirty dollars still washable through this front in the current cycle.
func capacity_remaining(front_id: String) -> int:
	if not has_front(front_id):
		return 0
	var used: int = _used.get(front_id, 0)
	return maxi(_front(front_id)["capacity"] - used, 0)


# --- Mutations (return fresh result dicts) -----------------------------------


## Crime proceeds arrive dirty. Returns the new dirty balance.
func add_dirty(amount: int) -> int:
	if amount > 0:
		_dirty += amount
	return _dirty


## Wash up to [param amount] dirty dollars through [param front_id], bounded by the
## dirty balance and the front's remaining cycle capacity. Returns
## {success, routed, clean, fee, suspicion}; success is false for an unknown front
## or when nothing could be routed.
func launder(front_id: String, amount: int) -> Dictionary:
	if not has_front(front_id) or amount <= 0:
		return {"success": false, "routed": 0, "clean": 0, "fee": 0, "suspicion": _suspicion}
	var routed: int = mini(mini(amount, _dirty), capacity_remaining(front_id))
	if routed <= 0:
		return {"success": false, "routed": 0, "clean": 0, "fee": 0, "suspicion": _suspicion}
	var cut: float = _front(front_id)["cut"]
	var clean: int = int(floor(float(routed) * (1.0 - cut)))
	_dirty -= routed
	_used[front_id] = int(_used.get(front_id, 0)) + routed
	_clean_total += clean
	_suspicion = clampf(_suspicion + float(routed) * SUSPICION_PER_DOLLAR, 0.0, 1.0)
	return {
		"success": true,
		"routed": routed,
		"clean": clean,
		"fee": routed - clean,
		"suspicion": _suspicion,
	}


## Open a fresh laundering window (per-front usage resets) and cool suspicion.
func tick(cycles: int = 1) -> void:
	if cycles <= 0:
		return
	for id in _used:
		_used[id] = 0
	_suspicion = clampf(_suspicion - SUSPICION_COOL_PER_CYCLE * float(cycles), 0.0, 1.0)


## If currently flagged, seize a slice of the remaining dirty pile and partly clear
## suspicion. Returns {seized, flagged}; a no-op (seized 0) when not flagged.
func audit() -> Dictionary:
	if not is_flagged():
		return {"seized": 0, "flagged": false}
	var seized: int = int(floor(float(_dirty) * SEIZE_FRACTION))
	_dirty -= seized
	_suspicion = POST_AUDIT_SUSPICION
	return {"seized": seized, "flagged": true}


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	return {
		"dirty": _dirty,
		"suspicion": _suspicion,
		"clean_total": _clean_total,
		"used": _used.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	_dirty = int(data.get("dirty", 0))
	_suspicion = clampf(float(data.get("suspicion", 0.0)), 0.0, 1.0)
	_clean_total = int(data.get("clean_total", 0))
	var used: Dictionary = data.get("used", {})
	for id in _used:
		_used[id] = int(used.get(id, 0))


func _front(id: String) -> Dictionary:
	for f in _fronts:
		if f["id"] == id:
			return f
	return {}
