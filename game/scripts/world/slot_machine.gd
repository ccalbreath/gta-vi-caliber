class_name SlotMachine
extends Area3D
## A walk-up slot machine — step into the zone and pull once: it stakes `stake`
## from your wallet, spins the reels, and pays any win straight back through
## PlayerStats. The casino floor's simplest playable activity. Consumes the tested
## CasinoGames slot math (slot_spin / slot_payout) and self-wires by group (player /
## player_stats). Needs a CollisionShape3D child; watches the player layer (2).
##
## Each entry is ONE pull (step out and back in to pull again). Outcomes use a live
## RandomNumberGenerator; inject a seeded one with set_rng() for deterministic
## events or tests. Verified headless in tests/slot_machine_probe.gd.

## Reels show three-of-a-kind (pays by symbol) or any matching pair (a flat
## partial), else nothing — see CasinoGames.slot_payout.
signal pulled(result: Array, stake: int, payout: int)
signal jackpot(symbol: String, payout: int)

## Chips staked per pull, drawn from the player's wallet.
@export var stake: int = 100
## Number of reels to spin.
@export var reels: int = 3

var _rng: RandomNumberGenerator


func _ready() -> void:
	# Preserve an RNG injected via set_rng() before _ready (e.g. a seeded one in a
	# probe); only fall back to a live randomized one when none was supplied.
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	add_to_group("slot_machine")
	collision_mask |= 2
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		pull()


## Pull once: stake from the wallet, spin, bank any win. Returns the payout (total
## chips returned, 0 on a loss), or -1 as a no-op when the player can't be charged
## AND paid or can't afford the stake — so a pull never takes money it can't return
## winnings against.
func pull() -> int:
	if _rng == null:
		return -1
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats == null or not ("money" in stats):
		return -1
	if not stats.has_method("spend_money") or not stats.has_method("add_money"):
		return -1
	if stake <= 0 or int(stats.money) < stake:
		return -1
	stats.spend_money(stake)
	var result := CasinoGames.slot_spin(_rng, reels)
	var payout := CasinoGames.slot_payout(result, stake)
	if payout > 0:
		stats.add_money(payout)
	pulled.emit(result, stake, payout)
	if _is_jackpot(result):
		jackpot.emit(result[0] as String, payout)
	return payout


## A true three-of-a-kind that pays the triple rate: at least 3 reels all showing
## the same symbol, and that symbol is in the triple-payout table (so a 2-reel pair
## or an unknown symbol never reads as a jackpot).
func _is_jackpot(result: Array) -> bool:
	if result.size() < 3:
		return false
	for symbol: Variant in result:
		if symbol != result[0]:
			return false
	return CasinoGames.SLOT_TRIPLE_MULT.has(result[0])


## Inject a seeded RNG for deterministic outcomes (tests / fixed-odds events).
func set_rng(rng: RandomNumberGenerator) -> void:
	if rng != null:
		_rng = rng
