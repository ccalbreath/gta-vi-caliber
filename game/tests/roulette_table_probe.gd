extends SceneTree
## Runtime wiring + economy probe for the live RouletteTable in miami.tscn.
##
## Boots the real map, asserts the table is present and registered as an
## interactable (so the player can walk up and press to play), seeds its wheel
## for a deterministic run, tops up the LIVE player_stats wallet so the bets are
## affordable, then drives ~12 spins through interact(). Each spin emits
## roulette_played(number, net); the probe sums the emitted nets and asserts the
## wallet moved by exactly that sum — proving the bet debit and any winnings flow
## through the real wallet with no leakage. Self-contained. Run headless:
##   godot --headless --path game --script res://tests/roulette_table_probe.gd

const SCENE_PATH: String = "res://scenes/world/miami.tscn"
const WARMUP_FRAMES: int = 90
const SPIN_COUNT: int = 12
const SEED_VALUE: int = 20260613
## Big top-up so a string of losses can never make a bet unaffordable mid-run.
const WALLET_TOPUP: int = 1_000_000

var _scene: Node = null
var _frames: int = 0
var _nets: Array[int] = []


func _initialize() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		push_error("roulette table probe: scene failed to load")
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
		print("roulette table probe: OK (%d spins, net sum %d)" % [SPIN_COUNT, _sum_nets()])
		quit(0)
	else:
		push_error("roulette table probe FAIL: " + err)
		quit(1)
	return true


func _verify() -> String:
	var table := _scene.find_child("RouletteTable", true, false) as RouletteTable
	if table == null:
		return "RouletteTable not present in miami.tscn"
	if not table.is_in_group("interactables"):
		return "RouletteTable not registered as an interactable"
	var stats := get_first_node_in_group("player_stats") as PlayerStats
	var player := get_first_node_in_group("player")
	if stats == null or player == null:
		return "no live player / player_stats node"
	return _run_loop(table, stats, player)


## Seed the wheel, top up the wallet, run the spins, and assert the wallet moved
## by exactly the sum of the emitted per-spin nets.
func _run_loop(table: RouletteTable, stats: PlayerStats, player: Node) -> String:
	table.set_seed(SEED_VALUE)
	table.roulette_played.connect(_on_played)
	stats.add_money(WALLET_TOPUP)
	var money_before: int = int(stats.money)
	for _i in SPIN_COUNT:
		table.interact(player)
	if _nets.size() != SPIN_COUNT:
		return "expected %d spins, got %d" % [SPIN_COUNT, _nets.size()]
	var expected: int = money_before + _sum_nets()
	if int(stats.money) != expected:
		return "wallet drift: expected %d, got %d" % [expected, int(stats.money)]
	return ""


func _on_played(_number_landed: int, net: int) -> void:
	_nets.append(net)


func _sum_nets() -> int:
	var total: int = 0
	for net in _nets:
		total += net
	return total
