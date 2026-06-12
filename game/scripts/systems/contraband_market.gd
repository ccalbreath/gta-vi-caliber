class_name ContrabandMarket
extends RefCounted
## Pure black-market / contraband trading model — buy goods low in one district and
## sell them high in another, with district price multipliers driving arbitrage and
## carried contraband raising the risk of a bust.
##
## No nodes, no scene access: a world controller owns one, feeds it the player's
## wallet balance on a buy, and applies the returned spend itself — so the price /
## arbitrage / risk curves stay unit-testable headless (tests/unit/test_contraband_market.gd).
##
## Each good is a Dictionary {id, base_price}. Garbage entries (missing id,
## non-int/non-positive price) are dropped at construction. Per-district price comes
## from base_price * a district multiplier: the multiplier is derived from a STABLE
## HASH of the district id (so every district pays a fixed, different rate without a
## hand-maintained table) and can drift over time via fluctuate(). Buys/sells never
## mutate the wallet; the caller applies the result.

## Multiplier band a district's price can sit in: base_price * [MIN, MAX].
const MULTIPLIER_MIN: float = 0.6
const MULTIPLIER_MAX: float = 1.6

## How far a single fluctuate() step may nudge a multiplier (scaled by volatility).
const FLUCTUATE_SWING: float = 0.25

## id -> base_price (int > 0). Built once in _init, insertion-ordered.
var _goods: Dictionary = {}

## district_id -> multiplier (float). Lazily seeded from the stable hash the first
## time a district is priced, then mutated by fluctuate().
var _multipliers: Dictionary = {}

## good -> qty (int >= 0) the player is physically carrying. Contraband on you.
var _carried: Dictionary = {}


func _init(goods: Array = []) -> void:
	var source: Array = goods if not goods.is_empty() else default_goods()
	for entry: Variant in source:
		_register(entry)


## The built-in stock used when an empty list is passed: a few classic contraband
## goods with base prices in the game's money units.
static func default_goods() -> Array:
	return [
		{"id": "cash", "base_price": 100},
		{"id": "jewelry", "base_price": 2500},
		{"id": "electronics", "base_price": 800},
		{"id": "product", "base_price": 1500},
	]


func goods_count() -> int:
	return _goods.size()


## True if the good id exists in the catalogue.
func has_good(good: String) -> bool:
	return _goods.has(good)


## Base (district-neutral) price of a good, or -1 if the id is unknown.
func base_price(good: String) -> int:
	if not _goods.has(good):
		return -1
	return _goods[good]


## Stable per-district multiplier in [MULTIPLIER_MIN, MULTIPLIER_MAX], derived once
## from a hash of the district id (different districts pay different rates) and then
## kept/mutated in _multipliers. Empty district ids fall back to 1.0.
func multiplier_for(district_id: String) -> float:
	if district_id.is_empty():
		return 1.0
	if not _multipliers.has(district_id):
		_multipliers[district_id] = _seed_multiplier(district_id)
	return _multipliers[district_id]


## The price of a good in a district: base_price * the district multiplier, rounded
## to whole currency. Unknown good returns -1.
func price_in(good: String, district_id: String) -> int:
	var base := base_price(good)
	if base < 0:
		return -1
	return int(round(float(base) * multiplier_for(district_id)))


## Resolve a buy against a wallet balance. Never mutates the wallet: the caller
## applies new_balance on success. Fails on unknown good, non-positive qty, or
## insufficient funds. Returns {success, cost, new_balance, reason}.
func buy(good: String, qty: int, district_id: String, balance: int) -> Dictionary:
	if not _goods.has(good):
		return _fail(balance, "unknown good: %s" % good)
	if qty <= 0:
		return _fail(balance, "qty must be positive: %d" % qty)
	var cost := price_in(good, district_id) * qty
	if balance < cost:
		return _fail(balance, "insufficient funds: need %d, have %d" % [cost, balance])
	return {"success": true, "cost": cost, "new_balance": balance - cost, "reason": ""}


## Revenue from selling qty of a good in a district. Unknown good / non-positive
## qty yield 0.
func sell(good: String, qty: int, district_id: String) -> int:
	if not _goods.has(good) or qty <= 0:
		return 0
	return price_in(good, district_id) * qty


## Of the supplied districts, which one pays the most for a good. Returns "" for an
## unknown good or an empty list; a single district is returned as-is.
func best_market(good: String, district_ids: Array) -> String:
	if not _goods.has(good) or district_ids.is_empty():
		return ""
	var best_id: String = ""
	var best_price: int = -1
	for raw: Variant in district_ids:
		var district_id: String = str(raw)
		var p := price_in(good, district_id)
		if p > best_price:
			best_price = p
			best_id = district_id
	return best_id


## Arbitrage profit from buying qty in buy_district and selling it in sell_district.
## Can be negative (a bad route). 0 for unknown good or non-positive qty.
func profit(good: String, buy_district: String, sell_district: String, qty: int) -> int:
	if not _goods.has(good) or qty <= 0:
		return 0
	var spend := price_in(good, buy_district) * qty
	var revenue := price_in(good, sell_district) * qty
	return revenue - spend


## Add contraband to what the player is carrying. Negative / non-positive qty and
## unknown goods are no-ops.
func carry(good: String, qty: int) -> void:
	if not _goods.has(good) or qty <= 0:
		return
	_carried[good] = carried(good) + qty


## How much of a good the player is currently carrying (0 if none / unknown).
func carried(good: String) -> int:
	return _carried.get(good, 0)


## Remove carried contraband (e.g. sold or ditched), floored at 0 so it never goes
## negative. Non-positive qty and unknown goods are no-ops.
func drop(good: String, qty: int) -> void:
	if not _goods.has(good) or qty <= 0:
		return
	_carried[good] = maxi(carried(good) - qty, 0)


## Total units of all contraband on the player right now.
func total_carried() -> int:
	var sum := 0
	for good: Variant in _carried:
		sum += _carried[good]
	return sum


## Bust risk if the player is stopped: base_risk plus a load penalty that grows
## with how much contraband they carry, clamped to [0, 1]. More on you = more likely
## the stop turns into a wanted bust.
func bust_risk(total: int, base_risk: float) -> float:
	if total <= 0:
		return clampf(base_risk, 0.0, 1.0)
	var load_penalty := float(total) * 0.05
	return clampf(base_risk + load_penalty, 0.0, 1.0)


## Nudge every known district's multiplier a little so prices drift over time.
## Deterministic for a given rng seed: same seed + volatility => same drift.
## Multipliers stay clamped to [MULTIPLIER_MIN, MULTIPLIER_MAX]. No-op without an rng.
func fluctuate(rng: RandomNumberGenerator, volatility: float) -> void:
	if rng == null or volatility <= 0.0:
		return
	var swing := FLUCTUATE_SWING * volatility
	for district_id: Variant in _multipliers:
		var delta := rng.randf_range(-swing, swing)
		var nudged: float = _multipliers[district_id] + delta
		_multipliers[district_id] = clampf(nudged, MULTIPLIER_MIN, MULTIPLIER_MAX)


## Deterministic-test helper: a fresh rng seeded with `seed_value`.
static func make_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _fail(balance: int, reason: String) -> Dictionary:
	return {"success": false, "cost": 0, "new_balance": balance, "reason": reason}


## Map a district id's stable hash onto the multiplier band so each district gets a
## fixed, distinct rate without a hand-maintained table.
func _seed_multiplier(district_id: String) -> float:
	var h := hash(district_id)
	var frac := float(absi(h) % 1000) / 1000.0
	return MULTIPLIER_MIN + frac * (MULTIPLIER_MAX - MULTIPLIER_MIN)


## Validate and store one {id, base_price} entry; silently drops malformed rows so a
## bad good can't crash the market.
func _register(entry: Variant) -> void:
	if typeof(entry) != TYPE_DICTIONARY:
		return
	var dict: Dictionary = entry
	if not (dict.has("id") and dict.has("base_price")):
		return
	var id: Variant = dict["id"]
	var price: Variant = dict["base_price"]
	if not (id is String) or (id as String).is_empty() or _goods.has(id):
		return
	if not (price is int) or price <= 0:
		return
	_goods[id] = price
