extends SceneTree
## End-to-end composition probe for the deployed InteractionDistrict — proves the
## bundled controllers actually COMPOSE into the full emergent crime-war chain when
## dropped as one node (the per-controller probes use mocks; this drives the REAL
## bundle): capture a rival's turf -> the gang holds a grudge -> a revenge strike
## fires -> a bounty lands on the player's head -> hunters come. Drives the clocks
## manually for a deterministic run. Run:
##   godot --headless --path game --script res://tests/interaction_chain_probe.gd

const SETTLE_FRAMES: int = 6
const DISTRICT: String = "downtown"  # InteractionDistrict.turf_district default
const RIVAL: String = "vice_kings"  # owns downtown in GangTerritory.default_districts

var _player: StaticBody3D = null
var _frames: int = 0


func _initialize() -> void:
	var district := InteractionDistrict.new()
	root.add_child(district)

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return false
	return _capture_turf()


func _capture_turf() -> bool:
	var turf := get_first_node_in_group("turf_zone")
	var gang := get_first_node_in_group("gang_territory")
	var rival := get_first_node_in_group("rival_retaliation")
	var bounty := get_first_node_in_group("player_bounty")
	if turf == null or gang == null or rival == null or bounty == null:
		return _fail("the district did not assemble its controllers")

	# Take manual control of every clock, then bind the lazy signal hops.
	turf.set_process(false)
	rival.set_process(false)
	bounty.set_process(false)
	rival.seconds_per_day = 1.0
	rival._process(0.0)  # rival binds to gang_territory.turf_captured
	bounty._process(0.0)  # bounty binds to rival.retaliation_strike

	# Hold the rival district's turf to full influence: it flips to the player and,
	# through the live controllers, provokes the dispossessed gang.
	turf.body_entered.emit(_player)
	turf._process(10.0)
	if gang.owner_of(DISTRICT) != "player":
		return _fail("turf was not captured through the district")
	if rival.grudge_of(RIVAL) <= 0.0:
		return _fail("capturing turf did not provoke the gang through the bundle")

	return _strike_to_bounty(rival, bounty)


func _strike_to_bounty(rival: Node, bounty: Node) -> bool:
	# Two in-game days pass: the gang's revenge strike fires and the bounty
	# controller, listening on the same bundle, puts a price on the player.
	rival._process(2.0)
	if bounty.total_bounty() <= 0 or bounty.hunter_count() < 1:
		return _fail(
			(
				"the strike did not raise a bounty through the bundle (total %d, hunters %d)"
				% [bounty.total_bounty(), bounty.hunter_count()]
			)
		)
	return _pass(bounty)


func _pass(bounty: Node) -> bool:
	print(
		(
			"interaction chain probe: OK (one district: turf -> grudge -> strike -> $%d bounty, %d hunters)"
			% [bounty.total_bounty(), bounty.hunter_count()]
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("interaction chain probe FAIL :: %s" % message)
	print("interaction chain probe: FAIL — %s" % message)
	quit(1)
	return true
