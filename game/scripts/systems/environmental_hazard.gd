class_name EnvironmentalHazard
extends RefCounted
## Pure environmental-hazard field — static and transient damage zones (a toxic
## waste dump, a radiation hotspot, a live electrical fault, a chemical cloud) that
## hurt anyone standing in them. Each zone is a circle on the XZ plane (centre +
## radius) with a hazard type and a damage-per-second. damage_at() sums the dps of
## every zone covering a position over a frame, optionally reduced by protection
## (a hazmat suit / armour 0..1). Transient zones (a thrown gas grenade) carry a
## lifetime that tick() ages out.
##
## No scene access: a controller owns one, calls damage_at(player_pos, dt,
## protection) each frame and applies the returned damage to PlayerHealth, and reads
## is_in_hazard()/dominant_hazard_at() to drive a HUD warning or steer NPC/CrowdPanic
## routing away from the zone. The damage value is applied by the caller (never a hard
## PlayerHealth dependency). Unit-tested headless
## (tests/unit/test_environmental_hazard.gd). Hazard zones are level/runtime data,
## not save data, so there is no serialize/restore.
##
## Zone row: {id, type, center: Vector3, radius: float, dps: float, duration?: float}.
## Rows with a missing/empty id, a non-positive radius/dps, or a duplicate id are
## dropped. Omitting duration (or <= 0) makes the zone permanent.

enum Hazard { TOXIC, RADIATION, FIRE, ELECTRICAL }

## Sentinel duration meaning "never expires".
const PERMANENT: float = -1.0

## id -> {type: int, center: Vector3, radius: float, dps: float, remaining: float}.
var _zones: Dictionary = {}


func _init(zones: Array = []) -> void:
	var source: Array = zones if not zones.is_empty() else default_zones()
	for entry: Variant in source:
		_register(entry)


## A small built-in set of static world hazards.
static func default_zones() -> Array:
	return [
		{
			"id": "toxic_dump",
			"type": Hazard.TOXIC,
			"center": Vector3(100, 0, 100),
			"radius": 30.0,
			"dps": 8.0
		},
		{
			"id": "radiation_field",
			"type": Hazard.RADIATION,
			"center": Vector3(-200, 0, 50),
			"radius": 40.0,
			"dps": 12.0,
		},
		{
			"id": "live_wire",
			"type": Hazard.ELECTRICAL,
			"center": Vector3(50, 0, -150),
			"radius": 12.0,
			"dps": 20.0,
		},
	]


# --- Queries --------------------------------------------------------------


func zone_count() -> int:
	return _zones.size()


func has_zone(id: String) -> bool:
	return _zones.has(id)


func ids() -> Array:
	var out: Array = _zones.keys()
	out.sort()
	return out


## Damage taken at a position over `dt` seconds: the summed dps of every zone covering
## it, reduced by `protection` (0 none .. 1 full). 0 outside all zones / non-positive dt.
func damage_at(position: Vector3, dt: float, protection: float = 0.0) -> float:
	if dt <= 0.0:
		return 0.0
	var dps: float = _total_dps_at(position)
	if dps <= 0.0:
		return 0.0
	return dps * dt * (1.0 - clampf(protection, 0.0, 1.0))


func is_in_hazard(position: Vector3) -> bool:
	for id: String in _zones:
		if _covers(_zones[id], position):
			return true
	return false


## The hazard TYPE of the most dangerous (highest-dps) zone covering a position, or
## -1 if the position is in no zone. Ties break to the alphabetically-first zone id.
func dominant_hazard_at(position: Vector3) -> int:
	var best_id: String = ""
	var best_dps: float = 0.0
	for id: String in ids():
		var zone: Dictionary = _zones[id]
		if _covers(zone, position) and float(zone["dps"]) > best_dps:
			best_dps = zone["dps"]
			best_id = id
	return _zones[best_id]["type"] if not best_id.is_empty() else -1


## Highest single-zone dps at a position (0 if in none) — for a HUD severity readout.
func strongest_dps_at(position: Vector3) -> float:
	var best: float = 0.0
	for id: String in _zones:
		var zone: Dictionary = _zones[id]
		if _covers(zone, position):
			best = maxf(best, float(zone["dps"]))
	return best


# --- Mutation / lifecycle -------------------------------------------------


## Spawn a timed hazard (a gas grenade, a fuel fire). Returns false for a duplicate id
## or a non-positive radius/dps/duration.
func add_transient(
	id: String, type: int, center: Vector3, radius: float, dps: float, duration: float
) -> bool:
	if id.is_empty() or _zones.has(id) or radius <= 0.0 or dps <= 0.0 or duration <= 0.0:
		return false
	_zones[id] = {
		"type": type, "center": center, "radius": radius, "dps": dps, "remaining": duration
	}
	return true


## Advance transient zones by `dt` and remove any that expire. Returns the ids that
## expired this tick. Permanent zones and non-positive spans are unaffected.
func tick(dt: float) -> Array:
	var expired: Array = []
	if dt <= 0.0:
		return expired
	for id: String in _zones.keys():
		var remaining: float = _zones[id]["remaining"]
		if remaining == PERMANENT:
			continue
		remaining -= dt
		if remaining <= 0.0:
			_zones.erase(id)
			expired.append(id)
		else:
			_zones[id]["remaining"] = remaining
	return expired


## Remove a zone by id. False if it does not exist.
func remove_zone(id: String) -> bool:
	return _zones.erase(id)


# --- Internal -------------------------------------------------------------


## Total dps of every zone covering a position.
func _total_dps_at(position: Vector3) -> float:
	var total: float = 0.0
	for id: String in _zones:
		var zone: Dictionary = _zones[id]
		if _covers(zone, position):
			total += float(zone["dps"])
	return total


## Whether a zone's XZ circle covers a position (height ignored).
static func _covers(zone: Dictionary, position: Vector3) -> bool:
	var center: Vector3 = zone["center"]
	var dx: float = center.x - position.x
	var dz: float = center.z - position.z
	var radius: float = zone["radius"]
	return dx * dx + dz * dz <= radius * radius


## Validate and store one zone row; drops malformed (no/empty id, non-positive
## radius/dps) and duplicates.
func _register(entry: Variant) -> void:
	if not (entry is Dictionary):
		return
	var row: Dictionary = entry
	if not row.has("id"):
		return
	var id: String = str(row["id"])
	var radius: float = float(row.get("radius", 0.0))
	var dps: float = float(row.get("dps", 0.0))
	if id.is_empty() or _zones.has(id) or radius <= 0.0 or dps <= 0.0:
		return
	var duration: float = float(row.get("duration", PERMANENT))
	_zones[id] = {
		"type": int(row.get("type", Hazard.TOXIC)),
		"center": row.get("center", Vector3.ZERO),
		"radius": radius,
		"dps": dps,
		"remaining": duration if duration > 0.0 else PERMANENT,
	}
