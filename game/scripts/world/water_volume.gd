class_name WaterVolume
extends Area3D
## A body of water the player can swim in.
##
## Joins group "water" so Player._current_water() can find it by overlap (same
## pattern as ladders). The still surface sits at this node's world Y plus
## `surface_offset`; SwimMotion reads that height to decide submersion, while
## the Ocean mesh renders the animated surface above it. Give it a box (or any)
## CollisionShape3D covering the swimmable region and set its monitoring mask to
## the player's physics layer.

## Surface height above the node origin. Keep at 0 to place the water by moving
## the node; nudge it if the visible mesh and the collision box don't share a Y.
@export var surface_offset: float = 0.0


func _ready() -> void:
	add_to_group("water")


## World-space Y of the still water surface — the line submersion is measured
## against. Waves displace the mesh visually but not this swimmable plane.
func surface_y() -> float:
	return global_position.y + surface_offset
