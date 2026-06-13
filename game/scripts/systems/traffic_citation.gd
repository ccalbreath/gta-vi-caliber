class_name TrafficCitation
extends RefCounted
## Pure civil/traffic-law ledger — the CIVIL counterpart to the criminal
## WantedSystem/CrimeWitness loop. It issues fines for speeding, running a red light,
## reckless collision damage, and hit-and-run, tracks an unpaid-fine balance, and
## escalates a citation into actual police heat when it is ignored too long OR a cop
## witnesses the infraction live. Most infractions are quiet tickets the player can
## settle at a courthouse; ignoring them (or being seen) promotes the civil debt into
## a WantedSystem star.
##
## No scene access: a controller owns one, feeds it driving events
## (record_speeding/record_red_light/record_collision), settles fines against a
## wallet balance the caller applies (like PropertyOwnership.buy), and each frame
## passes consume_star_severity() / the tick() escalations to WantedSystem.add_crime()
## — the civil->criminal promotion goes through that existing seam, not a re-implemented
## heat model. `cop_sees` is a coarse boolean the caller can source from
## CrimeWitness.can_witness. Collision damage_hp is the same severity that feeds
## VehicleCondition.apply_crash, so one impact drives both wear and a citation.
## Unit-tested headless (tests/unit/test_traffic_citation.gd).
##
## Zone row: {id, limit_kmh, fine_per_kmh}. Rows with a missing/empty id, a
## non-positive limit, or a duplicate id are dropped at construction.

## Traffic-light state (self-contained so the model has no hard dependency; a caller
## maps its TrafficSignal light onto this).
enum Light { GREEN, YELLOW, RED }

## Speed (km/h) over a zone's limit that is tolerated before a ticket is issued.
const GRACE_KMH: float = 10.0
## Overage (km/h) beyond which speeding is gross enough to become heat on its own.
const SPEED_STAR_KMH: float = 50.0
const REDLIGHT_FINE: int = 250
## Reckless-collision fine per hit-point of damage, and the minimum damage to ticket.
const RECKLESS_FINE_PER_HP: float = 15.0
const RECKLESS_DAMAGE_MIN: float = 5.0
## A hit-and-run fine is the reckless fine times this.
const HIT_AND_RUN_MULT: float = 3.0
## Distance (m) to the stop line at/within which a moving car is "running" the light.
const STOP_LINE_TOLERANCE: float = 0.5
## Game-days an unpaid citation can be ignored before it escalates into heat.
const ESCALATE_AFTER_DAYS: float = 3.0
## Star severity contributions fed to WantedSystem.add_crime.
const COP_WITNESS_STAR: float = 0.5
const SPEED_STAR_SEVERITY: float = 0.6
const HIT_RUN_STAR: float = 0.7
const ESCALATE_STAR: float = 0.4

## id -> {limit_kmh: int, fine_per_kmh: int}.
var _zones: Dictionary = {}
## citation_id -> {kind: String, fine: int, age: float, escalated: bool}.
var _citations: Dictionary = {}
var _next_id: int = 0
var _total_issued: int = 0
var _total_paid: int = 0
## Star severity accumulated from witnessed/escalated citations, drained by the caller.
var _star_accum: float = 0.0


func _init(zones: Array = []) -> void:
	var source: Array = zones if not zones.is_empty() else default_zones()
	for entry: Variant in source:
		_register(entry)


## Built-in speed-limit zones (km/h limit, fine per km/h over).
static func default_zones() -> Array:
	return [
		{"id": "residential", "limit_kmh": 50, "fine_per_kmh": 8},
		{"id": "highway", "limit_kmh": 110, "fine_per_kmh": 5},
		{"id": "school", "limit_kmh": 30, "fine_per_kmh": 20},
	]


# --- Zone queries ---------------------------------------------------------


func zone_count() -> int:
	return _zones.size()


func has_zone(id: String) -> bool:
	return _zones.has(id)


func zone_ids() -> Array:
	var out: Array = _zones.keys()
	out.sort()
	return out


## km/h limit for a zone, or -1 for an unknown zone.
func limit_of(id: String) -> int:
	return _zones[id]["limit_kmh"] if _zones.has(id) else -1


## km/h over (limit + grace), floored at 0. 0 for an unknown zone.
func overage(zone_id: String, speed_kmh: float) -> float:
	if not _zones.has(zone_id):
		return 0.0
	return maxf(speed_kmh - float(_zones[zone_id]["limit_kmh"]) - GRACE_KMH, 0.0)


func is_speeding(zone_id: String, speed_kmh: float) -> bool:
	return overage(zone_id, speed_kmh) > 0.0


# --- Issuing citations ----------------------------------------------------


## Ticket speeding. Returns {success, kind, fine, overage, escalated, star_severity,
## citation_id, reason}. Fails (no citation) within grace or for an unknown zone.
## Gross overage (>= SPEED_STAR_KMH) or a watching cop promotes it straight to heat.
func record_speeding(zone_id: String, speed_kmh: float, cop_sees: bool = false) -> Dictionary:
	if not _zones.has(zone_id):
		return _infraction_fail("unknown zone: %s" % zone_id)
	var over: float = overage(zone_id, speed_kmh)
	if over <= 0.0:
		return _infraction_fail("within grace")
	var fine: int = int(round(over * float(_zones[zone_id]["fine_per_kmh"])))
	var severity: float = 0.0
	if over >= SPEED_STAR_KMH:
		severity = SPEED_STAR_SEVERITY
	if cop_sees:
		severity = maxf(severity, COP_WITNESS_STAR)
	return _issue("speeding", fine, over, severity)


## Ticket running a red light. Fails when the light is not RED, or the car stopped
## legally (speed <= 0 — a stationary car at the line is not an infraction).
func record_red_light(
	light: int, distance_to_line: float, speed_kmh: float, cop_sees: bool = false
) -> Dictionary:
	if light != Light.RED:
		return _infraction_fail("light not red")
	if speed_kmh <= 0.0:
		return _infraction_fail("stopped legally")
	if distance_to_line > STOP_LINE_TOLERANCE:
		return _infraction_fail("not yet at the line")
	var severity: float = COP_WITNESS_STAR if cop_sees else 0.0
	return _issue("red_light", REDLIGHT_FINE, 0.0, severity)


## Ticket a reckless collision. fled multiplies the fine and makes it a hit-and-run
## (which is heat on its own). Sub-threshold damage issues nothing.
func record_collision(damage_hp: float, fled: bool, cop_sees: bool = false) -> Dictionary:
	if damage_hp < RECKLESS_DAMAGE_MIN:
		return _infraction_fail("minor collision")
	var raw_fine: float = RECKLESS_FINE_PER_HP * damage_hp
	var kind: String = "reckless"
	var severity: float = 0.0
	if fled:
		raw_fine *= HIT_AND_RUN_MULT  # round once, after the multiplier
		kind = "hit_and_run"
		severity = HIT_RUN_STAR
	if cop_sees:
		severity = maxf(severity, COP_WITNESS_STAR)
	return _issue(kind, int(round(raw_fine)), 0.0, severity)


# --- Ledger queries -------------------------------------------------------


func unpaid_balance() -> int:
	var sum: int = 0
	for cid: String in _citations:
		sum += int(_citations[cid]["fine"])
	return sum


func citation_count() -> int:
	return _citations.size()


func outstanding_ids() -> Array:
	var out: Array = _citations.keys()
	out.sort()
	return out


func total_issued() -> int:
	return _total_issued


func total_paid() -> int:
	return _total_paid


# --- Paying ---------------------------------------------------------------


## Settle ALL outstanding fines against a wallet. {success, cost, new_balance, reason};
## fails when nothing is outstanding or the balance can't cover it.
func pay(balance: int) -> Dictionary:
	var owed: int = unpaid_balance()
	if owed <= 0:
		return _fail(balance, "no outstanding citations")
	if balance < owed:
		return _fail(balance, "insufficient funds: need %d, have %d" % [owed, balance])
	_citations.clear()
	_total_paid += owed
	return {"success": true, "cost": owed, "new_balance": balance - owed, "reason": ""}


## Settle one citation by id. Same money-result shape.
func pay_citation(citation_id: String, balance: int) -> Dictionary:
	if not _citations.has(citation_id):
		return _fail(balance, "unknown citation: %s" % citation_id)
	var fine: int = _citations[citation_id]["fine"]
	if balance < fine:
		return _fail(balance, "insufficient funds: need %d, have %d" % [fine, balance])
	_citations.erase(citation_id)
	_total_paid += fine
	return {"success": true, "cost": fine, "new_balance": balance - fine, "reason": ""}


# --- Escalation / heat seam -----------------------------------------------


## Age outstanding citations by `delta_days`. Returns {citation_id, star_severity} for
## each citation that crossed ESCALATE_AFTER_DAYS this tick — feed each severity
## DIRECTLY to WantedSystem.add_crime. This path is DISJOINT from the live-witnessed
## accumulator (consume_star_severity()): escalations are NOT added there, so feeding
## both can't double-count heat. Non-positive spans are ignored.
func tick(delta_days: float) -> Array:
	var escalations: Array = []
	if delta_days <= 0.0:
		return escalations
	for cid: String in _citations:
		var citation: Dictionary = _citations[cid]
		citation["age"] = float(citation["age"]) + delta_days
		if not bool(citation["escalated"]) and float(citation["age"]) >= ESCALATE_AFTER_DAYS:
			citation["escalated"] = true
			escalations.append({"citation_id": cid, "star_severity": ESCALATE_STAR})
	return escalations


## Total WantedSystem heat the caller should add this frame (then drain it).
func pending_star_severity() -> float:
	return _star_accum


## Return and zero the accumulated star severity, so the caller adds it exactly once.
func consume_star_severity() -> float:
	var severity: float = _star_accum
	_star_accum = 0.0
	return severity


# --- Persistence ----------------------------------------------------------


func to_dict() -> Dictionary:
	var citations: Array = []
	for cid: String in outstanding_ids():
		var citation: Dictionary = _citations[cid]
		(
			citations
			. append(
				{
					"id": cid,
					"kind": citation["kind"],
					"fine": citation["fine"],
					"age": citation["age"],
					"escalated": citation["escalated"],
				}
			)
		)
	return {"citations": citations, "total_issued": _total_issued, "total_paid": _total_paid}


## Restore outstanding citations + lifetime totals. Malformed/unknown rows dropped.
func load_dict(data: Dictionary) -> void:
	_citations = {}
	_total_issued = int(maxf(float(data.get("total_issued", 0)), 0.0))
	_total_paid = int(maxf(float(data.get("total_paid", 0)), 0.0))
	var stored: Variant = data.get("citations")
	if not (stored is Array):
		return
	for entry: Variant in stored:
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry
		if not (row.has("id") and row.has("fine")):
			continue
		var cid: String = str(row["id"])
		var fine: int = int(row.get("fine", 0))
		if cid.is_empty() or fine <= 0 or _citations.has(cid):
			continue
		_citations[cid] = {
			"kind": str(row.get("kind", "speeding")),
			"fine": fine,
			"age": maxf(float(row.get("age", 0.0)), 0.0),
			"escalated": bool(row.get("escalated", false)),
		}
	# Advance the id counter past any loaded ids so a new citation can't overwrite one.
	var max_id: int = -1
	for cid: String in _citations:
		if cid.begins_with("cit_"):
			max_id = maxi(max_id, int(cid.substr(4)))
	_next_id = max_id + 1


## Clear outstanding citations + heat accumulator (lifetime totals kept).
func reset() -> void:
	_citations = {}
	_star_accum = 0.0


# --- Internal -------------------------------------------------------------


func _issue(kind: String, fine: int, over: float, severity: float) -> Dictionary:
	var cid: String = "cit_%d" % _next_id
	_next_id += 1
	_citations[cid] = {"kind": kind, "fine": fine, "age": 0.0, "escalated": false}
	_total_issued += fine
	_star_accum += severity
	return {
		"success": true,
		"kind": kind,
		"fine": fine,
		"overage": over,
		"escalated": severity > 0.0,
		"star_severity": severity,
		"citation_id": cid,
		"reason": "",
	}


func _infraction_fail(reason: String) -> Dictionary:
	return {
		"success": false,
		"kind": "",
		"fine": 0,
		"overage": 0.0,
		"escalated": false,
		"star_severity": 0.0,
		"citation_id": "",
		"reason": reason,
	}


func _fail(balance: int, reason: String) -> Dictionary:
	return {"success": false, "cost": 0, "new_balance": balance, "reason": reason}


## Validate and store one zone row; drops malformed (no/empty id, non-positive limit)
## and duplicates.
func _register(entry: Variant) -> void:
	if not (entry is Dictionary):
		return
	var row: Dictionary = entry
	if not row.has("id"):
		return
	var id: String = str(row["id"])
	var limit: int = int(row.get("limit_kmh", 0))
	if id.is_empty() or limit <= 0 or _zones.has(id):
		return
	_zones[id] = {"limit_kmh": limit, "fine_per_kmh": maxi(int(row.get("fine_per_kmh", 5)), 1)}
