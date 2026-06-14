extends SceneTree
## Runtime wiring + economy probe for the live HeistPlanningBoard in miami.tscn.
##
## Boots the real map, asserts the board is a registered interactable, then drives the
## plan-the-job loop against the LIVE player_stats wallet: interact once per crew member
## to RECRUIT (wallet drops by recruit_cost each time, crew grows), confirm the crew
## reads ready, then interact again to PULL THE JOB. The run is tuned so the seeded
## attempt deterministically SUCCEEDS (success_chance clamps to 1.0), so the player's
## share of the take must land in the wallet. Self-contained. Run:
##   godot --headless --path game --script res://tests/heist_planning_board_probe.gd

const SCENE_PATH: String = "res://scenes/world/miami.tscn"
const WARMUP_FRAMES: int = 90
## Seed for a deterministic attempt roll.
const SEED_VALUE: int = 1337
## Difficulty that lifts the default crew's success_chance to a clamped 1.0 win.
const SURE_THING_DIFFICULTY: float = 0.95
## Cash fronted so recruiting exercises the hire path, not the can't-afford branch.
const FRONT_MONEY: int = 200000

var _scene: Node = null
var _frames: int = 0


func _initialize() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		push_error("heist planning board probe: scene failed to load")
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
		print("heist planning board probe: OK")
		quit(0)
	else:
		push_error("heist planning board probe FAIL: " + err)
		quit(1)
	return true


func _verify() -> String:
	var board := _scene.find_child("HeistPlanningBoard", true, false) as HeistPlanningBoard
	if board == null:
		return "HeistPlanningBoard not present in miami.tscn"
	var wiring_err := _verify_wiring(board)
	if not wiring_err.is_empty():
		return wiring_err
	return _verify_loop(board)


## The board is live, owns a crew, and is a registered interactable answering the contract.
func _verify_wiring(board: HeistPlanningBoard) -> String:
	if board.crew == null:
		return "HeistPlanningBoard / its crew not present in miami.tscn"
	if not board.is_in_group("interactables"):
		return "board not in group 'interactables'"
	if not board.has_method("interact") or not board.has_method("interact_prompt"):
		return "board does not answer the interactable contract"
	if board.is_ready() or board.crew_size() != 0:
		return "board starts already staffed (should recruit before it is ready)"
	return ""


## recruit-each-member -> ready -> pull-the-job round trip; the seeded win must pay out.
func _verify_loop(board: HeistPlanningBoard) -> String:
	var player := get_first_node_in_group("player")
	var stats := get_first_node_in_group("player_stats")
	if player == null or stats == null or not ("money" in stats):
		return "no live player / player_stats node"
	if stats.has_method("add_money"):
		stats.add_money(FRONT_MONEY)
	board.set_seed(SEED_VALUE)
	board.base_difficulty = SURE_THING_DIFFICULTY

	var recruit_err := _verify_recruiting(board, stats)
	if not recruit_err.is_empty():
		return recruit_err
	return _verify_attempt(board, player, stats)


## Each press hires one member, debiting recruit_cost and growing the crew, until ready.
func _verify_recruiting(board: HeistPlanningBoard, stats: Node) -> String:
	var target: int = board.crew_specs.size()
	for hired in range(target):
		var before: int = int(stats.money)
		var size_before: int = board.crew_size()
		board.interact(null)
		if int(stats.money) != before - board.recruit_cost:
			return (
				"recruit %d did not charge recruit_cost (money %d->%d)"
				% [hired + 1, before, int(stats.money)]
			)
		if board.crew_size() != size_before + 1:
			return "recruit %d did not grow the crew (size %d)" % [hired + 1, board.crew_size()]
	if not board.is_ready():
		return "crew not ready after staffing %d members" % target
	return ""


## A staffed press pulls the job; the seeded sure-thing win must bank the player's share.
func _verify_attempt(board: HeistPlanningBoard, player: Node, stats: Node) -> String:
	var resolved := {"fired": false, "success": false, "paid": 0}
	board.heist_resolved.connect(
		func(success: bool, take_paid: int) -> void:
			resolved["fired"] = true
			resolved["success"] = success
			resolved["paid"] = take_paid
	)
	var before: int = int(stats.money)
	board.interact(player)
	if not resolved["fired"]:
		return "heist_resolved did not fire on the staffed press"
	if not resolved["success"]:
		return "seeded sure-thing attempt did not succeed"
	var paid: int = int(resolved["paid"])
	if paid <= 0 or int(stats.money) != before + paid:
		return (
			"win did not bank the share (money %d->%d, paid %d)" % [before, int(stats.money), paid]
		)
	print(
		(
			"heist planning board probe: staffed crew, won -> +%d (money %d->%d)"
			% [paid, before, int(stats.money)]
		)
	)
	return ""
