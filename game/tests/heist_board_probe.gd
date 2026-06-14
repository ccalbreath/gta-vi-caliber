extends SceneTree
## Runtime wiring probe for the HeistBoard two-zone loop: casing the joint (Planning
## zone) completes prep that raises the odds; once ready, the Vault zone pulls the
## job — a seeded roll banks the player's cut (PlayerStats) and draws heat, or gets
## them CAUGHT (no take, more heat). Deterministic via seeded RNGs (one seed lands a
## score, one lands a bust). Run:
##   godot --headless --path game --script res://tests/heist_board_probe.gd

const WARMUP_FRAMES: int = 3
const BASE_TAKE: int = 50000
const WIN_SEED: int = 7  # full-prep smart job (~0.95) -> first randf 0.43 -> success
const BUST_SEED: int = 14  # -> first randf 0.996 -> caught

var _board: HeistBoard = null
var _plan_zone: Area3D = null
var _vault_zone: Area3D = null
var _board_b: HeistBoard = null
var _plan_b: Area3D = null
var _vault_b: Area3D = null
var _stats: MockStats = null
var _wanted: MockWanted = null
var _player: StaticBody3D = null
var _frames: int = 0
var _resolved_count: int = 0
var _last_success: bool = false
var _last_take: int = -1
var _last_progress: float = 0.0


class MockStats:
	extends Node
	var money: int = 0

	func _ready() -> void:
		add_to_group("player_stats")

	func add_money(amount: int) -> void:
		money += amount


class MockWanted:
	extends Node
	var crimes: int = 0

	func _ready() -> void:
		add_to_group("wanted")

	func report_crime(_killed: bool) -> void:
		crimes += 1


func _initialize() -> void:
	_stats = MockStats.new()
	root.add_child(_stats)
	_wanted = MockWanted.new()
	root.add_child(_wanted)

	var a := _make_board(WIN_SEED)
	_board = a[0]
	_plan_zone = a[1]
	_vault_zone = a[2]
	var b := _make_board(BUST_SEED)
	_board_b = b[0]
	_plan_b = b[1]
	_vault_b = b[2]

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _make_board(seed_value: int) -> Array:
	var board := HeistBoard.new()
	board.approach = "smart"
	board.base_take = BASE_TAKE
	var plan := Area3D.new()
	plan.name = "Planning"
	board.add_child(plan)
	var vault := Area3D.new()
	vault.name = "Vault"
	board.add_child(vault)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	board.set_rng(rng)
	board.prep_done.connect(_on_prep)
	board.heist_resolved.connect(_on_resolved)
	root.add_child(board)
	return [board, plan, vault]


func _case_fully(plan_zone: Area3D) -> void:
	for _i in 3:  # smart needs 3 preps
		plan_zone.body_entered.emit(_player)


func _on_prep(progress: float) -> void:
	_last_progress = progress


func _on_resolved(success: bool, take: int) -> void:
	_resolved_count += 1
	_last_success = success
	_last_take = take


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _board == null or _vault_zone == null or _board_b == null or _stats == null:
		return _fail("mock tree did not assemble")

	# Group gate + locked vault: a non-player can't case, and the vault won't open
	# before the plan is ready.
	var bystander := StaticBody3D.new()
	root.add_child(bystander)
	_plan_zone.body_entered.emit(bystander)
	_vault_zone.body_entered.emit(_player)
	if _last_progress != 0.0 or _resolved_count != 0 or _board.is_ready():
		return _fail("a non-player cased / the vault opened before the plan was ready")

	# Case the joint, then pull a winning score.
	_case_fully(_plan_zone)
	if not _board.is_ready():
		return _fail("casing did not ready the plan")
	return _run_pull()


func _run_pull() -> bool:
	_vault_zone.body_entered.emit(_player)
	if _resolved_count != 1 or not _last_success or _last_take <= 0:
		return _fail("a fully-cased heist did not come off (success %s)" % _last_success)
	if _stats.money != _last_take or _wanted.crimes < 1:
		return _fail("the score did not pay the cut / draw heat (money %d)" % _stats.money)

	# One score per board: re-entering the vault pulls nothing more.
	_vault_zone.body_entered.emit(_player)
	if _resolved_count != 1 or _stats.money != _last_take:
		return _fail("the vault was pulled a second time")

	return _run_caught(_stats.money, _wanted.crimes)


func _run_caught(money_after_win: int, heat_after_win: int) -> bool:
	# A second, identical job whose seed lands a BUST: it pays nothing and draws
	# even more heat (a blown job is worse).
	_case_fully(_plan_b)
	_vault_b.body_entered.emit(_player)
	if _resolved_count != 2 or _last_success or _last_take != 0:
		return _fail("a blown heist did not resolve as a bust (success %s)" % _last_success)
	if _stats.money != money_after_win:
		return _fail("a caught heist still paid out (money %d)" % _stats.money)
	if _wanted.crimes <= heat_after_win:
		return _fail("a blown heist did not draw extra heat (%d)" % _wanted.crimes)
	return _pass()


func _pass() -> bool:
	print(
		"heist board probe: OK (case -> pull: score banked + heat; a bust pays nothing + more heat)"
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("heist board probe FAIL :: %s" % message)
	print("heist board probe: FAIL — %s" % message)
	quit(1)
	return true
