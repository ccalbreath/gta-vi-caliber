class_name BribeOfficial
extends Area3D
## A crooked official you can try to bribe your way past. Step up while WANTED and they name a
## price scaled by your heat; you slip them `offer_fraction` of it. Put enough on the table and
## they look the other way (your wanted heat CLEARS); come up short and they wave you off (no
## effect); lowball them and they book you (heat goes UP). Reads the live wanted stars, charges
## PlayerStats, and clears/raises the heat — a riskier alternative to a PaySpray respray. Drives
## the tested Bribery model; self-wires by group (player / wanted / player_stats). One attempt
## per visit (debounced); a clean sheet is a no-op. Needs a CollisionShape3D child; watches the
## player's collision layer (2). Verified in tests/bribe_official_probe.gd.

signal bribe_resolved(outcome: String, spent: int)

@export var base_price: int = Bribery.DEFAULT_BASE_PRICE
@export var price_per_star: int = Bribery.DEFAULT_PRICE_PER_STAR
## How much of the going price you put on the table (1.0 = the full ask). Below the model's
## insult line it backfires — so this is the gamble dial a scene/UI drives.
@export_range(0.1, 2.0) var offer_fraction: float = 1.0

var _bribery: Bribery
var _player_inside: bool = false


func _ready() -> void:
	_bribery = Bribery.new(base_price, price_per_star)
	collision_mask |= 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if _player_inside or not body.is_in_group("player"):
		return
	_player_inside = true
	var wanted := get_tree().get_first_node_in_group("wanted")
	if wanted == null or not wanted.has_method("stars"):
		return
	var stars := int(wanted.stars())
	if stars <= 0:
		return  # a clean sheet — nothing to buy your way out of
	var price := _bribery.price_for(stars)
	var offer := int(round(float(price) * offer_fraction))
	_apply(_bribery.attempt(offer, stars), wanted)


## React to the model's verdict: a bribe pays + clears, a backfire raises the heat, a refusal
## does nothing.
func _apply(result: Dictionary, wanted: Node) -> void:
	match String(result["outcome"]):
		"bribed":
			_pay_and_clear(int(result["spent"]), wanted)
		"backfired":
			if wanted.has_method("report_crime"):
				wanted.report_crime(true)
			bribe_resolved.emit("backfired", 0)
		"refused":
			bribe_resolved.emit("refused", 0)
		_:
			push_error("BribeOfficial: unknown bribery outcome '%s'" % String(result["outcome"]))
			bribe_resolved.emit("refused", 0)


## Charge the going price BEFORE clearing the heat, so a wallet that can't cover it falls back
## to a no-op (you never clear your record for free).
func _pay_and_clear(price: int, wanted: Node) -> void:
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats == null or not stats.has_method("spend_money"):
		push_error("BribeOfficial: player_stats not found — no bribe charged")
		bribe_resolved.emit("refused", 0)
		return
	if not stats.spend_money(price):
		bribe_resolved.emit("refused", 0)  # can't afford it -> no clear, no charge
		return
	if wanted.has_method("clear"):
		wanted.clear()
	bribe_resolved.emit("bribed", price)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
