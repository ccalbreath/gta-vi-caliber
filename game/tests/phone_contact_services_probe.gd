extends SceneTree
## Scene-free probe for live phone contact services.
##
## The Phone node owns the tested ContactServices model. This proves a connected
## service call charges the wallet, emits the service request, and applies the
## immediate "lower wanted" effect by clearing the wanted tracker.
## Run headless:
##   godot --headless --path game --script res://tests/phone_contact_services_probe.gd

const LENA_INDEX: int = 3

var _phone: Phone = null
var _stats: MockStats = null
var _wanted: MockWanted = null
var _frames: int = 0
var _service: Dictionary = {}
var _friend: String = ""


class MockStats:
	extends Node
	var money: int = 6000

	func _ready() -> void:
		add_to_group("player_stats")

	func spend_money(amount: int) -> bool:
		if amount <= 0 or money < amount:
			return false
		money -= amount
		return true


class MockWanted:
	extends Node
	var clears: int = 0

	func _ready() -> void:
		add_to_group("wanted")

	func clear() -> void:
		clears += 1


func _initialize() -> void:
	_stats = MockStats.new()
	root.add_child(_stats)
	_wanted = MockWanted.new()
	root.add_child(_wanted)
	_phone = Phone.new()
	root.add_child(_phone)
	_phone.friend_called.connect(func(name: String) -> void: _friend = name)
	_phone.service_requested.connect(_on_service_requested)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	return _run()


func _on_service_requested(id: String, kind: String, contact: String, cost: int) -> void:
	_service = {"id": id, "kind": kind, "contact": contact, "cost": cost}


func _run() -> bool:
	_phone._start_call(LENA_INDEX)
	_phone._advance_call(PhoneModel.DIAL_SECONDS + 0.1)
	_phone._advance_call(PhoneContacts.ring_seconds(PhoneContacts.by_name("Lena")) + 0.1)
	if _friend != "Lena":
		return _fail("Lena call did not connect")
	if _service.get("id", "") != "lower_wanted":
		return _fail("phone did not emit lower_wanted service")
	if _service.get("kind", "") != "heat" or int(_service.get("cost", 0)) != 5000:
		return _fail("service payload was wrong: %s" % str(_service))
	if _stats.money != 1000:
		return _fail("wallet was not charged down to 1000 (money=%d)" % _stats.money)
	if _wanted.clears != 1:
		return _fail("wanted tracker was not cleared")
	return _pass()


func _pass() -> bool:
	print("phone contact services probe: OK (Lena charged wallet and cleared wanted)")
	quit(0)
	return true


func _fail(reason: String) -> bool:
	push_error("phone contact services probe FAIL: %s" % reason)
	quit(1)
	return true
