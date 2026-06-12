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


func test_miami_keeps_cinematic_quality_floor() -> bool:
	var packed := MIAMI_SCENE
	if packed == null:
		return false
	var scene := packed.instantiate()
	var world_quality := scene.get_node("WorldEnvironment") as WorldQuality
	var ok := (
		world_quality != null and world_quality.minimum_tier == CinematicEnvironment.Quality.MEDIUM
	)
	scene.free()
	return ok


func test_miami_render_grade_keeps_geometry_readable() -> bool:
	var packed := MIAMI_SCENE
	if packed == null:
		return false
	var scene := packed.instantiate()
	var world_quality := scene.get_node("WorldEnvironment") as WorldQuality
	var sun := scene.get_node("Sun") as DirectionalLight3D
	var env := world_quality.environment if world_quality != null else null
	var ok := (
		env != null
		and env.tonemap_exposure <= 0.65
		and env.ambient_light_energy <= 0.55
		and env.adjustment_brightness <= 0.9
		and sun != null
		and sun.light_energy <= 1.0
	)
	scene.free()
	return ok
