class_name GeoProjection
extends RefCounted
## Projects real-world WGS84 (lat, lon) coordinates into the game's local metric
## space, relative to a district origin. Equirectangular projection: accurate to
## well under a metre across a city-scale district (a few km), which is far below
## what a player can perceive, and it is cheap and exactly invertible.
##
## Axis convention (Godot, Y-up): +X = east, -Z = north, ground on the XZ plane.
## Kept as a pure RefCounted with no scene dependencies so it is unit-tested
## headless (see tests/unit/test_geo_projection.gd).

## Metres per degree of latitude (WGS84 mean). Longitude scales by cos(lat).
const METRES_PER_DEG_LAT: float = 111_320.0

var _lat0: float
var _lon0: float
var _metres_per_deg_lon: float


func _init(origin_lat: float, origin_lon: float) -> void:
	_lat0 = origin_lat
	_lon0 = origin_lon
	_metres_per_deg_lon = METRES_PER_DEG_LAT * cos(deg_to_rad(origin_lat))


## Project a geographic point to a ground-plane position (y = 0).
func to_local(lat: float, lon: float) -> Vector3:
	var east: float = (lon - _lon0) * _metres_per_deg_lon
	var north: float = (lat - _lat0) * METRES_PER_DEG_LAT
	return Vector3(east, 0.0, -north)


## Same projection collapsed to the XZ plane as a Vector2 (x = east, y = -north),
## convenient for 2D polygon work before extrusion.
func to_local_2d(lat: float, lon: float) -> Vector2:
	var east: float = (lon - _lon0) * _metres_per_deg_lon
	var north: float = (lat - _lat0) * METRES_PER_DEG_LAT
	return Vector2(east, -north)


## Inverse: local metric position back to (lat, lon). Useful for map UI / save.
func to_geo(local: Vector3) -> Vector2:
	var lon: float = _lon0 + local.x / _metres_per_deg_lon
	var lat: float = _lat0 - local.z / METRES_PER_DEG_LAT
	return Vector2(lat, lon)
