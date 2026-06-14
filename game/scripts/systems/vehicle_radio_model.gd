class_name VehicleRadioModel
extends RefCounted
## Pure model for the in-vehicle streaming radio (M5: "Radio: streaming music
## channels in vehicles").
##
## Distinct from vehicles/radio_model.gd, which only synthesizes placeholder
## arpeggio loops: this is the station/playlist/now-playing brain — what the HUD
## reads and what advances playback over time. No engine/node deps, so the
## station/track/playback logic is fully unit-tested (test_vehicle_radio_model.gd).
## Tracks are pure metadata (title/artist/duration); the VehicleRadio node maps a
## track to an optional audio resource and degrades to silence if absent.
##
## Per-station playback memory: each station keeps its own track index + position,
## so tuning away and back resumes where you left off (like a real car radio).
## All station/track/artist names are ORIGINAL/fictional.

## Stations, each: {"id", "name", "genre", "tracks": [{"title","artist","duration_sec"}]}.
var _stations: Array[Dictionary] = []
## Per-station playback cursor, parallel to _stations: {"track": int, "pos": float}.
var _cursors: Array[Dictionary] = []
var _station_index: int = 0
var _powered: bool = false


func _init(seed_default: bool = true) -> void:
	if seed_default:
		_seed_default_stations()


## Replace the station list (used by tests / custom line-ups). Resets all cursors
## and clamps the tuned index back into range.
func set_stations(stations: Array[Dictionary]) -> void:
	_stations = stations.duplicate(true)
	_cursors.clear()
	for _station in _stations:
		_cursors.append({"track": 0, "pos": 0.0})
	if _stations.is_empty():
		_station_index = 0
	else:
		_station_index = clampi(_station_index, 0, _stations.size() - 1)


func station_count() -> int:
	return _stations.size()


func is_on() -> bool:
	return _powered


func power_on() -> void:
	_powered = true


func power_off() -> void:
	_powered = false


## Toggle power; returns the new on/off state.
func toggle_power() -> bool:
	_powered = not _powered
	return _powered


func station_index() -> int:
	return _station_index


## The tuned station, or an empty Dictionary if no stations exist.
func current_station() -> Dictionary:
	if _stations.is_empty():
		return {}
	return _stations[_station_index]


## Tune to an absolute index, wrapping around (so it always lands on a station).
func tune_to(index: int) -> void:
	if _stations.is_empty():
		return
	_station_index = wrapi(index, 0, _stations.size())


func next_station() -> void:
	tune_to(_station_index + 1)


func previous_station() -> void:
	tune_to(_station_index - 1)


## The playing track on the tuned station, or an empty Dictionary if none.
func current_track() -> Dictionary:
	var tracks := _current_tracks()
	if tracks.is_empty():
		return {}
	return tracks[_current_cursor()["track"]]


## Index of the playing track within the tuned station's playlist.
func track_index() -> int:
	if _stations.is_empty():
		return 0
	return int(_current_cursor()["track"])


## Seconds elapsed into the current track.
func track_position() -> float:
	if _stations.is_empty():
		return 0.0
	return float(_current_cursor()["pos"])


## Jump to the next track on the tuned station (wrapping), resetting position.
func seek_next_track() -> void:
	_step_track(1)


## Jump to the previous track on the tuned station (wrapping), resetting position.
func seek_previous_track() -> void:
	_step_track(-1)


## Advance playback by delta seconds. No-op when powered off. Rolls over to the
## next track (wrapping the playlist) for every track whose duration elapses, so
## a large delta can cross several tracks.
func advance(delta_sec: float) -> void:
	if not _powered or delta_sec <= 0.0 or _stations.is_empty():
		return
	var tracks := _current_tracks()
	if tracks.is_empty():
		return
	var cursor := _current_cursor()
	var pos := float(cursor["pos"]) + delta_sec
	var track := int(cursor["track"])
	var duration := _duration_of(tracks[track])
	# Carry overflow across as many tracks as the elapsed time spans.
	while duration > 0.0 and pos >= duration:
		pos -= duration
		track = wrapi(track + 1, 0, tracks.size())
		duration = _duration_of(tracks[track])
	cursor["track"] = track
	cursor["pos"] = pos


## HUD one-liner, e.g. "WAVE 87.4 — Neon Mirage by The Pastel Hours". Never empty
## while a station exists; reads "RADIO OFF" when powered down.
func now_playing_text() -> String:
	if not _powered:
		return "RADIO OFF"
	var station := current_station()
	if station.is_empty():
		return "NO SIGNAL"
	var track := current_track()
	if track.is_empty():
		return String(station.get("name", "RADIO"))
	return (
		"%s — %s by %s"
		% [
			String(station.get("name", "RADIO")),
			String(track.get("title", "Untitled")),
			String(track.get("artist", "Unknown"))
		]
	)


# --- internals ---------------------------------------------------------------


func _current_cursor() -> Dictionary:
	return _cursors[_station_index]


func _current_tracks() -> Array:
	if _stations.is_empty():
		return []
	var tracks: Variant = _stations[_station_index].get("tracks", [])
	if tracks is Array:
		return tracks
	return []


func _duration_of(track: Dictionary) -> float:
	return maxf(float(track.get("duration_sec", 0.0)), 0.0)


func _step_track(direction: int) -> void:
	var tracks := _current_tracks()
	if tracks.is_empty():
		return
	var cursor := _current_cursor()
	cursor["track"] = wrapi(int(cursor["track"]) + direction, 0, tracks.size())
	cursor["pos"] = 0.0


func _seed_default_stations() -> void:
	set_stations(
		[
			{
				"id": "wave",
				"name": "WAVE 87.4",
				"genre": "synthwave",
				"tracks":
				[
					{"title": "Neon Mirage", "artist": "The Pastel Hours", "duration_sec": 214.0},
					{"title": "Chrome Sunset", "artist": "Violet Static", "duration_sec": 198.0},
					{"title": "Midnight Drive", "artist": "Lumen Coast", "duration_sec": 232.0}
				]
			},
			{
				"id": "calor",
				"name": "Radio Calor",
				"genre": "latin",
				"tracks":
				[
					{"title": "Fuego en la Bahia", "artist": "Los Caimanes", "duration_sec": 187.0},
					{"title": "Ritmo del Puerto", "artist": "Marisol Vega", "duration_sec": 205.0},
					{"title": "Noche de Palmas", "artist": "El Conjunto Sol", "duration_sec": 221.0}
				]
			},
			{
				"id": "block",
				"name": "Block 99.1",
				"genre": "hip-hop",
				"tracks":
				[
					{"title": "Concrete Heat", "artist": "Dade Kingpin", "duration_sec": 176.0},
					{"title": "Trunk Rattle", "artist": "Lil Mangrove", "duration_sec": 169.0},
					{"title": "Causeway Flow", "artist": "MC Riptide", "duration_sec": 192.0}
				]
			},
			{
				"id": "deep",
				"name": "Deep Current FM",
				"genre": "house",
				"tracks":
				[
					{"title": "Saltwater Pulse", "artist": "Tidal Theory", "duration_sec": 318.0},
					{"title": "Glass Tower", "artist": "Nocturne Bloom", "duration_sec": 287.0}
				]
			},
			{
				"id": "talk",
				"name": "VCX Talk",
				"genre": "talk",
				"tracks":
				[
					{"title": "Hot Take Hour", "artist": "Buck Sterling", "duration_sec": 420.0},
					{"title": "Listener Lines", "artist": "Dr. Coral Vane", "duration_sec": 365.0}
				]
			}
		]
	)
