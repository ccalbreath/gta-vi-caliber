class_name SmugglingRoute
extends Node3D
## A bulk smuggling run — the Florida gauntlet. Step into the Pickup zone to load the
## cargo, then reach the Dropoff zone to run the route: at each leg (open water, a
## patrol box, the port approach) an interdiction can seize a slice of the load, but
## your EVASION shrinks the loss — and a trained DRIVER evades better, reading
## PlayerSkills.bonus("driving") from the player_skills group (so the gym pays off
## here). What survives is delivered for cash; each seizure draws police heat.
## Consumes the tested SmugglingRun model and self-wires by group (player /
## player_stats / wanted / player_skills).
##
## Two named Area3D children "Pickup" + "Dropoff", each with a CollisionShape3D; both
## watch the player's collision layer (2). One run per route. Verified in
## tests/smuggling_route_probe.gd.

signal cargo_loaded
signal run_delivered(value: int, seized: int)

## Cap on the crime reports a run's interdiction heat maps to.
const MAX_HEAT_REPORTS: int = 6

## Units of product and their per-unit value.
@export var cargo_units: int = 20
@export var unit_value: int = 500
## Per-leg interdiction risk (0..1): open water, a coast-guard box, the port run.
@export var leg_risks: PackedFloat32Array = PackedFloat32Array([0.4, 0.5, 0.3])
## Evasion floor before the driver's skill is added (a fast boat / a greased official).
@export_range(0.0, 1.0) var base_evasion: float = 0.2

var _run: SmugglingRun
var _pickup: Area3D
var _dropoff: Area3D
var _loaded: bool = false
var _ran: bool = false


func _ready() -> void:
	if cargo_units <= 0 or unit_value <= 0:
		push_warning(
			(
				"SmugglingRoute: cargo_units and unit_value should be > 0 (got %d, %d)"
				% [cargo_units, unit_value]
			)
		)
	_run = SmugglingRun.new(cargo_units, unit_value)
	for risk: float in leg_risks:
		_run.add_leg(risk)
	add_to_group("smuggling_route")
	_pickup = get_node_or_null("Pickup") as Area3D
	_dropoff = get_node_or_null("Dropoff") as Area3D
	if _pickup != null:
		_pickup.collision_mask |= 2
		_pickup.body_entered.connect(_on_pickup_entered)
	if _dropoff != null:
		_dropoff.collision_mask |= 2
		_dropoff.body_entered.connect(_on_dropoff_entered)


func _on_pickup_entered(body: Node) -> void:
	if body.is_in_group("player") and not _loaded and not _ran:
		_loaded = true
		cargo_loaded.emit()


func _on_dropoff_entered(body: Node) -> void:
	if not body.is_in_group("player") or not _loaded or _ran:
		return
	# Confirm the delivery can be paid before burning the run.
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats == null or not stats.has_method("add_money"):
		return
	_ran = true
	var evasion := clampf(base_evasion + _driving_bonus(), 0.0, 1.0)
	var result := _run.run(evasion)
	var value := int(result["value_delivered"])
	if value > 0:
		stats.add_money(value)
	_report_heat(int(result["heat"]))
	run_delivered.emit(value, int(result["seized"]))


## Evasion the player's driving proficiency adds (0 if no skills wired in).
func _driving_bonus() -> float:
	var skills := get_tree().get_first_node_in_group("player_skills")
	if skills != null and skills.has_method("bonus"):
		return clampf(float(skills.bonus("driving")), 0.0, 1.0)
	return 0.0


## A seizure at each leg draws heat — fed to the wanted tracker as crime reports
## (it has no add-amount API), capped so a long route can't spam it.
func _report_heat(heat: int) -> void:
	var wanted := get_tree().get_first_node_in_group("wanted")
	if wanted == null or not wanted.has_method("report_crime"):
		return
	for _i in mini(maxi(heat, 0), MAX_HEAT_REPORTS):
		wanted.report_crime(false)


## Sticker value of the full cargo (what a clean run delivers), for a HUD readout.
func cargo_value() -> int:
	return _run.cargo_value() if _run != null else 0
