class_name Bribery
extends RefCounted
## Pure police-bribery model — gamble your way out of a wanted level by greasing a crooked
## official. The going price SCALES with how hot you are (a 5-star manhunt costs far more to
## buy off than a 1-star ping). Put enough on the table and they take it and look the other
## way; come up short and they just wave you off; INSULT them with a lowball and they book you
## instead — so cheaping out can make things worse. Distinct from PaySpray (a safe, fixed-price
## respray) by that risk and the heat-scaled cost. Deterministic, no nodes, no wallet coupling
## (the caller charges PlayerStats and clears/raises the heat). Unit-tested headless
## (tests/unit/test_bribery.gd).

const DEFAULT_BASE_PRICE: int = 1000
const DEFAULT_PRICE_PER_STAR: int = 1500
## An offer below this fraction of the going price is an insult — it backfires.
const DEFAULT_INSULT_FRACTION: float = 0.5

var base_price: int
var price_per_star: int
var insult_fraction: float


func _init(
	base: int = DEFAULT_BASE_PRICE,
	per_star: int = DEFAULT_PRICE_PER_STAR,
	insult: float = DEFAULT_INSULT_FRACTION
) -> void:
	base_price = maxi(base, 0)
	price_per_star = maxi(per_star, 0)
	insult_fraction = clampf(insult, 0.0, 1.0)


## The bribe a crooked official wants to look the other way at this heat level.
func price_for(stars: int) -> int:
	return base_price + price_per_star * maxi(stars, 0)


## Slip the official `offer` while `stars` hot. Returns {outcome, price, spent, reason}:
## "bribed" (offer >= price — they take their PRICE and you walk), "refused" (short but not
## insulting — no effect, no charge), or "backfired" (an insulting lowball — they book you).
func attempt(offer: int, stars: int) -> Dictionary:
	var price := price_for(stars)
	if offer >= price:
		return {"outcome": "bribed", "price": price, "spent": price, "reason": ""}
	if float(offer) >= insult_fraction * float(price):
		return {"outcome": "refused", "price": price, "spent": 0, "reason": "not enough"}
	return {"outcome": "backfired", "price": price, "spent": 0, "reason": "insulting lowball"}
