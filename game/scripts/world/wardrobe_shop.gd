class_name WardrobeShop
extends Node3D
## A walk-up clothing store: face it, press interact, and buy a new outfit. Owns a
## tested Wardrobe model (buy/own/wear), charges the wallet through PlayerStats, and
## wears the purchase so its look feeds Disguise — a fresh outfit helps shed wanted
## heat. Answers the "interactables" contract like Shop/BuildingDoor, so it self-wires
## by group and needs no plumbing beyond dropping the node at a storefront.

signal clothing_bought(item_id: String, cost: int)
signal disguise_updated(looks: Dictionary)

## Wardrobe catalogue id to sell — must exist in the model's default catalogue.
@export var item_id: String = "sharp_suit"
## Storefront label shown in the interact prompt.
@export var shop_name: String = "Clothing Store"

var _wardrobe: Wardrobe
var _disguise: Node = null


func _ready() -> void:
	add_to_group("interactables")
	_wardrobe = Wardrobe.new()
	call_deferred("_push_worn_looks")


func interact_prompt() -> String:
	return shop_name


## Buy + wear the outfit on purpose: guards on funds and ownership, charges the
## wallet only when the model confirms the sale, then wears it so the look applies.
func interact(_player: Node) -> void:
	var stats := get_tree().get_first_node_in_group("player_stats") as PlayerStats
	if stats == null or _wardrobe == null or not _wardrobe.has_item(item_id):
		return
	var result := _wardrobe.buy(item_id, stats.money)
	if not result.get("success", false):
		return
	var cost := int(result["cost"])
	# Free items still bank a real sale; only a positive price needs the wallet.
	if cost > 0 and not stats.spend_money(cost):
		return
	_wardrobe.wear(item_id)
	_push_worn_looks()
	clothing_bought.emit(item_id, cost)


func _push_worn_looks() -> void:
	if _wardrobe == null:
		return
	var tracker := _disguise_tracker()
	if tracker == null or not tracker.has_method("apply_looks"):
		return
	var looks := _wardrobe.worn_looks()
	tracker.apply_looks(looks)
	disguise_updated.emit(looks)


func _disguise_tracker() -> Node:
	if _disguise == null or not is_instance_valid(_disguise):
		_disguise = get_tree().get_first_node_in_group("player_disguise")
	return _disguise
