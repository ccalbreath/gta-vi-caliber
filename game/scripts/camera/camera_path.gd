class_name CameraPath
extends RefCounted
## Pure spline math for cinematic camera moves (M6 capture tooling).
## Centripetal Catmull-Rom through waypoints with an arc-length table for
## constant-speed travel, plus smoothstep easing — the three ingredients a
## dolly shot needs. Scene-free so it unit-tests headless.

## Samples per segment when building the arc-length table; 32 keeps the
## constant-speed error well under a centimetre at shot scale.
const ARC_SAMPLES_PER_SEGMENT: int = 32


## Centripetal Catmull-Rom point at t∈[0,1] across the whole waypoint list.
## Endpoints are duplicated so the curve passes through every waypoint.
static func sample(points: PackedVector3Array, t: float) -> Vector3:
	var n := points.size()
	if n == 0:
		return Vector3.ZERO
	if n == 1:
		return points[0]
	var clamped := clampf(t, 0.0, 1.0)
	var segment_count := n - 1
	var x := clamped * segment_count
	var seg := mini(int(x), segment_count - 1)
	var local_t := x - seg
	var p0 := points[maxi(seg - 1, 0)]
	var p1 := points[seg]
	var p2 := points[seg + 1]
	var p3 := points[mini(seg + 2, n - 1)]
	return _catmull_rom(p0, p1, p2, p3, local_t)


## Arc-length lookup table: cumulative distances at uniform t steps.
## Feed to t_at_distance for constant-speed playback.
static func arc_table(points: PackedVector3Array) -> PackedFloat32Array:
	var samples := maxi((points.size() - 1) * ARC_SAMPLES_PER_SEGMENT, 1)
	var table := PackedFloat32Array()
	table.resize(samples + 1)
	table[0] = 0.0
	var prev := sample(points, 0.0)
	for i in range(1, samples + 1):
		var cur := sample(points, float(i) / samples)
		table[i] = table[i - 1] + prev.distance_to(cur)
		prev = cur
	return table


## Curve parameter t that lies `distance` metres along the path.
static func t_at_distance(table: PackedFloat32Array, distance: float) -> float:
	var total: float = table[table.size() - 1]
	if total <= 0.0:
		return 0.0
	var d := clampf(distance, 0.0, total)
	# Binary search the first entry >= d.
	var lo := 0
	var hi := table.size() - 1
	while lo < hi:
		var mid := (lo + hi) / 2
		if table[mid] < d:
			lo = mid + 1
		else:
			hi = mid
	if lo == 0:
		return 0.0
	var span := table[lo] - table[lo - 1]
	var frac := 0.0 if span <= 0.0 else (d - table[lo - 1]) / span
	return (lo - 1 + frac) / (table.size() - 1)


## Smoothstep ease for shot starts/ends: 0..1 in, 0..1 out.
static func ease_in_out(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	# Centripetal parameterization avoids loops/cusps on uneven waypoints.
	var t0 := 0.0
	var t1 := t0 + _knot(p0, p1)
	var t2 := t1 + _knot(p1, p2)
	var t3 := t2 + _knot(p2, p3)
	var u := lerpf(t1, t2, t)
	var a1 := p0 if t1 == t0 else p0.lerp(p1, (u - t0) / (t1 - t0))
	var a2 := p1 if t2 == t1 else p1.lerp(p2, (u - t1) / (t2 - t1))
	var a3 := p2 if t3 == t2 else p2.lerp(p3, (u - t2) / (t3 - t2))
	var b1 := a1 if t2 == t0 else a1.lerp(a2, (u - t0) / (t2 - t0))
	var b2 := a2 if t3 == t1 else a2.lerp(a3, (u - t1) / (t3 - t1))
	return b1 if t2 == t1 else b1.lerp(b2, (u - t1) / (t2 - t1))


static func _knot(a: Vector3, b: Vector3) -> float:
	return maxf(sqrt(a.distance_to(b)), 0.0001)
