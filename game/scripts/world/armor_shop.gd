class_name ArmorShop
extends Area3D
## A drive-up body-armor vendor: enter while you can afford it and aren't already
## fully armored to buy a vest — charged via PlayerStats and topping armor to
## full. Consumes the tested ShopModel and self-wires by group (player /
## player_stats). Needs a CollisionShape3D child; watches the player layer (2).

signal armor_bought(cost: int)

## ShopModel catalogue id to sell (default body_armor @ $1000).
@export var item_id: String = "body_armor"
## Armor points granted per purchase (clamped to PlayerStats.max_armor).
@export var armor_per_buy: float = 100.0

var _shop: ShopModel


func _ready() -> void:
	_shop = ShopModel.new()
	add_to_group("armor_shop")
	collision_mask |= 2
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats == null or not ("money" in stats):
		return
	# Already topped up — don't charge for armor you can't carry.
	if "armor" in stats and "max_armor" in stats and float(stats.armor) >= float(stats.max_armor):
		return
	var result := _shop.purchase(item_id, int(stats.money))
	if not result.get("success", false):
		return
	if stats.has_method("spend_money"):
		stats.spend_money(int(result["cost"]))
	if stats.has_method("add_armor"):
		stats.add_armor(armor_per_buy)
	armor_bought.emit(int(result["cost"]))
