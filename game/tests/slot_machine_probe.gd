extends SceneTree
## Runtime wiring probe for the SlotMachine -> PlayerStats casino activity, proven
## through the live node graph in a mock tree (no scene file, like the other
## systems-wiring probes). Deterministic via a seeded RNG.
##
## Asserts: a non-player body is ignored (the group gate); an unaffordable pull is a
## no-op that takes no money (-1); and every affordable pull stakes from the wallet
## and banks EXACTLY the model's payout (money delta == payout - stake), with at
## least one winning pull actually exercised. Physics overlap is the scene author's
## job (a CollisionShape3D child + layer 2); this probe drives the body_entered path
## directly. Run:
##   godot --headless --path game --script res://tests/slot_machine_probe.gd

const WARMUP_FRAMES: int = 3
const STAKE: int = 100
const RICH: int = 1_000_000
const PULLS: int = 200
const RNG_SEED: int = 0x5107

var _machine: SlotMachine = null
var _stats: MockStats = null
var _player: StaticBody3D = null
var _frames: int = 0
var _last_stake: int = 0
var _last_payout: int = -1
var _jackpots: int = 0
var _min_jackpot_payout: int = 1 << 30


class MockStats:
	extends Node
	var money: int = 0

	func _ready() -> void:
		add_to_group("player_stats")

	func add_money(amount: int) -> void:
		money += amount

	func spend_money(amount: int) -> void:
		money -= amount


func _initialize() -> void:
	_stats = MockStats.new()
	root.add_child(_stats)

	_machine = SlotMachine.new()
	_machine.stake = STAKE
	root.add_child(_machine)
	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	_machine.set_rng(rng)
	_machine.pulled.connect(_on_pulled)
	_machine.jackpot.connect(_on_jackpot)

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _on_pulled(_result: Array, stake: int, payout: int) -> void:
	_last_stake = stake
	_last_payout = payout


func _on_jackpot(_symbol: String, payout: int) -> void:
	_jackpots += 1
	_min_jackpot_payout = mini(_min_jackpot_payout, payout)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _machine == null or _stats == null or _player == null:
		return _fail("mock tree did not assemble")

	# Group gate: a non-player body must not spin the reels — and must move no
	# money even when the wallet is flush (so the test isn't masked by the
	# affordability guard).
	var bystander := Node.new()
	root.add_child(bystander)
	_stats.money = RICH
	_machine.body_entered.emit(bystander)
	if _last_payout != -1 or _stats.money != RICH:
		return _fail("a non-player body pulled the machine")

	# Unaffordable: a pull below the stake takes no money and reports a no-op.
	_stats.money = STAKE - 1
	if _machine.pull() != -1 or _stats.money != STAKE - 1:
		return _fail("an unaffordable pull was not a no-op")

	_stats.money = RICH
	return _run_pulls()


func _run_pulls() -> bool:
	var wins: int = 0
	for _i in PULLS:
		var before: int = _stats.money
		_last_payout = -1
		_machine.body_entered.emit(_player)  # one pull
		if _last_payout < 0:
			return _fail("a player pull did not settle")
		var delta: int = _stats.money - before
		if delta != _last_payout - _last_stake:
			return _fail(
				(
					"wallet accounting wrong: delta %d != payout %d - stake %d"
					% [delta, _last_payout, _last_stake]
				)
			)
		if _last_payout > 0:
			wins += 1
	if wins == 0:
		return _fail("no winning pull in %d tries — slot payout not wired to the wallet" % PULLS)
	return _assert_jackpots(wins)


# A jackpot must be a strict subset of wins and must pay more than a partial pair
# (STAKE * 2) — guards _is_jackpot against firing on a non-triple.
func _assert_jackpots(wins: int) -> bool:
	if _jackpots > wins:
		return _fail("more jackpots (%d) than wins (%d)" % [_jackpots, wins])
	if _jackpots > 0 and _min_jackpot_payout <= STAKE * 2:
		return _fail(
			(
				"a jackpot paid only %d (<= partial %d) — _is_jackpot fired on a non-triple"
				% [_min_jackpot_payout, STAKE * 2]
			)
		)
	return _pass(wins)


func _pass(wins: int) -> bool:
	print(
		(
			"slot machine probe: OK (%d/%d won, %d jackpots, wallet accounting exact, gate + guards hold)"
			% [wins, PULLS, _jackpots]
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("slot machine probe FAIL :: %s" % message)
	print("slot machine probe: FAIL — %s" % message)
	quit(1)
	return true
