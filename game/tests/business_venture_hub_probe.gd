extends SceneTree
## Runtime wiring + economy probe for the live BusinessVentureHub in miami.tscn.
##
## Boots the real map, asserts the hub is a registered interactable, then drives the
## operate loop against the LIVE player_stats wallet: interact once to ACQUIRE (wallet
## drops, the model owns it), tick the hub so product accrues, interact again to CASH
## OUT (wallet rises). Self-contained — does not touch miami_wiring_probe. Run:
##   godot --headless --path game --script res://tests/business_venture_hub_probe.gd

const SCENE_PATH: String = "res://scenes/world/miami.tscn"
const WARMUP_FRAMES: int = 90
## Real seconds of production to accrue between takeover and cash-out.
const ACCRUE_SECONDS: float = 240.0
## Cash fronted so the probe exercises the buy path, not the can't-afford branch.
const FRONT_MONEY: int = 200000

var _scene: Node = null
var _frames: int = 0


func _initialize() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		push_error("business venture hub probe: scene failed to load")
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
		print("business venture hub probe: OK")
		quit(0)
	else:
		push_error("business venture hub probe FAIL: " + err)
		quit(1)
	return true


func _verify() -> String:
	var hub := _scene.find_child("BusinessVentureHub", true, false) as BusinessVentureHub
	var wiring_err := _verify_wiring(hub)
	if not wiring_err.is_empty():
		return wiring_err
	return _verify_loop(hub)


## The hub is live, owns a model, and is a registered interactable answering the contract.
func _verify_wiring(hub: BusinessVentureHub) -> String:
	if hub == null or hub.venture == null:
		return "BusinessVentureHub / its venture not present in miami.tscn"
	if not hub.is_in_group("interactables"):
		return "hub not in group 'interactables'"
	if not hub.has_method("interact") or not hub.has_method("interact_prompt"):
		return "hub does not answer the interactable contract"
	if hub.owns_business():
		return "hub starts already owned (should acquire on first interact)"
	return ""


## acquire -> accrue -> cash-out round trip against the live wallet must end richer.
func _verify_loop(hub: BusinessVentureHub) -> String:
	var player := get_first_node_in_group("player")
	var stats := get_first_node_in_group("player_stats")
	if player == null or stats == null or not ("money" in stats):
		return "no live player / player_stats node"
	if stats.has_method("add_money"):
		stats.add_money(FRONT_MONEY)

	var money0: int = int(stats.money)
	hub.interact(player)
	if int(stats.money) >= money0 or not hub.owns_business():
		return (
			"acquire did not charge + own (money %d->%d, owns %s)"
			% [money0, int(stats.money), str(hub.owns_business())]
		)

	var after_buy: int = int(stats.money)
	hub.tick(ACCRUE_SECONDS)
	if hub.stockpile() <= 0:
		return "no product accrued after tick (stockpile %d)" % hub.stockpile()

	hub.interact(player)
	if int(stats.money) <= after_buy:
		return "cash-out did not credit wallet (money %d->%d)" % [after_buy, int(stats.money)]
	print(
		(
			"business venture hub probe: acquire %d->%d, cashed out -> %d"
			% [money0, after_buy, int(stats.money)]
		)
	)
	return ""
