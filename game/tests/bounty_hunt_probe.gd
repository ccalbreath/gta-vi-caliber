extends SceneTree
## Runtime wiring probe for BountyBoardController + BountyBoard AND the shooting->bounty-hunt
## seam: stepping up to a poster resolves the hunt at the player's live combat rating (a base
## competence lifted by PlayerSkills.bonus("shooting")), banks the bounty to PlayerStats on a
## catch, and leaves the poster up if you're outgunned. The key proof: a tough fugitive ESCAPES
## an untrained hunter but is brought in once you've TRAINED your shooting — closing the last
## gym-skill consumer. Run:
##   godot --headless --path game --script res://tests/bounty_hunt_probe.gd

const WARMUP_FRAMES: int = 3
const EASY: String = "petty_thief"  # difficulty 0.2, bounty 2000
const TOUGH: String = "gang_lieutenant"  # difficulty 0.75, bounty 15000

var _ctrl: BountyBoardController = null
var _skills: PlayerSkillsController = null
var _easy: BountyBoard = null
var _tough: BountyBoard = null
var _stats: MockStats = null
var _player: StaticBody3D = null
var _frames: int = 0
var _last_claim: int = -1
var _escaped_id: String = ""


class MockStats:
	extends Node
	var money: int = 0

	func _ready() -> void:
		add_to_group("player_stats")

	func add_money(amount: int) -> void:
		money += amount


func _initialize() -> void:
	_stats = MockStats.new()
	root.add_child(_stats)
	_skills = PlayerSkillsController.new()
	root.add_child(_skills)

	_ctrl = BountyBoardController.new()
	_ctrl.fugitive_caught.connect(_on_caught)
	root.add_child(_ctrl)

	_easy = _make_board(EASY)
	_tough = _make_board(TOUGH)

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _make_board(id: String) -> BountyBoard:
	var board := BountyBoard.new()
	board.fugitive_id = id
	board.escaped.connect(_on_escaped)
	root.add_child(board)
	return board


func _on_caught(_id: String, bounty: int) -> void:
	_last_claim = bounty


func _on_escaped(id: String) -> void:
	_escaped_id = id


func _visit(board: BountyBoard) -> void:
	_escaped_id = ""  # reset the escape capture per visit
	board.body_entered.emit(_player)
	board.body_exited.emit(_player)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _ctrl == null or _easy == null or _stats == null:
		return _fail("mock tree did not assemble")
	var checks: Array[Callable] = [
		_check_easy_untrained,
		_check_tough_escapes,
		_check_train_and_no_wallet,
		_check_tough_trained,
		_check_recatch
	]
	for check in checks:
		var err: String = check.call()
		if err != "":
			return _fail(err)
	return _pass()


func _check_easy_untrained() -> String:
	# An untrained hunter (rating at the base floor) can still bring in an easy mark.
	var m0 := _stats.money
	_visit(_easy)
	if not _ctrl.is_caught(EASY) or _stats.money != m0 + 2000 or _last_claim != 2000:
		return "an easy fugitive was not caught untrained (money %d)" % _stats.money
	return ""


func _check_tough_escapes() -> String:
	# The tough fugitive outguns an untrained hunter and gets away (poster stays up, no pay).
	var m0 := _stats.money
	_visit(_tough)
	if _ctrl.is_caught(TOUGH) or _stats.money != m0:
		return "a tough fugitive was caught while outgunned"
	if _escaped_id != TOUGH:
		return "an outgunned hunt did not signal the escape"
	return ""


func _check_train_and_no_wallet() -> String:
	# Train shooting so the hunt WOULD land, then prove a missing wallet doesn't consume the catch.
	_skills.train("shooting", 100.0)
	if _ctrl.combat_rating() < _ctrl.difficulty_of(TOUGH):
		return "training shooting did not raise the combat rating (%f)" % _ctrl.combat_rating()
	_stats.remove_from_group("player_stats")
	_visit(_tough)
	var untouched := not _ctrl.is_caught(TOUGH)
	var silent := _escaped_id == ""  # no-wallet is a system no-op, NOT a "they escaped" event
	_stats.add_to_group("player_stats")
	if not untouched:
		return "a catch with no wallet still brought the fugitive in"
	if not silent:
		return "a no-wallet hunt wrongly signalled an escape"
	return ""


func _check_tough_trained() -> String:
	# The seam closed: a trained shooter brings in the fugitive an untrained one couldn't.
	var m0 := _stats.money
	_visit(_tough)
	if not _ctrl.is_caught(TOUGH) or _stats.money != m0 + 15000 or _last_claim != 15000:
		return "a trained shooter did not bring in the tough fugitive (money %d)" % _stats.money
	return ""


func _check_recatch() -> String:
	# A caught fugitive can't be claimed again.
	var m0 := _stats.money
	_visit(_easy)
	if _stats.money != m0:
		return "a caught fugitive paid out again (money %d)" % _stats.money
	return ""


func _pass() -> bool:
	print(
		(
			"bounty hunt probe: OK (an easy mark fell to an untrained hunter, a tough one escaped "
			+ "until shooting was trained, the wallet guard held, no double-claim) — shooting seam closed"
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("bounty hunt probe FAIL :: %s" % message)
	print("bounty hunt probe: FAIL — %s" % message)
	quit(1)
	return true
