class_name BurglaryZone
extends Area3D
## A break-in: step inside to lift the valuables — they go into your fence stash
## (group "fence") as HOT goods, and the burglary draws police heat. Fence them later
## at a FenceCounter (cooled goods fetch more). One haul per break-in (the place is
## cleaned out). Self-wires by group (player / fence / wanted). Needs a
## CollisionShape3D child; watches the player's collision layer (2). Verified in
## tests/fence_loop_probe.gd.

signal burgled(category: String, value: int)

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
	var id: String = fence.add_loot(loot_category, loot_value)
	if id.is_empty():
		return
	_looted = true
	# A break-in is a crime — it draws the cops.
	var wanted := get_tree().get_first_node_in_group("wanted")
	if wanted != null and wanted.has_method("report_crime"):
		wanted.report_crime(false)
	burgled.emit(loot_category, loot_value)
