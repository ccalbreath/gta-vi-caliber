extends SceneTree
## Runtime wiring probe for the TrainingZone gym loop: stepping in trains the skill
## it teaches (raising the shared PlayerSkillsController level), a rest cooldown
## blocks an immediate re-train, and a later session adds LESS (diminishing returns
## toward mastery). Drives the cooldown clock manually. Run:
##   godot --headless --path game --script res://tests/training_zone_probe.gd

const WARMUP_FRAMES: int = 3
const SKILL: String = "strength"
const REST: float = 20.0

var _ctl: PlayerSkillsController = null
var _zone: TrainingZone = null
var _bad_zone: TrainingZone = null
var _player: StaticBody3D = null
var _frames: int = 0
var _trained_count: int = 0


func _initialize() -> void:
	_ctl = PlayerSkillsController.new()
	root.add_child(_ctl)

	_zone = TrainingZone.new()
	_zone.skill_id = SKILL
	_zone.session_effort = 1.0
	_zone.rest_seconds = REST
	_zone.trained.connect(_on_trained)
	root.add_child(_zone)

	# A zone aimed at a non-existent skill — trains nothing, never locks its cooldown.
	_bad_zone = TrainingZone.new()
	_bad_zone.skill_id = "not_a_real_skill"
	root.add_child(_bad_zone)

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _on_trained(_skill_id: String, _level: float) -> void:
	_trained_count += 1


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _ctl == null or _zone == null or _player == null:
		return _fail("mock tree did not assemble")
	_zone.set_process(false)  # drive the rest cooldown manually

	# Group gate: a non-player can't train.
	var bystander := StaticBody3D.new()
	root.add_child(bystander)
	_zone.body_entered.emit(bystander)
	if _ctl.level(SKILL) != 0.0 or _trained_count != 0:
		return _fail("a non-player trained the skill")

	# An unknown skill id is a no-op that never arms the cooldown (no silent lock).
	_bad_zone.body_entered.emit(_player)
	if _bad_zone.rest_remaining() > 0.0:
		return _fail("a zone with an unknown skill locked its cooldown")

	# First session: the skill climbs from zero.
	_zone.body_entered.emit(_player)
	var level1 := _ctl.level(SKILL)
	if level1 <= 0.0 or _trained_count != 1:
		return _fail("a training session did not raise the skill (%.3f)" % level1)

	# Still resting: an immediate re-entry trains nothing.
	_zone.body_entered.emit(_player)
	if _ctl.level(SKILL) != level1 or _trained_count != 1:
		return _fail("trained again before the rest cooldown elapsed")

	return _run_more(level1)


func _run_more(level1: float) -> bool:
	# Rest, then train again: it rises further but by LESS (diminishing returns).
	_zone._process(REST + 1.0)
	_zone.body_entered.emit(_player)
	var level2 := _ctl.level(SKILL)
	if level2 <= level1 or _trained_count != 2:
		return _fail("a second session after resting did not raise the skill")
	var gain1 := level1
	var gain2 := level2 - level1
	if gain2 >= gain1:
		return _fail("training did not show diminishing returns (%.4f >= %.4f)" % [gain2, gain1])
	return _pass(level2)


func _pass(level2: float) -> bool:
	print(
		(
			"training zone probe: OK (train raises skill to %.3f; cooldown gates spam; gains diminish)"
			% level2
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("training zone probe FAIL :: %s" % message)
	print("training zone probe: FAIL — %s" % message)
	quit(1)
	return true
