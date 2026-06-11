class_name OceanWaves
extends RefCounted
## Gerstner ocean surface (roadmap M4 "Ocean v1"): a sum of directional Gerstner
## waves giving each surface point a vertical bob plus a horizontal "choppiness"
## that sharpens crests and flattens troughs like real water. Pure and
## deterministic (position + time + wave set → displacement/height/normal), so it
## unit-tests headless (tests/unit/test_ocean_waves.gd).
##
## The Ocean node CPU-displaces a grid with `displacement`; boats sample
## `surface_height` for buoyancy (cheap vertical-only approximation, ignoring the
## horizontal shift). `normal` is a finite-difference of the height field — unit
## length, and exactly up on flat water.


## A wave: {dir: Vector2, amplitude: m, wavelength: m, steepness: 0..1, speed: m/s}.
## A sensible rolling sea: one long swell plus shorter cross-chop.
static func default_waves() -> Array:
	return [
		{
			"dir": Vector2(1.0, 0.25),
			"amplitude": 0.55,
			"wavelength": 26.0,
			"steepness": 0.55,
			"speed": 3.0
		},
		{
			"dir": Vector2(0.6, 1.0),
			"amplitude": 0.32,
			"wavelength": 15.0,
			"steepness": 0.6,
			"speed": 2.2
		},
		{
			"dir": Vector2(-0.8, 0.5),
			"amplitude": 0.18,
			"wavelength": 8.0,
			"steepness": 0.7,
			"speed": 1.6
		},
	]


static func _wavenumber(wavelength: float) -> float:
	return TAU / maxf(wavelength, 0.001)


## Full Gerstner displacement of the surface point that rests at (x, z), relative
## to the flat plane. .y is the bob; .x/.z are the choppiness shift.
static func displacement(x: float, z: float, t: float, waves: Array) -> Vector3:
	var d := Vector3.ZERO
	var n := maxi(waves.size(), 1)
	for w in waves:
		var dir := (w["dir"] as Vector2).normalized()
		var a := float(w["amplitude"])
		if a <= 0.0:
			continue
		var k := _wavenumber(float(w["wavelength"]))
		var theta := k * (dir.x * x + dir.y * z) - float(w["speed"]) * k * t
		# Per-wave steepness, sum-normalised so stacked waves can't loop the mesh.
		var qi := float(w["steepness"]) / (k * a * n)
		var c := cos(theta)
		d.x += qi * a * dir.x * c
		d.z += qi * a * dir.y * c
		d.y += a * sin(theta)
	return d


## Vertical surface height at world (x, z) — the cheap buoyancy sample (ignores
## the horizontal Gerstner shift). Relative to the flat water line.
static func surface_height(x: float, z: float, t: float, waves: Array) -> float:
	var h := 0.0
	for w in waves:
		var dir := (w["dir"] as Vector2).normalized()
		var k := _wavenumber(float(w["wavelength"]))
		h += float(w["amplitude"]) * sin(k * (dir.x * x + dir.y * z) - float(w["speed"]) * k * t)
	return h


## Largest possible |surface_height| for a wave set — the sum of amplitudes.
static func max_height(waves: Array) -> float:
	var m := 0.0
	for w in waves:
		m += absf(float(w["amplitude"]))
	return m


## Foam factor 0..1 at (x, z): whitecaps gather on the crests, so foam rises as
## the surface nears its peak height. `crest_start` is the normalised height
## (0 trough .. 1 max crest) where foam begins. Flat water has no foam.
static func foam(x: float, z: float, t: float, waves: Array, crest_start: float = 0.55) -> float:
	var mh := max_height(waves)
	if mh <= 0.0:
		return 0.0
	var norm := surface_height(x, z, t, waves) / mh * 0.5 + 0.5
	return smoothstep(crest_start, 1.0, clampf(norm, 0.0, 1.0))


## Surface normal at (x, z), by central difference of the height field. Unit
## length; exactly Vector3.UP on flat water.
static func normal(x: float, z: float, t: float, waves: Array, eps: float = 0.1) -> Vector3:
	var hl := surface_height(x - eps, z, t, waves)
	var hr := surface_height(x + eps, z, t, waves)
	var hb := surface_height(x, z - eps, t, waves)
	var hf := surface_height(x, z + eps, t, waves)
	return Vector3(hl - hr, 2.0 * eps, hb - hf).normalized()
