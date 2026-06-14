extends SceneTree
## Runtime wiring probe for VehicleSupplierController + ValetStand — the integration the
## pure-model unit tests (test_vehicle_supplier.gd) can't make: stepping up to a valet stand
## CALLS the car (charged to PlayerStats, enters transit), the controller's frame clock
## counts the delivery down and emits vehicle_delivered on arrival, a wreck reported via
## report_destroyed starts a respawn cooldown that emits vehicle_respawned when it elapses,
## and a call with too little money fails with no charge and no dispatch. Run:
##   godot --headless --path game --script res://tests/vehicle_supplier_probe.gd

const WARMUP_FRAMES: int = 3
const VEHICLE: String = "daily_sedan"
const FREE_VEHICLE: String = "loaner"
const DELIVERY: float = 45.0
const COST: int = 150
const RESPAWN: float = 300.0
const START_MONEY: int = 1000

var _ctrl: VehicleSupplierController = null
var _valet: ValetStand = null
var _stats: MockStats = null
var _player: StaticBody3D = null
var _frames: int = 0
var _delivered_id: String = ""
var _delivered_count: int = 0
var _respawned_count: int = 0
var _called_count: int = 0
var _last_eta: float = -1.0


class MockStats:
	extends Node
	var money: int = 0

	func _ready() -> void:
		add_to_group("player_stats")

	func spend_money(amount: int) -> bool:
		if amount <= 0 or money < amount:
			return false
		money -= amount
		return true


func _initialize() -> void:
	_stats = MockStats.new()
	_stats.money = START_MONEY
	root.add_child(_stats)

	_ctrl = VehicleSupplierController.new()
	# A fixed roster so the asserts don't ride on the default catalogue, plus a free
	# (cost 0) loaner to exercise the no-spend summon path.
	_ctrl.roster = [
		{
			"id": VEHICLE,
			"delivery_seconds": DELIVERY,
			"respawn_seconds": RESPAWN,
			"request_cost": COST,
		},
		{"id": FREE_VEHICLE, "delivery_seconds": 10.0, "request_cost": 0},
	]
	_ctrl.set_process(false)
	_ctrl.vehicle_delivered.connect(_on_delivered)
	_ctrl.vehicle_respawned.connect(_on_respawned)
	root.add_child(_ctrl)

	_valet = ValetStand.new()
	_valet.vehicle_id = VEHICLE
	_valet.called.connect(_on_called)
	root.add_child(_valet)

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _on_delivered(id: String) -> void:
	_delivered_id = id
	_delivered_count += 1


func _on_respawned(_id: String) -> void:
	_respawned_count += 1


func _on_called(_id: String, eta: float) -> void:
	_called_count += 1
	_last_eta = eta


## One physical visit: enter (acts once) then leave (re-arms the stand for the next visit).
func _visit() -> void:
	_valet.body_entered.emit(_player)
	_valet.body_exited.emit(_player)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _ctrl == null or _valet == null or _stats == null:
		return _fail("mock tree did not assemble")
	var err := _run_checks()
	if err != "":
		return _fail(err)
	return _pass()


func _run_checks() -> String:
	var call_err := _check_call()
	if call_err != "":
		return call_err
	var delivery_err := _check_delivery()
	if delivery_err != "":
		return delivery_err
	var respawn_err := _check_wreck_respawn()
	if respawn_err != "":
		return respawn_err
	var free_err := _check_free_summon()
	if free_err != "":
		return free_err
	return _check_insufficient_funds()


func _check_call() -> String:
	var money_before := _stats.money
	_visit()  # available -> call the car
	if _called_count != 1 or _last_eta < DELIVERY - 0.5:
		return "the valet did not call the car with a full ETA (eta %.1f)" % _last_eta
	if not _ctrl.is_in_transit(VEHICLE) or _ctrl.is_available(VEHICLE):
		return "the called car did not enter transit"
	if _ctrl.report_destroyed(VEHICLE):
		return "an in-transit car was wrongly reportable as wrecked"
	if _stats.money != money_before - COST:
		return "calling the car did not charge the fee (money %d)" % _stats.money
	return ""


func _check_delivery() -> String:
	var delivered_before := _delivered_count
	_ctrl._process(20.0)  # partial trip
	# eta is integer-sourced (45 - 20), so a sub-millisecond float epsilon is ample.
	if not _ctrl.is_in_transit(VEHICLE) or absf(_ctrl.eta_of(VEHICLE) - (DELIVERY - 20.0)) > 0.01:
		return "the delivery ETA did not count down (eta %.1f)" % _ctrl.eta_of(VEHICLE)
	_ctrl._process(DELIVERY)  # finish the trip
	if _delivered_count - delivered_before != 1 or _delivered_id != VEHICLE:
		return "the car was not delivered exactly once when the timer elapsed"
	if not _ctrl.is_available(VEHICLE):
		return "the delivered car is not available to drive"
	return ""


func _check_wreck_respawn() -> String:
	var respawned_before := _respawned_count
	if not _ctrl.report_destroyed(VEHICLE):
		return "a delivered car could not be reported wrecked"
	if not _ctrl.is_destroyed(VEHICLE) or _ctrl.is_available(VEHICLE):
		return "the wrecked car did not enter the respawn cooldown"
	_ctrl._process(RESPAWN + 1.0)  # wait out the cooldown
	if _respawned_count - respawned_before != 1 or not _ctrl.is_available(VEHICLE):
		return "the wrecked car did not respawn exactly once after its cooldown"
	return ""


func _check_free_summon() -> String:
	# A cost-0 loaner summons WITHOUT a spend: the cost>0 guard must skip spend_money (which
	# would reject a 0 charge and wrongly abort the call).
	var money_before := _stats.money
	var eta := _ctrl.request(FREE_VEHICLE)
	if eta < 0.0:
		return "a free vehicle could not be summoned"
	if not _ctrl.is_in_transit(FREE_VEHICLE) or _stats.money != money_before:
		return "a free summon charged the wallet or did not dispatch"
	return ""


func _check_insufficient_funds() -> String:
	# Drain the wallet below the fee; a call must fail with no charge and no dispatch.
	_stats.money = COST - 1
	var money_before := _stats.money
	var calls_before := _called_count
	_visit()
	if _called_count != calls_before:
		return "a call succeeded without enough money"
	if _ctrl.is_in_transit(VEHICLE) or _stats.money != money_before:
		return "a failed call still charged / dispatched the car"
	return ""


func _pass() -> bool:
	print(
		(
			"vehicle supplier probe: OK (valet call charged the fee + dispatched, the car "
			+ "arrived on the timer, a wreck respawned after cooldown, a broke call was refused)"
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("vehicle supplier probe FAIL :: %s" % message)
	print("vehicle supplier probe: FAIL — %s" % message)
	quit(1)
	return true
