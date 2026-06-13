extends RefCounted
## Unit tests for the Wardrobe -> Disguise seam the ClothingStore wires up: buying
## and wearing clothes changes the worn looks, and pushing those looks into a
## Disguise drops how well the player matches the description the cops logged. Pure
## (no nodes), so it runs in the headless unit suite. See tests/run_tests.gd for
## the runner contract: test_* methods return true to pass.


# Mirror what ClothingStore._push_look does, model-only: push every worn look into
# the disguise's matching slot.
func _push(wardrobe: Wardrobe, disguise: Disguise) -> void:
	var looks := wardrobe.worn_looks()
	for slot: Variant in looks:
		disguise.set_appearance(str(slot), str(looks[slot]))


func test_worn_looks_feed_disguise_slots() -> bool:
	# Each outfit piece must land in its own Disguise slot with the right look —
	# guards the catalogue slot/look mapping the recognition math depends on.
	var w := Wardrobe.new()
	for id in ["track_suit", "blonde_dye", "ski_mask"]:
		w.buy(id, 1000)
		w.wear(id)
	var d := Disguise.new()
	_push(w, d)
	return (
		d.current("outfit") == "tracksuit"
		and d.current("hair") == "blonde"
		and d.current("mask") == "ski_mask"
	)


func test_changing_clothes_drops_recognition() -> bool:
	# Cops log the starter look; then the player buys a disguise and changes into
	# it, so recognition must fall.
	var w := Wardrobe.new()
	var d := Disguise.new()
	_push(w, d)  # starter casual + buzz on file
	d.log_sighting()
	var before := d.recognition()
	w.buy("track_suit", 1000)
	w.wear("track_suit")
	w.buy("blonde_dye", 1000)
	w.wear("blonde_dye")
	w.buy("ski_mask", 1000)
	w.wear("ski_mask")
	_push(w, d)
	var after := d.recognition()
	return before > after and after < before - 0.5


func test_full_disguise_speeds_evasion() -> bool:
	# A three-slot change should leave only the (unchanged) vehicle slot matching,
	# so evasion clearly speeds up versus the logged look.
	var w := Wardrobe.new()
	var d := Disguise.new()
	_push(w, d)
	d.log_sighting()
	for id in ["track_suit", "blonde_dye", "ski_mask"]:
		w.buy(id, 1000)
		w.wear(id)
	_push(w, d)
	return d.changed_slots() == 3 and d.evasion_speedup() > 2.0


func test_unaffordable_outfit_leaves_look_unchanged() -> bool:
	# Can't afford the suit -> not owned -> can't wear it -> the logged look still
	# matches, so recognition stays high (no free disguise).
	var w := Wardrobe.new()
	var d := Disguise.new()
	_push(w, d)
	d.log_sighting()
	var bought: bool = w.buy("sharp_suit", 10)["success"]
	var wore := w.wear("sharp_suit")
	_push(w, d)
	return not bought and not wore and is_equal_approx(d.recognition(), 1.0)


func test_pushing_same_look_keeps_full_recognition() -> bool:
	# Re-pushing the already-worn look is a no-op for recognition (you didn't
	# actually change anything).
	var w := Wardrobe.new()
	var d := Disguise.new()
	_push(w, d)
	d.log_sighting()
	_push(w, d)
	return is_equal_approx(d.recognition(), 1.0) and d.changed_slots() == 0
