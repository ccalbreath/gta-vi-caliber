class_name RouletteTable
extends Node3D
## A walk-up roulette table the player can use. Mirrors the storefront Shop
## interactable shape (self-wires into the "interactables" group, exposes
## interact_prompt()/interact()), but drives the unit-tested CasinoGames roulette
## helpers instead of a shop catalogue.
##
## One press = one spin: the fixed bet is debited from the live PlayerStats
## wallet (the guarded spend_money path), the wheel spins via
## CasinoGames.roulette_spin, and CasinoGames.roulette_payout returns the TOTAL
## chips coming back (stake included, 0 on a loss). Any winnings are credited via
## add_money and roulette_played(number_landed, net) fires with the wallet delta
## for this spin (net = payout - bet: +bet on a red win, -bet on a loss).
##
## Outcomes are drawn from a node-owned RandomNumberGenerator so a test can seed
## the table (set_seed) and replay a deterministic run; gameplay leaves it on its
## random default. Asset-agnostic like Shop: just drop it at the table and go.

## Fired after a resolved spin: the pocket the ball landed in and the net change
## to the wallet for this spin (positive on a win, negative on a loss/no-pay).
signal roulette_played(number_landed: int, net: int)

## Chips staked per press (debited up-front; only spins if affordable).
@export var bet_amount: int = 50
## CasinoGames.roulette_payout bet_type — "red" is the fixed colour bet here.
@export var bet_type: String = "red"

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("interactables")


## HUD prompt shown when the player faces the table.
func interact_prompt() -> String:
	return "Play Roulette ($%d on %s)" % [bet_amount, bet_type]


## One press: place the fixed bet, spin, pay any winnings, announce the net.
func interact(_player: Node) -> void:
	var stats := get_tree().get_first_node_in_group("player_stats") as PlayerStats
	if stats == null:
		return
	if not stats.spend_money(bet_amount):
		return
	var number_landed := CasinoGames.roulette_spin(_rng)
	var payout := CasinoGames.roulette_payout(bet_type, number_landed, bet_amount)
	if payout > 0:
		stats.add_money(payout)
	roulette_played.emit(number_landed, payout - bet_amount)


## Seed the wheel's RNG so a test can replay a deterministic sequence of spins.
func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value
