class_name ClothingStore
extends Area3D
## A walk-in clothes shop: step inside and the store kits you out in its disguise
## outfit — buying any pieces you don't already own (charged through PlayerStats)
## and wearing them — then re-skins the player's live Disguise. That closes the
## genre staple: change clothes to drop how well the cops still match their
## description of you, so a search gives up faster.
##
## The player's clothes (ownership + what's worn) live on the DisguiseController
## (group "player_disguise"), NOT on the store, so a piece bought at one store is
## free to wear at the next — the store just sells into that shared Wardrobe and
## skips anything already worn. Self-wires by group (player / player_stats /
## player_disguise). Needs a CollisionShape3D child; watches the player layer (2).
##
## Verified end-to-end in tests/clothing_store_probe.gd; the underlying
## Wardrobe->Disguise recognition math is unit-tested in
## tests/unit/test_wardrobe_disguise_link.gd.

signal outfit_changed(worn_ids: Array)

## Wardrobe item ids the store kits you out in on entry (at most one per slot).
## Defaults to a full disguise — track suit + blonde dye + ski mask — so a clean
## entry changes three of the four appearance slots.
@export var outfit_ids: PackedStringArray = ["track_suit", "blonde_dye", "ski_mask"]


func _ready() -> void:
	add_to_group("clothing_store")
	collision_mask |= 2
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var controller := get_tree().get_first_node_in_group("player_disguise")
	if controller == null or not controller.has_method("wardrobe"):
		return
	var wardrobe: Wardrobe = controller.wardrobe()
	if wardrobe == null:
		return
	var worn := _kit_out(wardrobe)
	if worn.is_empty():
		return  # nothing changed (already wearing it all) — no re-skin, no signal
	controller.refresh_disguise()
	outfit_changed.emit(worn)


## Buy (when needed and affordable) and wear each configured outfit piece that the
## player isn't already wearing. Returns the item ids actually changed this visit.
func _kit_out(wardrobe: Wardrobe) -> Array:
	var stats := get_tree().get_first_node_in_group("player_stats")
	var worn: Array = []
	for id_variant: Variant in outfit_ids:
		var id := str(id_variant)
		if not wardrobe.has_item(id):
			continue
		if wardrobe.worn_in(wardrobe.slot_of(id)) == id:
			continue  # already wearing this exact piece
		if not wardrobe.owns(id) and not _try_buy(wardrobe, id, stats):
			continue
		if wardrobe.wear(id):
			worn.append(id)
	return worn


## Charge the player for one item through PlayerStats; true if it was bought. Never
## grants an item the wallet can't actually be charged for (no free disguise).
func _try_buy(wardrobe: Wardrobe, id: String, stats: Node) -> bool:
	if stats == null or not ("money" in stats) or not stats.has_method("spend_money"):
		return false
	var result := wardrobe.buy(id, int(stats.money))
	if not result.get("success", false):
		return false
	stats.spend_money(int(result["cost"]))
	return true
