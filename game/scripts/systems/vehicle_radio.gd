class_name VehicleRadio
extends Node
## Scene bridge for the streaming vehicle radio (M5: "Radio: streaming music
## channels in vehicles").
##
## Owns a VehicleRadioModel (pure, tested) and an AudioStreamPlayer. The car turns
## it on while a driver is aboard and off on exit; tune/seek switch station/track.
## There are NO music assets in the repo yet, so audio degrades gracefully: a
## station's track resolves to res://audio/radio/<station_id>/<track_index>.ogg
## only if ResourceLoader.exists() finds one — otherwise it stays silent and the
## model still advances, so the HUD now-playing readout keeps working.
##
## Joins group "vehicle_radio" so a HUD or vehicle controller can find it without
## a hard reference.

signal now_playing_changed(text: String)
signal station_changed(index: int)

## Folder convention for optional per-track streams (none ship in-repo today).
const AUDIO_ROOT: String = "res://audio/radio"

var _model: VehicleRadioModel
var _player: AudioStreamPlayer
var _last_text: String = ""
var _bound_track_key: String = ""


func _ready() -> void:
	_model = VehicleRadioModel.new()
	_player = AudioStreamPlayer.new()
	add_child(_player)
	add_to_group("vehicle_radio")


## Driver entered: power on and start streaming the tuned station.
func turn_on() -> void:
	_model.power_on()
	_refresh_audio(true)
	_emit_state()


## Driver exited: power off and stop audio.
func turn_off() -> void:
	_model.power_off()
	_player.stop()
	_bound_track_key = ""
	_emit_state()


## Toggle power; returns the new on/off state.
func toggle_power() -> bool:
	if _model.toggle_power():
		_refresh_audio(true)
	else:
		_player.stop()
		_bound_track_key = ""
	_emit_state()
	return _model.is_on()


func next_station() -> void:
	_model.next_station()
	_refresh_audio(true)
	_emit_state()


func previous_station() -> void:
	_model.previous_station()
	_refresh_audio(true)
	_emit_state()


func tune_to(index: int) -> void:
	_model.tune_to(index)
	_refresh_audio(true)
	_emit_state()


func seek_next_track() -> void:
	_model.seek_next_track()
	_refresh_audio(true)
	_emit_state()


func station_name() -> String:
	return String(_model.current_station().get("name", ""))


func now_playing_text() -> String:
	return _model.now_playing_text()


func _process(delta: float) -> void:
	if not _model.is_on():
		return
	_model.advance(delta)
	# When the model rolls into a new track, rebind the stream (if any exists).
	if _track_key() != _bound_track_key:
		_refresh_audio(true)
	_emit_state()


## Resolve the optional stream for the tuned station/track and (re)start it.
## Missing assets leave the player silent without error.
func _refresh_audio(restart: bool) -> void:
	if not _model.is_on():
		return
	var path := _stream_path()
	_bound_track_key = _track_key()
	if path.is_empty() or not ResourceLoader.exists(path):
		_player.stream = null
		return
	var stream := load(path)
	if stream is AudioStream:
		_player.stream = stream
		if restart:
			_player.play()


func _stream_path() -> String:
	var station := _model.current_station()
	if station.is_empty():
		return ""
	var station_id := String(station.get("id", ""))
	if station_id.is_empty():
		return ""
	return "%s/%s/%d.ogg" % [AUDIO_ROOT, station_id, _model.track_index()]


func _track_key() -> String:
	return "%d:%d" % [_model.station_index(), _model.track_index()]


func _emit_state() -> void:
	var text := _model.now_playing_text()
	if text != _last_text:
		_last_text = text
		now_playing_changed.emit(text)
	station_changed.emit(_model.station_index())
