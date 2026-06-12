extends RefCounted
## Unit tests for RadarModel — the GTA-style radar/minimap blip math.
## Zero-arg test_* methods return true on pass. Run via tests/run_tests.gd.
##
## Convention under test: yaw about +Y, yaw = 0 faces -Z. Radar space is
## x = right, y = UP (player facing → +Y). bearing 0 = ahead, + = right, - = left.

const ORIGIN: Vector3 = Vector3.ZERO


func _approx(a: float, b: float) -> bool:
	return absf(a - b) <= 0.001


func _vec_approx(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) <= 0.001


# --- to_radar: cardinal directions at yaw 0 -------------------------------


## Entity directly in front (-Z at yaw 0) lands on the radar +Y axis: x≈0, y>0.
func test_dead_ahead_maps_to_plus_y() -> bool:
	var p := RadarModel.to_radar(ORIGIN, 0.0, Vector3(0, 0, -50), 100.0, 100.0)
	return _approx(p.x, 0.0) and p.y > 0.0


## At half range, the dead-ahead blip sits at half the radar radius up the +Y axis.
func test_half_range_lands_at_half_radius() -> bool:
	var p := RadarModel.to_radar(ORIGIN, 0.0, Vector3(0, 0, -50), 100.0, 100.0)
	return _vec_approx(p, Vector2(0, 50))


## Right (+X) maps to radar +X and left (-X) to radar -X, both with y≈0.
func test_right_and_left_axis() -> bool:
	var right := RadarModel.to_radar(ORIGIN, 0.0, Vector3(40, 0, 0), 100.0, 100.0)
	var left := RadarModel.to_radar(ORIGIN, 0.0, Vector3(-25, 0, 0), 100.0, 100.0)
	return _vec_approx(right, Vector2(40, 0)) and _vec_approx(left, Vector2(-25, 0))


## Entity behind (+Z at yaw 0) maps to radar -Y.
func test_behind_maps_to_minus_y() -> bool:
	var p := RadarModel.to_radar(ORIGIN, 0.0, Vector3(0, 0, 30), 100.0, 100.0)
	return _approx(p.x, 0.0) and p.y < 0.0 and _vec_approx(p, Vector2(0, -30))


## The y (up) component ignores world Y entirely (radar is a flat XZ disc).
func test_world_height_is_ignored() -> bool:
	var flat := RadarModel.to_radar(ORIGIN, 0.0, Vector3(0, 0, -50), 100.0, 100.0)
	var high := RadarModel.to_radar(ORIGIN, 0.0, Vector3(0, 999, -50), 100.0, 100.0)
	return _vec_approx(flat, high)


# --- to_radar: rotation by player yaw --------------------------------------


## Rotating the player +90° (now facing +X world) makes a +X-world entity read as
## dead ahead (+Y on the radar) instead of to the right.
func test_yaw_90_rotates_blip_to_ahead() -> bool:
	var p := RadarModel.to_radar(ORIGIN, PI / 2.0, Vector3(50, 0, 0), 100.0, 100.0)
	return _vec_approx(p, Vector2(0, 50))


## With the player turned 90°, the original dead-ahead (-Z) entity now reads to
## the player's left (-X on the radar).
func test_yaw_90_pushes_minus_z_to_left() -> bool:
	var p := RadarModel.to_radar(ORIGIN, PI / 2.0, Vector3(0, 0, -50), 100.0, 100.0)
	return _vec_approx(p, Vector2(-50, 0))


## A 180° turn flips a dead-ahead blip to directly behind (-Y).
func test_yaw_180_flips_front_to_back() -> bool:
	var p := RadarModel.to_radar(ORIGIN, PI, Vector3(0, 0, -50), 100.0, 100.0)
	return _vec_approx(p, Vector2(0, -50))


# --- to_radar: scaling & player offset -------------------------------------


## An entity at full range lands exactly radar_radius_px from centre.
func test_full_range_lands_at_radius() -> bool:
	var p := RadarModel.to_radar(ORIGIN, 0.0, Vector3(0, 0, -100), 100.0, 80.0)
	return _approx(p.length(), 80.0) and _vec_approx(p, Vector2(0, 80))


## Projection is relative to the player, not the world origin.
func test_offset_is_relative_to_player() -> bool:
	var player := Vector3(200, 0, 200)
	var entity := Vector3(200, 0, 150)  # 50m in front (-Z) of the player
	var p := RadarModel.to_radar(player, 0.0, entity, 100.0, 100.0)
	return _vec_approx(p, Vector2(0, 50))


## Non-positive range degrades to (0,0) — no division-by-zero / NaN.
func test_zero_range_is_safe() -> bool:
	var p := RadarModel.to_radar(ORIGIN, 0.0, Vector3(0, 0, -50), 0.0, 100.0)
	return p == Vector2.ZERO


# --- is_on_radar -----------------------------------------------------------


## Inside range → on radar; outside → off.
func test_is_on_radar_inside_and_outside() -> bool:
	var inside := RadarModel.is_on_radar(ORIGIN, Vector3(0, 0, -50), 100.0)
	var outside := RadarModel.is_on_radar(ORIGIN, Vector3(0, 0, -150), 100.0)
	return inside and not outside


## The boundary distance is inclusive (planar distance == range counts).
func test_is_on_radar_boundary_inclusive() -> bool:
	return RadarModel.is_on_radar(ORIGIN, Vector3(0, 0, -100), 100.0)


## Height never counts toward planar range.
func test_is_on_radar_ignores_height() -> bool:
	return RadarModel.is_on_radar(ORIGIN, Vector3(0, 5000, -50), 100.0)


# --- clamp_to_ring ---------------------------------------------------------


## Points inside the disc pass through untouched.
func test_clamp_leaves_inside_untouched() -> bool:
	var inside := Vector2(30, -40)  # length 50 < 80
	return _vec_approx(RadarModel.clamp_to_ring(inside, 80.0), inside)


## Points outside are pinned to exactly radar_radius_px, same direction.
func test_clamp_pins_outside_to_ring() -> bool:
	var outside := Vector2(300, 0)
	var clamped := RadarModel.clamp_to_ring(outside, 80.0)
	# Same direction (pure +X) and exactly on the ring.
	return _approx(clamped.length(), 80.0) and _vec_approx(clamped, Vector2(80, 0))


## Direction is preserved for a diagonal off-disc point.
func test_clamp_preserves_diagonal_direction() -> bool:
	var outside := Vector2(100, 100)  # 45°, length ~141
	var clamped := RadarModel.clamp_to_ring(outside, 50.0)
	var expected := Vector2(1, 1).normalized() * 50.0
	return _approx(clamped.length(), 50.0) and _vec_approx(clamped, expected)


# --- faction_color ---------------------------------------------------------


## Known factions return distinct colours and unknown falls back to grey.
func test_faction_colors_distinct_and_fallback() -> bool:
	var police := RadarModel.faction_color("police")
	var enemy := RadarModel.faction_color("enemy")
	var mission := RadarModel.faction_color("mission")
	var unknown := RadarModel.faction_color("banana")
	var distinct := police != enemy and enemy != mission and police != mission
	# Police reads blue (b dominant), enemy red (r dominant), mission yellow.
	var hued := police.b > police.r and enemy.r > enemy.g and mission.r > 0.8 and mission.g > 0.8
	var grey := unknown.r == unknown.g and unknown.g == unknown.b
	return distinct and hued and grey


## Aliases map to the same colour as their canonical faction.
func test_faction_color_aliases() -> bool:
	var gang := RadarModel.faction_color("gang") == RadarModel.faction_color("enemy")
	var obj := RadarModel.faction_color("objective") == RadarModel.faction_color("mission")
	return gang and obj


# --- blips -----------------------------------------------------------------


## One blip per entity, in order, with correct on_radar flags and clamped points.
func test_blips_one_entry_per_entity() -> bool:
	var entities: Array = [
		{"pos": Vector3(0, 0, -50), "faction": "police"},  # in front, on radar
		{"pos": Vector3(0, 0, -300), "faction": "enemy"},  # far ahead, off radar
	]
	var out := RadarModel.blips(ORIGIN, 0.0, entities, 100.0, 100.0)
	if out.size() != 2:
		return false
	var a: Dictionary = out[0]
	var b: Dictionary = out[1]
	var a_ok := bool(a["on_radar"]) and _vec_approx(a["point"], Vector2(0, 50))
	a_ok = a_ok and a["color"] == RadarModel.faction_color("police")
	# Off-radar enemy: not on radar, and its clamped point pinned to the rim.
	var b_ok := not bool(b["on_radar"]) and _approx((b["clamped"] as Vector2).length(), 100.0)
	b_ok = b_ok and (b["point"] as Vector2).length() > 100.0
	return a_ok and b_ok


## blips() carries each entity's faction colour, and an empty list yields none.
func test_blips_color_and_empty() -> bool:
	var entities: Array = [{"pos": Vector3(10, 0, 0), "faction": "vehicle"}]
	var out := RadarModel.blips(ORIGIN, 0.0, entities, 100.0, 100.0)
	var colored: bool = out.size() == 1 and out[0]["color"] == RadarModel.faction_color("vehicle")
	var empty := RadarModel.blips(ORIGIN, 0.0, [], 100.0, 100.0).is_empty()
	return colored and empty


# --- bearing_to ------------------------------------------------------------


## Dead-ahead bearing is ~0, and on top of the player is ~0 (no NaN).
func test_bearing_zero_cases() -> bool:
	var ahead := RadarModel.bearing_to(ORIGIN, 0.0, Vector3(0, 0, -50))
	var on_player := RadarModel.bearing_to(ORIGIN, 0.0, ORIGIN)
	return _approx(ahead, 0.0) and _approx(on_player, 0.0)


## Entity to the right gives a positive bearing (~+PI/2); left gives ~-PI/2.
func test_bearing_sign_left_vs_right() -> bool:
	var right := RadarModel.bearing_to(ORIGIN, 0.0, Vector3(50, 0, 0))
	var left := RadarModel.bearing_to(ORIGIN, 0.0, Vector3(-50, 0, 0))
	return _approx(right, PI / 2.0) and _approx(left, -PI / 2.0)


## Behind the player reads as ±PI (magnitude PI).
func test_bearing_behind_is_pi() -> bool:
	var back := RadarModel.bearing_to(ORIGIN, 0.0, Vector3(0, 0, 50))
	return _approx(absf(back), PI)
