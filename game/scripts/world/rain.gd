class_name Rain
extends Node3D
## A camera-following rain volume.
##
## A single GPUParticles3D streaks raindrops down through a box that tracks the
## player every frame, so the whole city can be rained on cheaply — the emitter
## only ever covers the area around the camera. Self-contained: drop it into any
## world scene and set `intensity`. World-space particles mean drops keep falling
## naturally as the emitter follows the player rather than snapping with it.
## The intensity→drop-count math is pure (tests/unit/test_rain.gd).

## 0 = dry, 1 = downpour. Scales the live particle count.
@export_range(0.0, 1.0) var intensity: float = 0.5
## Half-extent (m) of the square the rain covers around the player.
@export var area: float = 32.0
## Spawn height (m) above the player the drops fall from.
@export var height: float = 16.0
## Drop count at full intensity.
@export var max_drops: int = 3200

var _particles: GPUParticles3D
var _follow: Node3D


## Particle count for a given intensity, clamped — pure so it's unit-tested.
static func drop_count(intensity_value: float, max_count: int) -> int:
	return int(clampf(intensity_value, 0.0, 1.0) * float(max_count))


func _ready() -> void:
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(area, 1.0, area)
	proc.direction = Vector3(0.0, -1.0, 0.0)
	proc.spread = 2.0
	proc.initial_velocity_min = 11.0
	proc.initial_velocity_max = 14.0
	proc.gravity = Vector3(0.0, -20.0, 0.0)

	var streak := QuadMesh.new()
	streak.size = Vector2(0.022, 0.7)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.84, 0.95, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	streak.material = mat

	_particles = GPUParticles3D.new()
	_particles.amount = maxi(1, drop_count(intensity, max_drops))
	_particles.lifetime = 1.5
	_particles.local_coords = false
	_particles.process_material = proc
	_particles.draw_pass_1 = streak
	_particles.visibility_aabb = AABB(
		Vector3(-area, -height, -area), Vector3(area * 2.0, height * 2.0, area * 2.0)
	)
	_particles.emitting = intensity > 0.0
	add_child(_particles)


func _process(_delta: float) -> void:
	if _follow == null or not is_instance_valid(_follow):
		_follow = _find_follow()
	if _follow != null and _particles != null:
		_particles.global_position = _follow.global_position + Vector3(0.0, height, 0.0)


## Set rain strength at runtime (e.g. from a weather/day-night controller).
func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	if _particles != null:
		_particles.amount = maxi(1, drop_count(intensity, max_drops))
		_particles.emitting = intensity > 0.0


func _find_follow() -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	for node in tree.get_nodes_in_group("player"):
		if node is Node3D:
			return node
	return null
