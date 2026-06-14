class_name Enterable
extends RefCounted
## Decides which real buildings the player can enter and where their door is —
## the data layer beneath interiors/shops. A building is enterable if it is named
## or has a public-facing type (shops, offices, civic). The door is placed at the
## midpoint of the footprint's longest edge (its likely street frontage). Pure and
## scene-free so it unit-tests headless (tests/unit/test_enterable.gd).

## OSM building types that get an interior.
const PUBLIC_TYPES := {
	"retail": true,
	"commercial": true,
	"office": true,
	"supermarket": true,
	"hotel": true,
	"civic": true,
	"public": true,
	"hospital": true,
	"church": true,
	"government": true,
}


static func is_enterable(building: Dictionary) -> bool:
	if String(building.get("name", "")) != "":
		return true
	return PUBLIC_TYPES.has(building.get("kind", ""))


## Midpoint of the longest footprint edge (in local metres) — the street door.
static func door_point(footprint: PackedVector2Array) -> Vector2:
	var n := footprint.size()
	if n < 2:
		return Vector2.ZERO if n == 0 else footprint[0]
	var best := 0.0
	var door := (footprint[0] + footprint[1]) * 0.5
	for i in n:
		var a := footprint[i]
		var b := footprint[(i + 1) % n]
		var length := a.distance_to(b)
		if length > best:
			best = length
			door = (a + b) * 0.5
	return door


## Enterable subset of a district's buildings, capped to keep interiors bounded.
static func pick(buildings: Array, max_count: int) -> Array:
	var out: Array = []
	for b in buildings:
		if is_enterable(b):
			out.append(b)
			if out.size() >= max_count:
				break
	return out
