extends SceneTree
## Runtime wiring probe for the grudge->bounty seam: RivalRetaliation strikes
## (relayed here by a mock) make the aggrieved gang put a price on the player's head
## via PlayerBountyController, escalating the bounty tier (more hunters); the bounty
## then decays over days and can be paid off. Drives _process manually for a
## deterministic clock. Run:
##   godot --headless --path game --script res://tests/player_bounty_probe.gd

const WARMUP_FRAMES: int = 3
const PER_SEVERITY: float = 12000.0

var _ctl: PlayerBountyController = null
var _rival: MockRival = null
var _frames: int = 0
var _last_hunter_signal: int = -1


class MockRival:
	extends Node
	signal retaliation_strike(faction_id: String, kind: String, severity: float)

	func _ready() -> void:
		add_to_group("rival_retaliation")


func _initialize() -> void:
	_rival = MockRival.new()
	root.add_child(_rival)

	_ctl = PlayerBountyController.new()
	_ctl.bounty_per_severity = PER_SEVERITY
	_ctl.seconds_per_day = 1.0
	_ctl.hunters_changed.connect(_on_hunters_changed)
	root.add_child(_ctl)


func _on_hunters_changed(count: int, _threat: float) -> void:
	_last_hunter_signal = count


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _ctl == null or _rival == null:
		return _fail("mock tree did not assemble")
	_ctl.set_process(false)  # drive the decay clock manually
	_ctl._process(0.0)  # bind to the strike source

	# A half-severity strike puts a $6000 bounty up: HUNTED tier -> 2 hunters.
	_rival.retaliation_strike.emit("vice_kings", "vandalism", 0.5)
	if _ctl.total_bounty() != 6000 or _ctl.hunter_count() != 2 or _last_hunter_signal != 2:
		return _fail(
			(
				"a strike did not raise a hunted bounty (total %d, hunters %d)"
				% [_ctl.total_bounty(), _ctl.hunter_count()]
			)
		)
	return _run_escalate()


func _run_escalate() -> bool:
	# Two more full-severity strikes from other gangs push the total to $30000:
	# MARKED tier -> 3 hunters.
	_rival.retaliation_strike.emit("marina_cartel", "property_raid", 1.0)
	_rival.retaliation_strike.emit("los_santos_set", "hit_squad", 1.0)
	if _ctl.total_bounty() != 30000 or _ctl.hunter_count() != 3 or _last_hunter_signal != 3:
		return _fail(
			(
				"escalating strikes did not raise a marked bounty (total %d, hunters %d)"
				% [_ctl.total_bounty(), _ctl.hunter_count()]
			)
		)

	# Lay low: enough days fade the bounty DOWN a tier (marked -> hunted), which must
	# drop the hunter count and fire hunters_changed.
	_ctl._process(10.0)
	if _ctl.hunter_count() != 2 or _last_hunter_signal != 2:
		return _fail(
			(
				"decay did not drop hunters 3->2 (count %d, signal %d)"
				% [_ctl.hunter_count(), _last_hunter_signal]
			)
		)

	return _run_resolve()


func _run_resolve() -> bool:
	# Pay it off at a fixer: the bounty clears and the hunters stand down.
	if not _ctl.pay(_ctl.total_bounty()).get("success", false):
		return _fail("paying the bounty failed")
	if _ctl.total_bounty() != 0 or _ctl.hunter_count() != 0 or _last_hunter_signal != 0:
		return _fail("the bounty did not clear after paying (total %d)" % _ctl.total_bounty())

	# A fresh strike re-raises it; then a hunter kills the player and CLAIMS it.
	_rival.retaliation_strike.emit("vice_kings", "hit_squad", 1.0)
	if _ctl.hunter_count() == 0:
		return _fail("a fresh strike did not re-raise the bounty")
	var payout := _ctl.claim()
	if payout <= 0 or _ctl.total_bounty() != 0 or _last_hunter_signal != 0:
		return _fail("claim did not collect + clear the bounty (payout %d)" % payout)
	return _pass()


func _pass() -> bool:
	print(
		"player bounty probe: OK (strikes -> price on your head -> hunters escalate; decays; paid off)"
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("player bounty probe FAIL :: %s" % message)
	print("player bounty probe: FAIL — %s" % message)
	quit(1)
	return true
