class_name CrowdPanicDirector
extends Node
## Self-wiring world-life director: when the player commits gun violence
## (WeaponController.crime_committed), the nearby crowd SCATTERS. It finds the
## weapon by group `weapon_controller` (like WantedTracker) and the crowd by group
## `pedestrians`, and uses the unit-tested CrowdPanic model for the scare falloff —
## peds near the shooting bolt, peds across the block barely notice. Drop the node
## in a scene; no per-scene plumbing. Wiring exercised by tests/crowd_panic_probe.gd.
##
## The weapon may arm/appear after this node, so the connection is polled each frame
## until it lands, then processing stops.

## Emitted when a shooting scatters the crowd, with how many peds were spooked.
signal crowd_scattered(scared: int)

## Peds within this distance of a shooting are spooked (linear fear falloff to 0).
@export var scare_radius: float = 24.0
## Max seconds a spooked ped flees, scaled down by distance via the fear model.
@export var flee_seconds: float = 6.0

var _connected: bool = false


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	if _connected:
		set_process(false)
		return
	var weapon := get_tree().get_first_node_in_group("weapon_controller")
	if weapon == null or not weapon.has_signal("crime_committed"):
		return
	if not weapon.crime_committed.is_connected(_on_crime):
		weapon.crime_committed.connect(_on_crime)
	_connected = true
	set_process(false)


## A crime (gunshot) at `crime_pos` spooks every pedestrian within scare_radius,
## fleeing longer the closer they were. Returns nothing; emits crowd_scattered.
func _on_crime(_killed: bool, crime_pos: Vector3) -> void:
	var scared: int = 0
	for ped in get_tree().get_nodes_in_group("pedestrians"):
		var node := ped as Node3D
		if node == null or not node.has_method("scare"):
			continue
		var fear := CrowdPanic.initial_fear(node.global_position, crime_pos, scare_radius)
		if fear > 0.0:
			node.scare(crime_pos, flee_seconds * fear)
			scared += 1
	if scared > 0:
		crowd_scattered.emit(scared)
