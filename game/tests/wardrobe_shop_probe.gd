extends SceneTree
## Runtime wiring + economy probe for the live WardrobeShop in miami.tscn.
##
## Boots the real map, asserts the clothing store is a live interactable (in group
## "interactables" with an interact method), then drives interact() against the LIVE
## player_stats wallet and asserts the purchase charged the wallet AND the outfit is
## now owned + worn in its Wardrobe model. Guards the walk-up wardrobe wiring. Run:
##   godot --headless --path game --script res://tests/wardrobe_shop_probe.gd

const SCENE_PATH: String = "res://scenes/world/miami.tscn"
const WARMUP_FRAMES: int = 90

var _scene: Node = null
var _frames: int = 0


func _initialize() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		push_error("wardrobe shop probe: scene failed to load")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	var err := _verify()
	if err.is_empty():
		print("wardrobe shop probe: OK")
		quit(0)
	else:
		push_error("wardrobe shop probe FAIL: " + err)
		quit(1)
	return true


func _verify() -> String:
	var shop := _scene.find_child("WardrobeShop", true, false) as WardrobeShop
	var wiring_err := _verify_wiring(shop)
	if not wiring_err.is_empty():
		return wiring_err
	return _verify_purchase(shop)


## The node is live, joined the interactables group, and answers the contract.
func _verify_wiring(shop: WardrobeShop) -> String:
	if shop == null:
		return "WardrobeShop not present in miami.tscn"
	if not shop.is_in_group("interactables"):
		return "WardrobeShop not in group 'interactables'"
	if not shop.has_method("interact") or not shop.has_method("interact_prompt"):
		return "WardrobeShop missing interact/interact_prompt"
	return ""


## interact() must charge the wallet and own + wear the outfit in the model.
func _verify_purchase(shop: WardrobeShop) -> String:
	var player := get_first_node_in_group("player")
	var stats := get_first_node_in_group("player_stats")
	if player == null or stats == null or not ("money" in stats):
		return "no live player / player_stats node"
	var wardrobe: Wardrobe = shop._wardrobe
	var item: String = shop.item_id
	if wardrobe == null or not wardrobe.has_item(item):
		return "shop has no wardrobe / unknown item_id '%s'" % item
	var price: int = wardrobe.price_of(item)
	if int(stats.money) < price:
		stats.add_money(price)
	var money0: int = int(stats.money)
	shop.interact(player)
	if (
		int(stats.money) != money0 - price
		or not wardrobe.owns(item)
		or wardrobe.worn_in(wardrobe.slot_of(item)) != item
	):
		return (
			"purchase did not charge+own+wear (money %d->%d price %d owns=%s worn=%s)"
			% [
				money0,
				int(stats.money),
				price,
				str(wardrobe.owns(item)),
				wardrobe.worn_in(wardrobe.slot_of(item)),
			]
		)
	print(
		(
			"wardrobe shop probe: bought '%s' for $%d (%d -> %d)"
			% [item, price, money0, int(stats.money)]
		)
	)
	return ""
