class_name BuildingFacade
extends Node3D
## Shelf-stock building wrapper (docs/ASSET_PIPELINE.md §11, Tier C): maps a
## generated building's named material slots (WALL / TRIM / GLASS / ROOF /
## DETAIL / ACC*) onto the shared ambientCG facade sets, so every building in
## the library reuses the same textures (one copy in game/assets/materials/)
## and the GLBs stay geometry-only and tiny. Per-building variety comes from
## the exported wall set + tints here, not from duplicated textures.
##
## GLASS is given a warm window emission so a sibling NightWindowEmission node
## lights the windows at night on the shared day/night clock.

const TRIM_SET := "res://assets/materials/concrete_sidewalk_01"
## Solid-colour slots: name -> [Color, roughness].
const SOLID_SLOTS := {
	"ROOF": [Color(0.16, 0.15, 0.14), 0.95],
	"DETAIL": [Color(0.4, 0.4, 0.38), 0.7],
	"ACC1": [Color(0.2, 0.4, 0.5), 0.6],
	"ACC2": [Color(0.7, 0.4, 0.3), 0.6],
}

## Facade material folder for the walls (a PbrMaterial.from_set dir).
@export_dir var wall_set: String = "res://assets/materials/facade_stucco_01"

## Albedo tint multiplied over the wall texture (per-building colour).
@export var wall_tint: Color = Color(1, 1, 1)

## Window glass base colour (kept dark; metallic + low roughness for reflection).
@export var glass_color: Color = Color(0.1, 0.13, 0.18)


func _ready() -> void:
	for mesh in find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			var slot := src.resource_name if src else ""
			mi.set_surface_override_material(s, _material_for(slot))


func _material_for(slot: String) -> Material:
	if slot == "WALL":
		var w := PbrMaterial.from_set(wall_set, false, 0.25)
		w.albedo_color = wall_tint
		return w
	if slot == "TRIM":
		return PbrMaterial.from_set(TRIM_SET, false, 0.25)
	if slot == "GLASS":
		var g := StandardMaterial3D.new()
		g.albedo_color = glass_color
		g.metallic = 0.4
		g.roughness = 0.12
		g.emission_enabled = true
		g.emission = Color(1.0, 0.82, 0.55)
		g.emission_energy_multiplier = 0.0  # lit by NightWindowEmission at night
		return g
	if SOLID_SLOTS.has(slot):
		return _solid(SOLID_SLOTS[slot][0], SOLID_SLOTS[slot][1])
	return _solid(Color(0.85, 0.85, 0.82), 0.7)


func _solid(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m
