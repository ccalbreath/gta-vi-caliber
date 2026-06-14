class_name BurglaryZone
extends Area3D
## A break-in: step inside to lift the valuables — they go into your fence stash
## (group "fence") as HOT goods, and the burglary draws police heat. Fence them later
## at a FenceCounter (cooled goods fetch more). One haul per break-in (the place is
## cleaned out). A stronger crook hauls MORE of the take — the haul scales with the
## player's PlayerSkills.bonus("strength"), so this CONSUMES the gym's strength skill.
## Self-wires by group (player / fence / wanted / player_skills). Needs a
## CollisionShape3D child; watches the player's collision layer (2). Verified in
## tests/fence_loop_probe.gd + tests/burglary_strength_probe.gd.

signal burgled(category: String, value: int)

## Max extra haul a maxed STRENGTH skill adds (carry the heavy take out): 1.0 = up to
## double the base value at full strength, 0 added with no strength wired in.
const STRENGTH_HAUL_BONUS: float = 1.0

## What this place holds and its sticker value (the fence pays a fraction).
@export var loot_category: String = "jewelry"
@export var loot_value: int = 1200

var _looted: bool = false


func _ready() -> void:
	add_to_group("burglary")
	collision_mask |= 2
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or _looted:
		return
	var fence := get_tree().get_first_node_in_group("fence")
	if fence == null or not fence.has_method("add_loot"):
		return
	var haul := int(round(float(loot_value) * (1.0 + _strength_bonus() * STRENGTH_HAUL_BONUS)))
	var id: String = fence.add_loot(loot_category, haul)
	if id.is_empty():
		return
	_looted = true
	# A break-in is a crime — it draws the cops.
	var wanted := get_tree().get_first_node_in_group("wanted")
	if wanted != null and wanted.has_method("report_crime"):
		wanted.report_crime(false)
	burgled.emit(loot_category, haul)


## The player's STRENGTH proficiency as a 0..1 haul add-on (group "player_skills"); 0 when
## none is wired, so the base haul is exactly unchanged.
func _strength_bonus() -> float:
	var skills := get_tree().get_first_node_in_group("player_skills")
	if skills != null and skills.has_method("bonus"):
		return clampf(float(skills.bonus("strength")), 0.0, 1.0)
	return 0.0
