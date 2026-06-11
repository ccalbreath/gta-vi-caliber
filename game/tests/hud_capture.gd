extends SceneTree
## HUD beauty-shot harness: instances the gameplay HUD over a backdrop, feeds it
## representative values (health/armor/money/stars/weapon/objective + minimap
## blips), and saves a still so HUD polish can be reviewed without a full world.
## Needs a renderer — run WITHOUT --headless:
##   godot --path game --script res://tests/hud_capture.gd
## Still lands in /tmp/gta6_hud/still.png after a short warmup.

const OUT_DIR := "/tmp/gta6_hud"
const WARMUP_FRAMES := 18

var _frame := 0
var _hud: CanvasLayer = null


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	get_root().set("size", Vector2i(1280, 720))

	# Dim backdrop so the HUD reads against something city-like.
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.13, 0.18)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	get_root().add_child(bg)

	# A fake player + camera so the minimap has a transform to read.
	var player := Node3D.new()
	player.add_to_group("player")
	get_root().add_child(player)
	# Mock health/stats providers so the minimap's vitals arcs have data.
	var health := MockHealth.new()
	health.add_to_group("player_health")
	get_root().add_child(health)
	var stats := MockStats.new()
	stats.add_to_group("player_stats")
	get_root().add_child(stats)
	var cam := Camera3D.new()
	cam.rotation.y = deg_to_rad(35.0)
	get_root().add_child(cam)
	_spawn_blips()

	var packed := load("res://scenes/ui/game_hud.tscn") as PackedScene
	_hud = packed.instantiate()
	get_root().add_child(_hud)
	# Drive the widgets ourselves; suppress the HUD's own observer loop (it would
	# blank weapon/objective text and re-toggle the death overlay without a full
	# game world behind it).
	_hud.set_process_mode(Node.PROCESS_MODE_DISABLED)


func _spawn_blips() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in range(26):
		var n := Node3D.new()
		n.position = Vector3(rng.randf_range(-90, 90), 0, rng.randf_range(-90, 90))
		n.add_to_group("pedestrians" if i % 4 != 0 else "vehicles")
		get_root().add_child(n)
	for i in range(3):
		var p := Node3D.new()
		p.position = Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-60, 60))
		p.add_to_group("police")
		get_root().add_child(p)


func _process(_delta: float) -> bool:
	_frame += 1
	_drive_hud()
	if _frame >= WARMUP_FRAMES:
		_save()
		quit(0)
	return false


func _drive_hud() -> void:
	if _hud == null:
		return
	var vitals: StatBars = _hud.get_node("Vitals")
	vitals.health = 0.72
	vitals.armor = 0.5
	vitals.queue_redraw()
	var stars: WantedStars = _hud.get_node("WantedStars")
	stars.stars = 3
	stars.queue_redraw()
	(_hud.get_node("Minimap") as Control).queue_redraw()
	_hud.get_node("TopRight/Money").text = "$1,284,500"
	_hud.get_node("TopRight/Clock").text = "21:47"
	_hud.get_node("TopRight/Phase").text = "Night"
	_hud.get_node("Weapon/Name").text = "Combat PDW"
	_hud.get_node("Weapon/Ammo").text = "24 / 90"
	_hud.get_node("Quest").visible = true
	_hud.get_node("Quest/Margin/VBox/Title").text = "Reach the marina"
	_hud.get_node("Quest/Margin/VBox/Distance").text = "480 m"
	var cross: Crosshair = _hud.get_node("Crosshair")
	cross.visible = true
	cross.gap = 9.0
	cross.queue_redraw()
	_hud.get_node("Wasted").visible = false


func _save() -> void:
	var img := get_root().get_texture().get_image()
	var path := "%s/still.png" % OUT_DIR
	img.save_png(path)
	print("hud: saved %s" % path)


class MockHealth:
	extends Node

	func fraction() -> float:
		return 0.72

	func is_dead() -> bool:
		return false


class MockStats:
	extends Node
	signal armor_changed(armor: float, max_armor: float)
	signal money_changed(amount: int)
	signal objective_changed(title: String, waypoint)
	var armor: float = 50.0
	var max_armor: float = 100.0
	var money: int = 1284500
	var objective_title: String = "Reach the marina"

	func has_waypoint() -> bool:
		return false
