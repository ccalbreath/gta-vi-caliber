class_name StoreCounter
extends Area3D
## A stick-up: step up to the register and rob it. How much you walk out with scales
## with how hard you lean on the clerk (`intimidation`); lean too soft and they trip
## the silent alarm, so the cops come harder. Cash goes to PlayerStats, heat to the
## wanted tracker (the robbery is a crime; a tripped alarm is a second one). The till
## refills over in-game days, so a store is robbable again later. Consumes the tested
## StoreRobbery model; self-wires by group (player / player_stats / wanted). Needs a
## CollisionShape3D child; watches the player's collision layer (2). Verified in
## tests/store_counter_probe.gd.

signal robbed(took: int, alarm: bool)

## Floor on the day period + cap on days advanced per frame (a tiny seconds_per_day
## or a lag spike can't run thousands of refills in one frame).
const MIN_SECONDS_PER_DAY: float = 1.0
const MAX_DAYS_PER_FRAME: float = 10.0

## Cash in the till at the start (and the cap it refills back up to).
@export var register_cash: int = 800
## Till refill per in-game day.
@export var refill_per_day: int = 400
## How hard this stick-up leans on the clerk (0..1); below StoreRobbery.ALARM_THRESHOLD
## trips the silent alarm. A scene could drive this from the player's weapon/aim.
@export_range(0.0, 1.0) var intimidation: float = 0.7
## Real seconds per in-game day for the till-refill clock (<=0 disables refills).
@export_range(0.0, 600.0) var seconds_per_day: float = 120.0

var _robbery: StoreRobbery
var _day_accum: float = 0.0


func _ready() -> void:
	_robbery = StoreRobbery.new(register_cash, refill_per_day)
	if register_cash <= 0:
		push_warning(
			"StoreCounter: register_cash %d — this store is never robbable" % register_cash
		)
	add_to_group("store_counter")
	collision_mask |= 2
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if seconds_per_day <= 0.0 or _robbery == null:
		return
	var period := maxf(seconds_per_day, MIN_SECONDS_PER_DAY)
	_day_accum = minf(_day_accum + delta, period * MAX_DAYS_PER_FRAME)
	while _day_accum >= period:
		_day_accum -= period
		_robbery.refill(1.0)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or _robbery == null:
		return
	if _robbery.register_balance() <= 0:
		return  # already cleaned out — wait for the till to refill
	# Confirm the take can be paid out BEFORE rob() empties the till, so a robbery
	# never drains the register for nothing.
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats == null or not stats.has_method("add_money"):
		return
	var result := _robbery.rob(intimidation)
	var took := int(result["took"])
	var alarm := bool(result["alarm"])
	stats.add_money(took)
	_report_heat(alarm)
	robbed.emit(took, alarm)


## Feed the robbery's heat to the wanted tracker. The model returns an int `heat`
## (3, or 5 with alarm) but WantedTracker has no add-amount API, so this maps it —
## intentionally lossily — to crime reports: the stick-up is one crime, a tripped
## silent alarm a second (the cops come harder). Same approximation as the
## contraband-bust seam; swap to an add-heat call if the tracker ever gains one.
func _report_heat(alarm: bool) -> void:
	var wanted := get_tree().get_first_node_in_group("wanted")
	if wanted == null or not wanted.has_method("report_crime"):
		return
	wanted.report_crime(false)
	if alarm:
		wanted.report_crime(false)


## Cash currently in the till, for a HUD readout.
func till() -> int:
	return _robbery.register_balance() if _robbery != null else 0
