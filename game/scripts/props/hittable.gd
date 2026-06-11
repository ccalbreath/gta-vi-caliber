class_name Hittable
extends StaticBody3D
## A shootable prop. Forwards bullet damage to a Damageable (pure, tested),
## flashes on each hit, and topples + sinks when killed before respawning.
##
## WeaponController finds targets purely by the duck-typed take_damage(amount,
## point, normal) method, so this node needs no special registration — but it
## also joins the "hittables" group for any future area queries.

signal died
signal revived

@export var max_health: float = 60.0
## Seconds the target stays down before popping back up. <= 0 disables respawn.
@export var respawn_delay: float = 4.0
@export var flash_color: Color = Color(1.0, 1.0, 1.0)
## How fast the white hit-flash fades (1/s).
@export var flash_decay: float = 6.0

var _hp: Damageable
var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _flash: float = 0.0
var _dead: bool = false
var _rest_transform: Transform3D


func _ready() -> void:
	_hp = Damageable.new(max_health)
	add_to_group("hittables")
	_rest_transform = transform
	_mesh = _first_mesh(self)
	if _mesh != null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = _source_albedo(_mesh)
		_mesh.material_override = _material


func _process(delta: float) -> void:
	if _flash <= 0.0 or _material == null:
		return
	_flash = maxf(_flash - flash_decay * delta, 0.0)
	_material.emission_enabled = _flash > 0.0
	_material.emission = flash_color * _flash


## Duck-typed entry point called by WeaponController on a hit.
func take_damage(amount: float, _point: Vector3, _normal: Vector3) -> void:
	if _dead:
		return
	_flash = 1.0
	if _hp.apply(amount):
		_die()


func _die() -> void:
	_dead = true
	died.emit()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation:x", deg_to_rad(82.0), 0.35)
	tween.tween_property(self, "position:y", position.y - 0.3, 0.35)
	if respawn_delay > 0.0:
		tween.chain().tween_interval(respawn_delay)
		tween.chain().tween_callback(_respawn)


func _respawn() -> void:
	_hp.revive()
	_dead = false
	_flash = 0.0
	if _material != null:
		_material.emission_enabled = false
	var tween := create_tween()
	tween.tween_property(self, "transform", _rest_transform, 0.25)
	revived.emit()


static func _first_mesh(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var nested := _first_mesh(child)
		if nested != null:
			return nested
	return null


static func _source_albedo(mesh: MeshInstance3D) -> Color:
	var mat := mesh.get_active_material(0)
	if mat is StandardMaterial3D:
		return (mat as StandardMaterial3D).albedo_color
	return Color(0.7, 0.7, 0.72)
