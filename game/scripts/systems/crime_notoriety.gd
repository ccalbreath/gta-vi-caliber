class_name CrimeNotoriety
extends RefCounted
## Pure per-crime-type infamy "rap sheet" — the city's long memory of WHAT kind of
## criminal you are, orthogonal to current wanted-stars (WantedSystem heat decays to
## zero) and to faction reputation (FactionStanding is faction-keyed, this is
## crime-type-keyed). Each category (cop-killing, GTA, bank jobs, arson, drug
## trafficking, assault, kidnapping) accrues a persistent infamy that does NOT reset
## when you go cold — it only fades slowly over in-game days via decay(). You can sit
## at 0 stars and still be a legendary bank-robber.
##
## It is FED crimes on the same `wanted` hook CrimeReactionDirector uses (call
## record(crime_type, amount) when a crime is logged), and it FEEDS several existing
## systems without owning them: NewsBulletin (pass news_severity_for() as the
## severity arg so headlines are framed by your signature crime), ShopModel /
## ContrabandMarket (multiply prices by shop_price_multiplier() — a feared player is
## gouged), HeistCrew (gate recruitment on hiring_appeal()), and NPC AI / CrowdPanic
## (read fear_level()/intimidates_civilians() to make civilians flinch from a known
## cop-killer). Persists via serialize()/restore() like FactionStanding. Distinct
## from StatTracker (lifetime tallies) — this is a weighted, decaying reputation.
##
## Each category row is {id, name, fear_weight, hire_weight, decay_per_day}. Rows
## with a missing/empty id, or a duplicate id, are dropped at construction.

const MIN_INFAMY: float = 0.0
const MAX_INFAMY: float = 100.0
## Infamy tier thresholds (>=).
const KNOWN_AT: float = 25.0
const NOTORIOUS_AT: float = 55.0
const LEGENDARY_AT: float = 85.0
## fear_level() saturates (reaches 1.0) at this fear-weighted total — tuned so a maxed
## violent-ish signature crime (incl. bank jobs) can register civilian fear, while
## low-menace crimes (car theft, drug dealing) stay non-intimidating even when maxed.
const FEAR_SATURATION: float = 100.0
## hiring_appeal() saturates at this hire-weighted total (serious theft/heist cred).
const HIRE_SATURATION: float = 150.0
## fear_level() at/above which a known criminal intimidates civilians.
const CIVILIAN_FEAR_AT: float = 0.5
## Shop price markup band; full fear adds up to PRICE_FEAR_GAIN on top of 1.0.
const PRICE_MIN_MULT: float = 1.0
const PRICE_MAX_MULT: float = 2.0
const PRICE_FEAR_GAIN: float = 1.0
## Defaults for category rows that omit tuning fields.
const DEFAULT_FEAR_WEIGHT: float = 1.0
const DEFAULT_HIRE_WEIGHT: float = 1.0
const DEFAULT_DECAY_PER_DAY: float = 0.5

## id -> {name, fear_weight, hire_weight, decay_per_day, infamy}. Insertion-ordered.
var _categories: Dictionary = {}


func _init(categories: Array = []) -> void:
	var source: Array = categories if not categories.is_empty() else default_categories()
	for entry: Variant in source:
		_register(entry)


## Built-in rap-sheet categories. fear_weight drives civilian terror + news framing;
## hire_weight drives underworld respect (theft/heist crews); decay_per_day is how
## fast the city forgets that kind of crime.
static func default_categories() -> Array:
	return [
		{
			"id": "cop_killing",
			"name": "Cop-Killer",
			"fear_weight": 1.5,
			"hire_weight": 0.3,
			"decay_per_day": 0.3
		},
		{
			"id": "bank_job",
			"name": "Bank Robber",
			"fear_weight": 0.6,
			"hire_weight": 1.5,
			"decay_per_day": 0.4
		},
		{
			"id": "grand_theft_auto",
			"name": "Car Thief",
			"fear_weight": 0.4,
			"hire_weight": 1.2,
			"decay_per_day": 0.6
		},
		{
			"id": "arson",
			"name": "Arsonist",
			"fear_weight": 1.2,
			"hire_weight": 0.3,
			"decay_per_day": 0.4
		},
		{
			"id": "drug_trafficking",
			"name": "Trafficker",
			"fear_weight": 0.3,
			"hire_weight": 1.0,
			"decay_per_day": 0.7
		},
		{
			"id": "assault",
			"name": "Brawler",
			"fear_weight": 0.5,
			"hire_weight": 0.4,
			"decay_per_day": 0.8
		},
		{
			"id": "kidnapping",
			"name": "Kidnapper",
			"fear_weight": 1.3,
			"hire_weight": 0.5,
			"decay_per_day": 0.35
		},
	]


# --- Catalogue queries ----------------------------------------------------


func category_count() -> int:
	return _categories.size()


func has_category(id: String) -> bool:
	return _categories.has(id)


## Category ids, sorted for deterministic iteration / tie-breaks.
func ids() -> Array:
	var out: Array = _categories.keys()
	out.sort()
	return out


# --- Infamy ----------------------------------------------------------------


## Add infamy for a committed crime of this type (non-positive amounts are ignored),
## clamped to [0, MAX_INFAMY]. Returns the new infamy, or -1.0 for an unknown category.
func record(id: String, amount: float) -> float:
	if not _categories.has(id):
		return -1.0
	if amount > 0.0:
		_categories[id]["infamy"] = clampf(
			float(_categories[id]["infamy"]) + amount, MIN_INFAMY, MAX_INFAMY
		)
	return _categories[id]["infamy"]


## Current infamy for a type (0.0 if unknown).
func infamy_of(id: String) -> float:
	return _categories[id]["infamy"] if _categories.has(id) else 0.0


## Named tier for a category's current infamy. "" for an unknown category.
func tier_of(id: String) -> String:
	if not _categories.has(id):
		return ""
	var infamy: float = _categories[id]["infamy"]
	if infamy >= LEGENDARY_AT:
		return "legendary"
	if infamy >= NOTORIOUS_AT:
		return "notorious"
	if infamy >= KNOWN_AT:
		return "known"
	return "minor"


# --- Aggregate reputation --------------------------------------------------


## Single "how infamous overall" number: sum of infamy * fear_weight.
func notoriety_score() -> float:
	var sum: float = 0.0
	for id: String in _categories:
		sum += float(_categories[id]["infamy"]) * float(_categories[id]["fear_weight"])
	return sum


## Id of the highest-infamy category — your SIGNATURE crime by volume, intentionally
## orthogonal to fear (a prolific car thief is famous, not scary). "" if the sheet is
## clean. Ties break to the alphabetically-first id so the result is stable across runs.
func dominant_category() -> String:
	var best: String = ""
	var best_infamy: float = 0.0
	for id: String in ids():
		var infamy: float = _categories[id]["infamy"]
		if infamy > best_infamy:
			best_infamy = infamy
			best = id
	return best


## Human label for your signature crime at its tier (e.g. "Notorious Cop-Killer") —
## your rap-sheet IDENTITY by volume, distinct from fear_level()/intimidation which
## weight violent crime. "" when the rap sheet is clean.
func reputation_label() -> String:
	var dominant: String = dominant_category()
	if dominant.is_empty():
		return ""
	return "%s %s" % [tier_of(dominant).capitalize(), _categories[dominant]["name"]]


## 0..1 civilian-fear scalar from fear-weighted notoriety (saturates at 1.0).
func fear_level() -> float:
	return clampf(notoriety_score() / FEAR_SATURATION, 0.0, 1.0)


func intimidates_civilians() -> bool:
	return fear_level() >= CIVILIAN_FEAR_AT


## 0..1 underworld-respect scalar from hire-weighted infamy (theft/heist crimes raise
## it; civilian-terror crimes barely do). Gates HeistCrew recruitment willingness.
func hiring_appeal() -> float:
	var sum: float = 0.0
	for id: String in _categories:
		sum += float(_categories[id]["infamy"]) * float(_categories[id]["hire_weight"])
	return clampf(sum / HIRE_SATURATION, 0.0, 1.0)


## Shop price multiplier (>1 when feared — shopkeepers gouge a known maniac), clamped
## to [PRICE_MIN_MULT, PRICE_MAX_MULT]. 1.0 for a clean sheet.
func shop_price_multiplier() -> float:
	return clampf(1.0 + fear_level() * PRICE_FEAR_GAIN, PRICE_MIN_MULT, PRICE_MAX_MULT)


## Severity tier 1..5 for a crime type at its current infamy — pass straight into
## NewsBulletin.report(). 1 for an unknown category.
func news_severity_for(id: String) -> int:
	if not _categories.has(id):
		return 1
	var step: float = MAX_INFAMY / 5.0
	return clampi(1 + int(floor(float(_categories[id]["infamy"]) / step)), 1, 5)


# --- Time / lifecycle ------------------------------------------------------


## Fade every category by its decay_per_day * delta_days. The fade is intentionally
## SLOW — a rap sheet is a long memory (persists across many in-game days), unlike
## wanted heat which zeroes per tick. Non-positive spans are ignored; infamy stays >= 0.
func decay(delta_days: float) -> void:
	if delta_days <= 0.0:
		return
	for id: String in _categories:
		var drop: float = float(_categories[id]["decay_per_day"]) * delta_days
		_categories[id]["infamy"] = maxf(float(_categories[id]["infamy"]) - drop, MIN_INFAMY)


func is_clean() -> bool:
	for id: String in _categories:
		if float(_categories[id]["infamy"]) > 0.0:
			return false
	return true


## Wipe the whole rap sheet (every category back to 0 infamy).
func reset() -> void:
	for id: String in _categories:
		_categories[id]["infamy"] = 0.0


# --- Persistence ----------------------------------------------------------


## {infamy: {id: value}} (ids sorted) for the save system.
func serialize() -> Dictionary:
	var infamy: Dictionary = {}
	for id: String in ids():
		infamy[id] = _categories[id]["infamy"]
	return {"infamy": infamy}


## Rebuild infamy from a serialize() snapshot. Unknown ids dropped, values clamped;
## malformed input leaves a clean (all-zero) sheet.
func restore(data: Dictionary) -> void:
	reset()
	var stored: Variant = data.get("infamy")
	if not (stored is Dictionary):
		return
	var infamy: Dictionary = stored
	for key: Variant in infamy:
		var id: String = str(key)
		if _categories.has(id) and (infamy[key] is float or infamy[key] is int):
			_categories[id]["infamy"] = clampf(float(infamy[key]), MIN_INFAMY, MAX_INFAMY)


# --- Internal -------------------------------------------------------------


## Validate and store one category row; drops malformed (no/empty id) and duplicates.
func _register(entry: Variant) -> void:
	if not (entry is Dictionary):
		return
	var row: Dictionary = entry
	if not row.has("id"):
		return
	var id: String = str(row["id"])
	if id.is_empty() or _categories.has(id):
		return
	_categories[id] = {
		"name": str(row.get("name", id)),
		"fear_weight": maxf(float(row.get("fear_weight", DEFAULT_FEAR_WEIGHT)), 0.0),
		"hire_weight": maxf(float(row.get("hire_weight", DEFAULT_HIRE_WEIGHT)), 0.0),
		"decay_per_day": maxf(float(row.get("decay_per_day", DEFAULT_DECAY_PER_DAY)), 0.0),
		"infamy": 0.0,
	}
