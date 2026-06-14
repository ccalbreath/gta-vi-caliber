class_name FenceCounter
extends Area3D
## The fence's shop: step in to sell your whole stolen-goods stash for cash — the
## fence pays their fraction, docked for HOT (recently-stolen) goods. Sells via the
## shared FenceController (group "fence"). Self-wires by group (player / player_stats
## / fence). Needs a CollisionShape3D child; watches the player's collision layer
## (2). Verified in tests/fence_loop_probe.gd.

signal fenced(proceeds: int)


func _ready() -> void:
	add_to_group("fence_counter")
	collision_mask |= 2
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var fence := get_tree().get_first_node_in_group("fence")
	# Nothing to sell when the stash is empty. (A stash of only quote-floored-to-$0
	# trinkets would still clear for $0 here — acceptable: they're worth ~nothing.)
	if fence == null or not fence.has_method("sell_all") or fence.inventory_count() <= 0:
		return
	# Confirm the proceeds can be paid out before sell_all() clears the stash.
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats == null or not stats.has_method("add_money"):
		return
	var proceeds: int = fence.sell_all()
	if proceeds > 0:
		stats.add_money(proceeds)
	fenced.emit(proceeds)
