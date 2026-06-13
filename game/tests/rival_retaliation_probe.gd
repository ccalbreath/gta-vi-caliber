extends SceneTree
## Runtime wiring probe for the turf-grudge loop: capturing a rival gang's turf
## (TurfZone -> GangTerritoryController.turf_captured) provokes RivalRetaliation via
## RivalRetaliationController, and a day-tick then launches their revenge strike.
## Drives _process manually (engine ticking silenced) for a deterministic curve.
## Run: godot --headless --path game --script res://tests/rival_retaliation_probe.gd

const WARMUP_FRAMES: int = 3
const DISTRICT: String = "downtown"
const RIVAL: String = "vice_kings"  # owns downtown in GangTerritory.default_districts

var _gang: GangTerritoryController = null
var _rival: RivalRetaliationController = null
var _zone: TurfZone = null
var _player: StaticBody3D = null
var _frames: int = 0
var _strike_count: int = 0
var _strike_faction: String = ""
var _strike_kind: String = ""


func _initialize() -> void:
	_gang = GangTerritoryController.new()
	root.add_child(_gang)

	_rival = RivalRetaliationController.new()
	_rival.seconds_per_day = 1.0
	_rival.retaliation_strike.connect(_on_strike)
	root.add_child(_rival)

	_zone = TurfZone.new()
	_zone.district_id = DISTRICT
	_zone.capture_rate = 0.2
	root.add_child(_zone)

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _on_strike(faction_id: String, kind: String, _severity: float) -> void:
	_strike_count += 1
	_strike_faction = faction_id
	_strike_kind = kind


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _gang == null or _rival == null or _zone == null or _player == null:
		return _fail("mock tree did not assemble")
	# Drive accrual + the day clock manually.
	_zone.set_process(false)
	_rival.set_process(false)
	# Bind the rival controller to the turf source (no day passes at delta 0).
	_rival._process(0.0)

	# Capture downtown from vice_kings: hold the zone to full influence.
	_zone.body_entered.emit(_player)
	_zone._process(5.0)  # 0.2 * 5 = 1.0 -> captured
	if _gang.owner_of(DISTRICT) != "player":
		return _fail("turf was not captured")
	if not is_equal_approx(_rival.grudge_of(RIVAL), _rival.turf_grudge):
		return _fail(
			"capturing turf did not provoke the rival (grudge %.1f)" % _rival.grudge_of(RIVAL)
		)
	if not _rival.is_seeking_revenge(RIVAL):
		return _fail("provoked rival is not seeking revenge")

	return _run_strike()


func _run_strike() -> bool:
	# Two in-game days pass (past RETALIATION_COOLDOWN_DAYS): the hot faction now
	# launches its first retaliation strike.
	_rival._process(2.0)
	if _strike_count != 1 or _strike_faction != RIVAL:
		return _fail(
			(
				"no revenge strike from %s (count %d, faction '%s')"
				% [RIVAL, _strike_count, _strike_faction]
			)
		)
	return _pass()


func _pass() -> bool:
	print(
		(
			"rival retaliation probe: OK (took %s's turf -> grudge -> '%s' strike on the day tick)"
			% [RIVAL, _strike_kind]
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("rival retaliation probe FAIL :: %s" % message)
	print("rival retaliation probe: FAIL — %s" % message)
	quit(1)
	return true
