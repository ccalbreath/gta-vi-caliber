extends SceneTree
## Vehicle mod-garage probe: proves the playable tuning loop runs in miami — sit in
## a car, park it on the garage floor, and the next affordable upgrade is bought
## (money charged) and applied live to that car's stats. Run headless:
##   godot --headless --path game --script res://tests/miami_vehicle_mod_probe.gd

const SCENE_PATH: String = "res://scenes/world/miami.tscn"
const WARMUP_FRAMES: int = 36
const DWELL_FRAMES: int = 30
## Matches the VehicleModGarage transform in miami.tscn.
const GARAGE_POS := Vector3(-62, 1, 44)

var _player: Node3D = null
var _stats: Node = null
var _garage: Node = null
var _car: Node3D = null
var _money_start: int = 0
var _stock: Dictionary = {}
var _frames: int = 0
var _t: int = 0
var _phase: String = "warmup"


func _initialize() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		push_error("miami vehicle mod probe: scene failed to load")
		quit(1)
		return
	root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	match _phase:
		"warmup":
			if _frames >= WARMUP_FRAMES:
				return _resolve()
		"drive":
			return _phase_drive()
	return false


func _resolve() -> bool:
	_player = get_first_node_in_group("player") as Node3D
	_stats = get_first_node_in_group("player_stats")
	_garage = get_first_node_in_group("vehicle_mod_shop")
	_car = _find_car()
	if _player == null:
		return _fail("no player rig")
	if _stats == null or not ("money" in _stats):
		return _fail("no PlayerStats")
	if _garage == null or not _garage.has_method("installed_levels"):
		return _fail("no VehicleModGarage in group 'vehicle_mod_shop'")
	if _car == null:
		return _fail("no drivable car in group 'vehicles'")
	# Front the player enough to afford a tier so the probe exercises the buy path.
	if _stats.has_method("add_money"):
		_stats.add_money(50000)
	_money_start = int(_stats.money)
	_stock = _capture_stats(_car)
	# Sit in the car so the garage tunes a *driven* vehicle (parked cars are ignored).
	if _car.has_method("enter"):
		_car.enter(_player)
	_phase = "drive"
	return false


func _phase_drive() -> bool:
	_car.global_position = GARAGE_POS
	if _car is RigidBody3D:
		(_car as RigidBody3D).linear_velocity = Vector3.ZERO
	_t += 1
	if _garage.installed_levels(String(_car.name)) > 0:
		if int(_stats.money) >= _money_start:
			return _fail("upgrade installed but money was not charged")
		if not _stats_changed(_car, _stock):
			return _fail("upgrade installed but no car stat changed")
		return _pass()
	if _t >= DWELL_FRAMES:
		return _fail("car parked in the garage but no upgrade was bought")
	return false


func _find_car() -> Node3D:
	for node in get_nodes_in_group("vehicles"):
		var car := node as Node3D
		if car != null and car.has_method("enter") and "peak_torque" in car:
			return car
	return null


func _capture_stats(car: Node) -> Dictionary:
	return {
		"peak_torque": float(car.peak_torque),
		"tire_friction": float(car.tire_friction),
		"max_brake": float(car.max_brake),
		"max_health": float(car.max_health),
	}


func _stats_changed(car: Node, stock: Dictionary) -> bool:
	for key: String in stock:
		if not is_equal_approx(float(car.get(key)), float(stock[key])):
			return true
	return false


func _pass() -> bool:
	print(
		(
			"miami vehicle mod probe: OK (upgrade bought for $%d, %d tier(s) installed)"
			% [_money_start - int(_stats.money), _garage.installed_levels(String(_car.name))]
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("miami vehicle mod probe FAIL :: %s" % message)
	print("miami vehicle mod probe: FAIL — %s" % message)
	quit(1)
	return true
