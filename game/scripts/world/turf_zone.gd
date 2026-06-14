class_name TurfZone
extends Area3D
## A capturable gang turf: stand inside and your influence over this district climbs
## (capture_rate per second); fill it and you TAKE the turf from the rival gang that
## holds it. Step out and the climb stops. Every zone feeds the shared
## GangTerritoryController (group "gang_territory"), so the whole city's turf map is
## one state. The genre's gang-takeover loop, as a hold-the-ground activity rather
## than a transaction.
##
## A fitter player contests turf FASTER — the accrual scales with the player's
## PlayerSkills.bonus("stamina"), so this CONSUMES the gym's stamina skill (you can keep
## up the pressure longer). Self-wires by group (player / gang_territory / player_skills).
## Needs a CollisionShape3D child; watches the player's collision layer (2). Verified in
## tests/turf_zone_probe.gd + tests/turf_stamina_probe.gd.

signal influence_changed(district_id: String, influence: float)
signal captured(district_id: String, from_owner: String)

## Max extra capture speed a maxed STAMINA skill adds: 1.0 = up to twice as fast at full
## stamina, 0 added with no stamina wired in.
const STAMINA_CAPTURE_BONUS: float = 1.0

## Influence gained per second the player holds the zone (1.0 captures it).
@export var capture_rate: float = 0.2
## The GangTerritory district id this zone captures (must exist in the map).
@export var district_id: String = "downtown"

var _player_body: Node = null


func _ready() -> void:
	add_to_group("turf_zone")
	_warn_on_duplicate_district()
	collision_mask |= 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_body = body


func _on_body_exited(body: Node) -> void:
	if body == _player_body:
		_player_body = null


func _process(delta: float) -> void:
	# Hold the ground: only accrue while a still-valid player body is inside (guards
	# a stale ref if the player is freed mid-hold without a body_exited).
	if not is_instance_valid(_player_body) or delta <= 0.0:
		return
	var territory := _territory()
	if territory == null or not territory.has_district(district_id):
		return
	if territory.owner_of(district_id) == GangTerritory.PLAYER_OWNER:
		return  # already ours — nothing to take
	var rate := capture_rate * (1.0 + _stamina_bonus() * STAMINA_CAPTURE_BONUS)
	territory.add_influence(district_id, rate * delta)
	var influence := territory.influence_in(district_id)
	if influence >= 1.0:
		# `captured` is the canonical completion event — don't also emit a
		# progress tick at 1.0 (it would race the owner flip for HUD subscribers).
		_capture(territory)
		return
	influence_changed.emit(district_id, influence)


## Flip the district to the player once influence is full, and tell the controller.
func _capture(territory: GangTerritory) -> void:
	var from_owner := territory.owner_of(district_id)
	if not territory.take_over(district_id):
		return
	captured.emit(district_id, from_owner)
	var controller := get_tree().get_first_node_in_group("gang_territory")
	if controller != null and controller.has_method("report_capture"):
		controller.report_capture(district_id, from_owner)


## Warn a scene author who placed two zones for the same district (they'd accrue at
## double rate — the take_over guard still prevents a double capture).
func _warn_on_duplicate_district() -> void:
	for zone: Variant in get_tree().get_nodes_in_group("turf_zone"):
		if zone != self and zone.district_id == district_id:
			push_warning("TurfZone: duplicate district_id '%s' — double accrual" % district_id)
			return


## The shared GangTerritory from the controller (null if none is wired in).
func _territory() -> GangTerritory:
	var controller := get_tree().get_first_node_in_group("gang_territory")
	if controller == null or not controller.has_method("territory"):
		return null
	return controller.territory()


## The player's STAMINA proficiency as a 0..1 capture-speed add-on (group "player_skills");
## 0 when none is wired, so the base capture rate is exactly unchanged.
func _stamina_bonus() -> float:
	var skills := get_tree().get_first_node_in_group("player_skills")
	if skills != null and skills.has_method("bonus"):
		return clampf(float(skills.bonus("stamina")), 0.0, 1.0)
	return 0.0
