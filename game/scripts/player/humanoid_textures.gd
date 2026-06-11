class_name HumanoidTextures
extends RefCounted
## Procedural, cached surface-detail normal maps for the character.
##
## Synchronous on purpose — no async NoiseTexture — so headless import and unit
## tests stay deterministic. Each map is generated once and shared across every
## body, so a whole crowd pays the cost a single time. They are applied with
## local-space triplanar projection, which needs neither UVs nor tangents (the
## procedural body meshes carry neither). Covered by
## tests/unit/test_humanoid_textures.gd.

const SIZE: int = 64

static var _skin: ImageTexture
static var _fabric: ImageTexture
static var _skin_alb: ImageTexture
static var _fabric_alb: ImageTexture


## Fine isotropic pore detail for skin.
static func skin_normal() -> Texture2D:
	if _skin == null:
		_skin = _to_normal(_skin_height(), 0.7)
	return _skin


## Subtle skin albedo variation (mottling + faint redness) — multiplied onto the
## flat skin_color so flesh isn't a dead-uniform plastic tone.
static func skin_albedo() -> Texture2D:
	if _skin_alb == null:
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
		for y in SIZE:
			for x in SIZE:
				var v: float = 0.9 + 0.1 * _vnoise(x * 0.6, y * 0.6)
				var red: float = 0.05 * _vnoise(x * 0.3 + 9.0, y * 0.3 - 4.0)
				img.set_pixel(
					x, y, Color(clampf(v + red, 0.0, 1.0), v, clampf(v - red * 0.5, 0.0, 1.0))
				)
		_skin_alb = ImageTexture.create_from_image(img)
	return _skin_alb


## Subtle fabric albedo: threads catch a touch more light than the weave gaps.
static func fabric_albedo() -> Texture2D:
	if _fabric_alb == null:
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
		var f: float = TAU * 8.0 / float(SIZE)
		for y in SIZE:
			for x in SIZE:
				var w: float = 0.86 + 0.14 * (0.5 + 0.5 * maxf(sin(x * f), sin(y * f)))
				img.set_pixel(x, y, Color(w, w, w))
		_fabric_alb = ImageTexture.create_from_image(img)
	return _fabric_alb


## A woven warp/weft ridge pattern for clothing.
static func fabric_normal() -> Texture2D:
	if _fabric == null:
		_fabric = _to_normal(_fabric_height(), 1.1)
	return _fabric


## Pore micro-detail: two octaves of smooth value noise.
static func _skin_height() -> PackedFloat32Array:
	var h := PackedFloat32Array()
	h.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			var v: float = _vnoise(x * 0.5, y * 0.5) * 0.6 + _vnoise(x * 1.7, y * 1.7) * 0.4
			h[y * SIZE + x] = v
	return h


## Plain-weave fabric: interleaved orthogonal ridges (warp over weft).
static func _fabric_height() -> PackedFloat32Array:
	var h := PackedFloat32Array()
	h.resize(SIZE * SIZE)
	var f: float = TAU * 8.0 / float(SIZE)
	for y in SIZE:
		for x in SIZE:
			h[y * SIZE + x] = 0.5 + 0.25 * maxf(sin(x * f), sin(y * f))
	return h


## Tileable smooth value noise in [0, 1] from a hashed lattice (smoothstep blend).
static func _vnoise(fx: float, fy: float) -> float:
	var x0: int = int(floor(fx))
	var y0: int = int(floor(fy))
	var tx: float = fx - float(x0)
	var ty: float = fy - float(y0)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var top: float = lerpf(_hash(x0, y0), _hash(x0 + 1, y0), tx)
	var bot: float = lerpf(_hash(x0, y0 + 1), _hash(x0 + 1, y0 + 1), tx)
	return lerpf(top, bot, ty)


static func _hash(x: int, y: int) -> float:
	var n: int = (x * 73856093) ^ (y * 19349663)
	n = (n << 13) ^ n
	n = n * (n * n * 15731 + 789221) + 1376312589
	return float(n & 0x7fffffff) / float(0x7fffffff)


## Central-difference a height field into a tangent-space normal map.
static func _to_normal(height: PackedFloat32Array, strength: float) -> ImageTexture:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var left: float = height[y * SIZE + _wrap(x - 1)]
			var right: float = height[y * SIZE + _wrap(x + 1)]
			var up: float = height[_wrap(y - 1) * SIZE + x]
			var down: float = height[_wrap(y + 1) * SIZE + x]
			var n := Vector3((left - right) * strength, (up - down) * strength, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	return ImageTexture.create_from_image(img)


static func _wrap(i: int) -> int:
	return (i + SIZE) % SIZE
