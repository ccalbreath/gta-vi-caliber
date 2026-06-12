extends RefCounted
## Scene composition checks for the current main Florida/Miami map.

const MIAMI_SCENE := preload("res://scenes/world/miami.tscn")


func test_miami_scene_includes_florida_backdrop_and_game_hud() -> bool:
	var packed := MIAMI_SCENE
	if packed == null:
		return false
	var scene := packed.instantiate()
	var ok := scene.has_node("FloridaBackdrop") and scene.has_node("GameHud")
	scene.free()
	return ok


func test_miami_game_hud_contains_full_map() -> bool:
	var packed := MIAMI_SCENE
	if packed == null:
		return false
	var scene := packed.instantiate()
	var hud := scene.get_node("GameHud")
	var ok := hud.has_node("FullMap") and hud.has_node("Minimap")
	scene.free()
	return ok
