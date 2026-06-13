class_name HelicopterAudio
extends Node3D
## Runtime-synthesized rotor + siren audio for the police helicopter. Attach as
## a child of PoliceHelicopter; it owns two looping AudioStreamPlayer3Ds built
## in _ready from HelicopterAudioModel (no audio files in the repo, matching
## VehicleAudio). Volumes ease toward their targets so engage/disengage reads
## as the chopper spooling, not a hard mute.

const SAMPLE_RATE: int = 22050
## dB per second the volumes ease at.
const FADE_DB_PER_SEC: float = 30.0

## Blade-pass rate the loop is synthesized for (520 rpm × 2 blades).
@export var pulse_hz: float = HelicopterAudioModel.DEFAULT_PULSE_HZ
## Audible-range scale: the chopper should carry over city noise.
@export var unit_size: float = 26.0

var _rotor: AudioStreamPlayer3D
var _siren: AudioStreamPlayer3D
var _rotor_target_db: float = VehicleAudioModel.SILENT_DB
var _siren_target_db: float = VehicleAudioModel.SILENT_DB


func _ready() -> void:
	_rotor = _make_player(HelicopterAudioModel.rotor_loop_frames(SAMPLE_RATE, pulse_hz))
	_siren = _make_player(HelicopterAudioModel.siren_loop_frames(SAMPLE_RATE))
	# No autoplay: an undeployed chopper is silent. Playback starts only when a
	# voice eases above silent and stops once it eases back, so a helicopter that
	# never deploys (or a scene torn down before it does) holds no active stream
	# to leak.


func _exit_tree() -> void:
	# Release any active playback on teardown so a chopper that is still spun up
	# when its scene is freed (or the engine quits) does not leak the looping
	# AudioStreamPlaybackWAV/AudioStreamWAV pair.
	if _rotor != null and _rotor.playing:
		_rotor.stop()
	if _siren != null and _siren.playing:
		_siren.stop()


func _process(delta: float) -> void:
	_ease(_rotor, _rotor_target_db, delta)
	_ease(_siren, _siren_target_db, delta)


## Drive one voice toward its target volume, starting playback when it first
## needs to be audible and stopping it once it has faded fully back to silent.
func _ease(player: AudioStreamPlayer3D, target_db: float, delta: float) -> void:
	if target_db > VehicleAudioModel.SILENT_DB and not player.playing:
		player.play()
	player.volume_db = move_toward(player.volume_db, target_db, FADE_DB_PER_SEC * delta)
	if (
		player.playing
		and target_db <= VehicleAudioModel.SILENT_DB
		and player.volume_db <= VehicleAudioModel.SILENT_DB
	):
		player.stop()


## Rotor thump while the chopper is deployed. Spinning up eases in; standing
## down silences the voice at once (the chopper also goes invisible) so no
## looping playback is left running to leak if the scene tears down right after.
func set_running(on: bool) -> void:
	_rotor_target_db = 0.0 if on else VehicleAudioModel.SILENT_DB
	if not on:
		_silence(_rotor)


## Pursuit wail layered on top at high heat.
func set_siren(on: bool) -> void:
	_siren_target_db = -6.0 if on else VehicleAudioModel.SILENT_DB
	if not on:
		_silence(_siren)


func _silence(player: AudioStreamPlayer3D) -> void:
	if player != null and player.playing:
		player.stop()
		player.volume_db = VehicleAudioModel.SILENT_DB


func _make_player(frames: PackedFloat32Array) -> AudioStreamPlayer3D:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = VehicleAudioModel.frames_to_wav16(frames)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = frames.size()
	var player := AudioStreamPlayer3D.new()
	player.stream = wav
	player.unit_size = unit_size
	player.volume_db = VehicleAudioModel.SILENT_DB
	add_child(player)
	return player
