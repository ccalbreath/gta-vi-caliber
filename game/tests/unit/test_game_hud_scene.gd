extends RefCounted
## Scene composition checks for the gameplay HUD.

const GAME_HUD_SCENE := preload("res://scenes/ui/game_hud.tscn")


func test_game_hud_includes_minimap_and_full_map() -> bool:
	var packed := GAME_HUD_SCENE
	if packed == null:
		return false
	var hud := packed.instantiate()
	var ok := hud.has_node("Minimap") and hud.has_node("FullMap")
	hud.free()
	return ok


func test_full_map_node_uses_full_map_script() -> bool:
	var packed := GAME_HUD_SCENE
	if packed == null:
		return false
	var hud := packed.instantiate()
	var full_map := hud.get_node("FullMap") as FullMap
	var ok := full_map != null
	hud.free()
	return ok
