extends SceneTree
## Runtime wiring probe for SocialCloutController — the integration the pure-model unit tests
## (test_social_clout.gd) can't make: that the controller CONSUMES the wanted node's
## stars_changed (a crime is filmed; one clip per SPREE, debounced), that a flashy enough
## crime goes VIRAL (followers jump) and FEEDS a heat tip back to the wanted system (the clip
## is evidence) WITHOUT the re-entrant stars_changed re-filming, and that a day pays
## SPONSORSHIP income into PlayerStats then lets the audience drift. Run:
##   godot --headless --path game --script res://tests/social_clout_probe.gd

const WARMUP_FRAMES: int = 3
const PERIOD: float = 10.0
# Probe-fixed tuning so the math is controlled: reach = SEV*stars * (WIT+1) * FLASH * amp.
# At 0 followers (amp 1): stars 2 -> 60 (flop, < viral 80); stars 3 -> 90 (viral).
const FILM_AT: int = 1
const SEV: float = 15.0
const WIT: int = 1
const FLASH: float = 1.0

var _ctrl: SocialCloutController = null
var _wanted: MockWanted = null
var _stats: MockStats = null
var _frames: int = 0
var _viral_count: int = 0


class MockWanted:
	extends Node
	signal stars_changed(stars: int)
	var heat_reports: int = 0

	func _ready() -> void:
		add_to_group("wanted")

	func report_crime(_killed: bool) -> void:
		heat_reports += 1
		# Faithfully RE-ENTER the listener like the live WantedTracker (its heat bump
		# re-emits stars_changed), so the probe actually exercises the viral heat-tip's
		# re-entrancy guard instead of silently absorbing it.
		stars_changed.emit(5)

	func emit_stars(stars: int) -> void:
		stars_changed.emit(stars)


class MockStats:
	extends Node
	var money: int = 0

	func _ready() -> void:
		add_to_group("player_stats")

	func add_money(amount: int) -> void:
		money += amount


func _initialize() -> void:
	_wanted = MockWanted.new()
	root.add_child(_wanted)
	_stats = MockStats.new()
	root.add_child(_stats)

	_ctrl = SocialCloutController.new()
	_ctrl.film_at_stars = FILM_AT
	_ctrl.severity_per_star = SEV
	_ctrl.est_witnesses = WIT
	_ctrl.flashiness = FLASH
	_ctrl.seconds_per_day = PERIOD
	_ctrl.set_process(false)
	_ctrl.went_viral.connect(_on_viral)
	root.add_child(_ctrl)


func _on_viral(_followers: int, _gained: int) -> void:
	_viral_count += 1


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _ctrl == null or _wanted == null or _stats == null:
		return _fail("mock tree did not assemble")
	_ctrl._process(0.0)  # force _bind_wanted
	var err := _run_checks()
	if err != "":
		return _fail(err)
	return _pass()


func _run_checks() -> String:
	var flop_err := _check_flop()
	if flop_err != "":
		return flop_err
	var viral_err := _check_viral()
	if viral_err != "":
		return viral_err
	return _check_income_decay()


func _check_flop() -> String:
	_wanted.emit_stars(2)  # filmed but flopped (reach 60 < the 80 viral threshold)
	if _ctrl.followers() != 0 or _viral_count != 0:
		return "a small crime should flop (no followers, not viral)"
	_wanted.emit_stars(2)  # same spree -> debounced
	if _ctrl.followers() != 0:
		return "the debounce did not hold within a spree"
	_wanted.emit_stars(0)  # cool down -> re-arm
	return ""


func _check_viral() -> String:
	var heat_before := _wanted.heat_reports
	var viral_before := _viral_count
	_wanted.emit_stars(3)  # reach 90 -> viral; runs the full synchronous chain incl. the tip
	if _viral_count - viral_before != 1 or _ctrl.followers() <= 0:
		return "a flashy crime did not go viral exactly once"
	# The viral clip tipped heat back via report_crime, whose re-emitted stars_changed(5)
	# re-entered _on_stars_changed. If the spree debounce had FAILED, that re-entry would
	# re-film -> re-tip -> runaway, so bound the tips to a single clip's heat_tip.
	var tips := _wanted.heat_reports - heat_before
	if tips <= 0 or tips > SocialClout.HEAT_TIP_MAX:
		return "the viral heat-tip was missing or ran away on re-entry (%d tips)" % tips
	_wanted.emit_stars(0)  # re-arm
	return ""


func _check_income_decay() -> String:
	# Below the sponsorship floor (the viral gain is ~270 < 1000), a day pays nothing.
	if _ctrl.followers() >= 1000:
		return "probe setup: followers already past the sponsorship floor"
	var low_money := _stats.money
	_ctrl._process(PERIOD)
	if _stats.money != low_money:
		return "income was paid below the sponsorship floor"
	# Cross into sponsorship territory (>= 1000 followers) with a non-crime content post.
	_ctrl.post_content(2000)
	var income := _ctrl.sponsorship_income()
	if income <= 0:
		return "no sponsorship income above local fame"
	var money_before := _stats.money
	var followers_before := _ctrl.followers()
	_ctrl._process(PERIOD)  # one day: pay income + decay
	if _stats.money != money_before + income:
		return "a day did not pay the sponsorship income (money %d)" % _stats.money
	if _ctrl.followers() >= followers_before:
		return "the audience did not drift (decay) over a day"
	return ""


func _pass() -> bool:
	print(
		(
			"social clout probe: OK (a small crime flopped, a flashy one went viral + tipped "
			+ "heat back, the spree debounced the re-entry, a day paid sponsorship + decayed)"
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("social clout probe FAIL :: %s" % message)
	print("social clout probe: FAIL — %s" % message)
	quit(1)
	return true
