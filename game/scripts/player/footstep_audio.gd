class_name FootstepAudio
extends Node3D
## Plays runtime-synthesized footstep sounds in response to Player's `footstep`
## signal. Pre-bakes one AudioStreamWAV per surface in _ready from
## FootstepAudioModel (no audio binaries) and picks the matching one per step,
## nudging pitch by foot so a walk doesn't sound mechanically identical.
## Pure synthesis/voicing lives in FootstepAudioModel; this node only plays.

const SAMPLE_RATE: int = 22050

var _streams: Dictionary = {}

@onready var _player: AudioStreamPlayer3D = _make_player()


func _ready() -> void:
	for surface in FootstepAudioModel.SURFACES:
		_streams[surface] = _bake_stream(surface)


## Connect to Player.footstep. Selects the surface's stream (falling back to the
## default), varies pitch by foot, and plays a one-shot.
func on_footstep(surface: String, is_left: bool) -> void:
	var key: String = surface if _streams.has(surface) else FootstepAudioModel.FALLBACK_SURFACE
	if not _streams.has(key):
		return
	_player.stream = _streams[key]
	_player.pitch_scale = 1.04 if is_left else 0.97
	_player.play()


func _bake_stream(surface: String) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	# Stable per-surface seed so the timbre is consistent run to run.
	var frames := FootstepAudioModel.step_frames(SAMPLE_RATE, surface, hash(surface) & 0x7fffffff)
	wav.data = FootstepAudioModel.frames_to_wav16(frames)
	return wav


func _make_player() -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	add_child(player)
	return player
