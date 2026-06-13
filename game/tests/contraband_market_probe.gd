extends SceneTree
## Runtime wiring + economy probe for the live ContrabandDealer in miami.tscn.
##
## Boots the real map, asserts the dealer is present and its two trade zones are
## self-wired (body_entered connected), then drives the buy -> carry -> sell loop
## against the LIVE player_stats wallet and asserts the round trip turns a profit
## (the deal and fence districts must price the good differently, or the arbitrage
## is pointless). Self-contained so it does not touch miami_wiring_probe. Run:
##   godot --headless --path game --script res://tests/contraband_market_probe.gd

const SCENE_PATH: String = "res://scenes/world/miami.tscn"
const WARMUP_FRAMES: int = 90

var _scene: Node = null
var _frames: int = 0


func _initialize() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		push_error("contraband probe: scene failed to load")
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
		print("contraband market probe: OK")
		quit(0)
	else:
		push_error("contraband market probe FAIL: " + err)
		quit(1)
	return true


func _verify() -> String:
	var dealer := _scene.find_child("ContrabandDealer", true, false) as ContrabandDealer
	var wiring_err := _verify_wiring(dealer)
	if not wiring_err.is_empty():
		return wiring_err
	return _verify_loop(dealer)


## Dealer node is live in the scene and both trade zones self-wired their handlers.
func _verify_wiring(dealer: ContrabandDealer) -> String:
	if dealer == null:
		return "ContrabandDealer not present in miami.tscn"
	if dealer.market == null:
		return "dealer.market is null"
	var deal_zone := dealer.get_node_or_null("DealZone") as Area3D
	var fence_zone := dealer.get_node_or_null("FenceZone") as Area3D
	if deal_zone == null or fence_zone == null:
		return "DealZone/FenceZone missing"
	if not deal_zone.body_entered.is_connected(dealer._on_deal_entered):
		return "DealZone.body_entered not wired"
	if not fence_zone.body_entered.is_connected(dealer._on_fence_entered):
		return "FenceZone.body_entered not wired"
	return ""


## The buy -> carry -> sell round trip against the live wallet must net a profit.
func _verify_loop(dealer: ContrabandDealer) -> String:
	var player := get_first_node_in_group("player")
	var stats := get_first_node_in_group("player_stats")
	if player == null or stats == null:
		return "no live player / player_stats node"

	var good: String = dealer.good_id
	print(
		(
			"contraband probe: %s deal(%s)=%d fence(%s)=%d"
			% [
				good,
				dealer.deal_district,
				dealer.market.price_in(good, dealer.deal_district),
				dealer.fence_district,
				dealer.market.price_in(good, dealer.fence_district),
			]
		)
	)

	var money0: int = int(stats.money)
	dealer._on_deal_entered(player)
	if int(stats.money) >= money0 or dealer.market.carried(good) <= 0:
		return (
			"buy did not spend + stock (money %d->%d, carried %d)"
			% [money0, int(stats.money), dealer.market.carried(good)]
		)

	var after_buy: int = int(stats.money)
	dealer._on_fence_entered(player)
	if int(stats.money) <= after_buy or dealer.market.carried(good) != 0:
		return (
			"fence did not pay + clear (money %d->%d, carried %d)"
			% [after_buy, int(stats.money), dealer.market.carried(good)]
		)

	var final_money: int = int(stats.money)
	if final_money <= money0:
		return "round trip not profitable: %d -> %d" % [money0, final_money]

	print(
		(
			"contraband market probe: profit %d -> %d (+%d)"
			% [money0, final_money, final_money - money0]
		)
	)
	return ""
