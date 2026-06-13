extends SceneTree
## Runtime wiring probe for the TurfZone -> GangTerritoryController capture loop,
## proven through the live node graph in a mock tree. Hold-the-ground gameplay: the
## player stands in a rival district's zone, influence climbs while they're inside,
## and at full influence the turf flips to the player. Accrual is driven manually
## (the zone's engine _process is silenced) so the influence curve is deterministic.
## Physics overlap is the scene author's job; this probe emits body_entered/exited
## directly. Run:
##   godot --headless --path game --script res://tests/turf_zone_probe.gd

const WARMUP_FRAMES: int = 3
const DISTRICT: String = "downtown"
const RATE: float = 0.2

var _ctl: GangTerritoryController = null
var _zone: TurfZone = null
var _player: StaticBody3D = null
var _frames: int = 0
var _captured_count: int = 0
var _captured_from: String = ""
var _max_signal_influence: float = 0.0


func _initialize() -> void:
	_ctl = GangTerritoryController.new()
	root.add_child(_ctl)

	_zone = TurfZone.new()
	_zone.district_id = DISTRICT
	_zone.capture_rate = RATE
	_zone.captured.connect(_on_captured)
	_zone.influence_changed.connect(_on_influence_changed)
	root.add_child(_zone)

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _on_captured(_district: String, from_owner: String) -> void:
	_captured_count += 1
	_captured_from = from_owner


func _on_influence_changed(_district: String, influence: float) -> void:
	_max_signal_influence = maxf(_max_signal_influence, influence)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _ctl == null or _zone == null or _player == null:
		return _fail("mock tree did not assemble")
	var territory: GangTerritory = _ctl.territory()
	var rival := territory.owner_of(DISTRICT)
	if rival == "" or rival == GangTerritory.PLAYER_OWNER:
		return _fail("district is not held by a rival at start")
	# Silence the engine's auto _process so accrual is fully manual + deterministic.
	_zone.set_process(false)
	return _assert_gate(territory, rival)


func _assert_gate(territory: GangTerritory, rival: String) -> bool:
	# Not inside (and a non-player presence): ticks accrue nothing.
	var bystander := StaticBody3D.new()
	root.add_child(bystander)
	_zone.body_entered.emit(bystander)
	_zone._process(5.0)
	if territory.influence_in(DISTRICT) != 0.0:
		return _fail("influence rose without the player inside")

	# Player holds the zone partially: influence climbs, no capture yet.
	_zone.body_entered.emit(_player)
	_zone._process(2.0)  # +0.4
	if not is_equal_approx(territory.influence_in(DISTRICT), 0.4):
		return _fail("partial hold did not accrue 0.4 (got %f)" % territory.influence_in(DISTRICT))
	if territory.owner_of(DISTRICT) == GangTerritory.PLAYER_OWNER:
		return _fail("captured before influence was full")

	return _run_capture(territory, rival)


func _run_capture(territory: GangTerritory, rival: String) -> bool:
	# Leaving stops the climb.
	_zone.body_exited.emit(_player)
	_zone._process(5.0)
	if not is_equal_approx(territory.influence_in(DISTRICT), 0.4):
		return _fail("influence climbed while the player was outside")

	# Re-enter and hold to full -> capture the turf.
	_zone.body_entered.emit(_player)
	_zone._process(5.0)  # +1.0 -> clamps to full -> take_over
	if territory.owner_of(DISTRICT) != GangTerritory.PLAYER_OWNER:
		return _fail("holding to full influence did not capture the turf")
	if _captured_count != 1 or _captured_from != rival:
		return _fail(
			"capture signal wrong (count %d, from '%s')" % [_captured_count, _captured_from]
		)

	# Already ours: more holding is a no-op (no second capture).
	_zone._process(5.0)
	if _captured_count != 1:
		return _fail("an already-owned turf captured again")
	# influence_changed must report the climb but never a 1.0 tick (capture frame
	# is owned by the `captured` signal — no racing progress update).
	if _max_signal_influence <= 0.0 or _max_signal_influence >= 1.0:
		return _fail("influence_changed max was %f (want >0 and <1)" % _max_signal_influence)
	return _pass(rival)


func _pass(rival: String) -> bool:
	print(
		(
			"turf zone probe: OK (%s taken from %s at full influence, control %.0f%%, no double-capture)"
			% [DISTRICT, rival, _ctl.controlled_fraction() * 100.0]
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("turf zone probe FAIL :: %s" % message)
	print("turf zone probe: FAIL — %s" % message)
	quit(1)
	return true
