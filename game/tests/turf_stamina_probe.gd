extends SceneTree
## Runtime probe for the STAMINA -> turf-capture closure: a fitter player sustains the
## pressure and contests turf FASTER, so a maxed PlayerSkills.bonus("stamina") scales
## TurfZone's influence accrual. Holds one rival district and compares the influence gained
## per identical tick before vs after training stamina (neither tick reaches a capture, so
## it's a clean rate comparison). Run:
##   godot --headless --path game --script res://tests/turf_stamina_probe.gd

const WARMUP_FRAMES: int = 3
const DISTRICT: String = "downtown"
const RATE: float = 0.2
const DT: float = 1.0

var _ctl: GangTerritoryController = null
var _skills: PlayerSkillsController = null
var _zone: TurfZone = null
var _player: StaticBody3D = null
var _frames: int = 0


func _initialize() -> void:
	_ctl = GangTerritoryController.new()
	root.add_child(_ctl)

	_skills = PlayerSkillsController.new()
	root.add_child(_skills)

	_zone = TurfZone.new()
	_zone.district_id = DISTRICT
	_zone.capture_rate = RATE
	root.add_child(_zone)
	_zone.set_process(false)  # accrual is driven manually + deterministically

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _ctl == null or _zone == null or _skills == null:
		return _fail("mock tree did not assemble")
	var territory: GangTerritory = _ctl.territory()
	var rival := territory.owner_of(DISTRICT)
	if rival == "" or rival == GangTerritory.PLAYER_OWNER:
		return _fail("district is not held by a rival at start")
	var err := _check_stamina_speeds_capture(territory)
	if err != "":
		return _fail(err)
	return _pass()


func _check_stamina_speeds_capture(territory: GangTerritory) -> String:
	_zone.body_entered.emit(_player)  # the player holds the zone
	# Unfit: with a zero stamina bonus, one tick accrues exactly the base rate. (Assert the
	# zero baseline explicitly so a future PlayerSkills "baseline fitness" change fails loud.)
	var before_unfit := territory.influence_in(DISTRICT)
	_zone._process(DT)
	var delta_unfit := territory.influence_in(DISTRICT) - before_unfit
	if (
		not is_equal_approx(_skills.bonus("stamina"), 0.0)
		or not is_equal_approx(delta_unfit, RATE * DT)
	):
		return (
			"unfit baseline wrong: stamina bonus %f, accrual %f (want 0 and %f)"
			% [_skills.bonus("stamina"), delta_unfit, RATE * DT]
		)
	# Train STAMINA, then an identical tick accrues FASTER (still no capture).
	_skills.train("stamina", 100.0)
	var bonus := _skills.bonus("stamina")
	var before_fit := territory.influence_in(DISTRICT)
	_zone._process(DT)
	var delta_fit := territory.influence_in(DISTRICT) - before_fit
	if bonus <= 0.0 or delta_fit <= delta_unfit:
		return (
			"training stamina did not speed up the capture (bonus %f, %f vs %f)"
			% [bonus, delta_fit, delta_unfit]
		)
	if territory.owner_of(DISTRICT) == GangTerritory.PLAYER_OWNER:
		return "the rate-comparison ticks should not have captured the turf yet"
	# The accrual tracks the ACTUAL trained bonus (robust to the skill curve).
	var expected := delta_unfit * (1.0 + bonus * TurfZone.STAMINA_CAPTURE_BONUS)
	if not is_equal_approx(delta_fit, expected):
		return "the fit accrual was not the expected %f (got %f)" % [expected, delta_fit]
	return ""


func _pass() -> bool:
	print(
		(
			(
				"turf stamina probe: OK (unfit accrued %.2f/tick; a trained-fit player contested "
				+ "the same turf faster)"
			)
			% (RATE * DT)
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("turf stamina probe FAIL :: %s" % message)
	print("turf stamina probe: FAIL — %s" % message)
	quit(1)
	return true
