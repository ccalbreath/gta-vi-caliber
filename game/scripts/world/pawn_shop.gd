class_name PawnShop
extends Area3D
## A pawn shop — sell an item by HAGGLING, not at a fixed price. The buyer opens low; push for
## more and they concede toward its worth, but lean on them past their patience and they get
## insulted and the offer slides back down. Step in to make the deal: the shop pushes
## `haggle_persistence` times, then takes the offer and banks it to PlayerStats. Squeeze them to
## the peak for the best price; over-play your hand and walk away with less — the peak sits at
## the Haggle model's patience, so MORE pushing isn't always better. Self-wires by group
## (player / player_stats). You bring ONE item, so it sells ONCE (no re-farming the same shop).
## Needs a CollisionShape3D child; watches the player's collision layer (2). Verified in
## tests/pawn_shop_probe.gd.

signal pawned(item_value: int, price: int)

## Worth of the item you brought to pawn, and how hard this deal leans on the buyer (the Haggle
## model peaks at its patience, then declines — so this isn't "bigger is better").
@export var item_value: int = 5000
@export var haggle_persistence: int = 4
@export_range(0.1, 0.95) var opening_fraction: float = Haggle.DEFAULT_OPENING

## True while the player is inside, so one physical visit makes ONE deal even when a compound
## collider emits body_entered several times.
var _player_inside: bool = false
## True once the item has been sold — the shop won't pay again (no walk-in/out re-farming).
var _sold: bool = false


func _ready() -> void:
	collision_mask |= 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if _player_inside or _sold or not body.is_in_group("player"):
		return
	_player_inside = true
	if item_value <= 0:
		return
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats == null or not stats.has_method("add_money"):
		return
	var deal := Haggle.new(item_value, opening_fraction)
	for _i in maxi(haggle_persistence, 0):
		deal.push()
	var price := deal.accept()
	if price <= 0:
		return
	_sold = true
	stats.add_money(price)
	pawned.emit(item_value, price)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
