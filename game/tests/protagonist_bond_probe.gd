extends SceneTree
## Runtime wiring probe for ProtagonistBondController — the integration the pure-model
## unit tests (test_protagonist_bond.gd) can't make: that the controller CONSUMES the
## heist_board node's heist_resolved signal (a shared score raises the Lucia+Jason bond,
## a botched one breeds conflict) and FEEDS the bond back out as a CO-OP PREMIUM paid on
## the take — so a tighter crew earns a bigger cut on the NEXT score (the closed loop).
## Also checks the non-negative premium clamp and the drift-to-neutral day clock. Run:
##   godot --headless --path game --script res://tests/protagonist_bond_probe.gd

const WARMUP_FRAMES: int = 3
const TAKE: int = 10000
const PERIOD: float = 10.0

var _ctrl: ProtagonistBondController = null
var _heist: MockHeist = null
var _stats: MockStats = null
var _frames: int = 0
var _last_bonus: int = -1
var _bond_changed_count: int = 0
var _last_tier: String = ""


class MockHeist:
	extends Node
	signal heist_resolved(success: bool, take: int)

	func _ready() -> void:
		add_to_group("heist_board")

	func resolve(success: bool, take: int) -> void:
		heist_resolved.emit(success, take)


class MockStats:
	extends Node
	var money: int = 0

	func _ready() -> void:
		add_to_group("player_stats")

	func add_money(amount: int) -> void:
		money += amount


func _initialize() -> void:
	_heist = MockHeist.new()
	root.add_child(_heist)
	_stats = MockStats.new()
	root.add_child(_stats)

	_ctrl = ProtagonistBondController.new()
	_ctrl.seconds_per_day = PERIOD
	_ctrl.set_process(false)
	_ctrl.coop_bonus_paid.connect(_on_bonus)
	_ctrl.bond_changed.connect(_on_bond_changed)
	root.add_child(_ctrl)


func _on_bonus(bonus: int) -> void:
	_last_bonus = bonus


func _on_bond_changed(_bond_value: float, tier: String) -> void:
	_bond_changed_count += 1
	_last_tier = tier


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _ctrl == null or _heist == null or _stats == null:
		return _fail("mock tree did not assemble")
	_ctrl._process(0.0)  # force _bind_heist
	var err := _run_checks()
	if err != "":
		return _fail(err)
	return _pass()


func _run_checks() -> String:
	var start_err := _check_start()
	if start_err != "":
		return start_err
	var coop_err := _check_coop_loop()
	if coop_err != "":
		return coop_err
	var fail_err := _check_failure_and_clamp()
	if fail_err != "":
		return fail_err
	var drift_err := _check_drift()
	if drift_err != "":
		return drift_err
	return _check_rescue()


func _check_start() -> String:
	if absf(_ctrl.bond() - ProtagonistBond.BOND_START) > 0.01:
		return "bond did not start at the neutral baseline (%.1f)" % _ctrl.bond()
	if _ctrl.backup_available():
		return "backup was available at the neutral start bond"
	if _stats.money != 0:
		return "money was not zero at start"
	return ""


func _check_coop_loop() -> String:
	var bond0 := _ctrl.bond()
	var changes0 := _bond_changed_count
	_heist.resolve(true, TAKE)  # success 1
	var bonus1 := _last_bonus
	if _ctrl.bond() <= bond0 or _bond_changed_count <= changes0 or _last_tier == "":
		return "a co-op score did not raise the bond / fire bond_changed"
	# bond after one co-op = START + COOP_GAIN*intensity (50 + 12*0.6 = 57.2), which sits
	# above BACKUP_THRESHOLD(55). If COOP_GAIN drops or BACKUP_THRESHOLD rises so the sum
	# lands below it, this fires — retune heist_coop_intensity, not the wiring.
	if not _ctrl.backup_available():
		return "backup did not unlock after a co-op score"
	if bonus1 <= 0 or _stats.money != bonus1:
		return "no co-op premium was paid on the shared take (bonus %d)" % bonus1
	var money1 := _stats.money
	_heist.resolve(true, TAKE)  # success 2 — a tighter crew
	var bonus2 := _last_bonus
	if bonus2 <= bonus1 or _stats.money != money1 + bonus2:
		return "a tighter bond did not pay a bigger premium (%d then %d)" % [bonus1, bonus2]
	return ""


func _check_failure_and_clamp() -> String:
	var bond_before := _ctrl.bond()
	var money_before := _stats.money
	var changes_before := _bond_changed_count
	_heist.resolve(false, TAKE)  # botched job -> conflict, no bonus
	if _ctrl.bond() >= bond_before or _bond_changed_count <= changes_before:
		return "a botched heist did not breed conflict / fire bond_changed"
	if _stats.money != money_before:
		return "a failed heist wrongly paid a co-op bonus"
	# Crater the bond, then a success BELOW neutral must pay no premium (clamped >= 0) —
	# cross-checked both ways: the wallet is untouched AND coop_bonus_paid never fires.
	_ctrl.record_betrayal(1.0)
	if _ctrl.backup_available():
		return "backup stayed available after a betrayal"
	var bonus_seen := _last_bonus
	var money_low := _stats.money
	_heist.resolve(true, TAKE)
	if _stats.money != money_low or _last_bonus != bonus_seen:
		return "a sub-neutral bond paid a premium it should have clamped (money %d)" % _stats.money
	return ""


func _check_drift() -> String:
	var bond_before := _ctrl.bond()
	var dist_before := absf(bond_before - ProtagonistBond.BOND_START)
	for _i in 4:
		_ctrl._process(PERIOD)  # advance ~4 in-game days
	var dist_after := absf(_ctrl.bond() - ProtagonistBond.BOND_START)
	if dist_after >= dist_before:
		return "the bond did not drift toward neutral (%.1f -> %.1f)" % [bond_before, _ctrl.bond()]
	return ""


func _check_rescue() -> String:
	# The non-heist hook: one lead saving the other raises the bond and fires bond_changed.
	var bond_before := _ctrl.bond()
	var changes_before := _bond_changed_count
	_ctrl.record_rescue(1.0)
	if _ctrl.bond() <= bond_before or _bond_changed_count <= changes_before:
		return "record_rescue did not raise the bond / fire bond_changed"
	return ""


func _pass() -> bool:
	print(
		(
			"protagonist bond probe: OK (co-op score raised the bond + paid a premium, "
			+ "a tighter crew paid more, conflict/clamp/drift all held)"
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("protagonist bond probe FAIL :: %s" % message)
	print("protagonist bond probe: FAIL — %s" % message)
	quit(1)
	return true
