class_name FootstepAudioModel
extends RefCounted
## Pure runtime synthesis for footstep sounds — one short percussive burst per
## surface type, no audio binaries in the repo (mirrors VehicleAudioModel's
## approach for M2 vehicle audio). Deterministic and scene-free so it unit-tests
## headless; FootstepAudio (the node) only packs these frames into streams.
## Covered by tests/unit/test_footstep_audio_model.gd.

## Burst length in seconds. Long enough for a body, short enough to stay a step.
const DURATION: float = 0.16

## Per-surface voicing. `decay` is the envelope rate (higher = snappier),
## `lowpass` the one-pole noise brightness (0 dull .. 1 bright), `tone_hz`/
## `tone_mix` an optional resonant body (metal rings, wood knocks), `amp` the
## pre-normalisation loudness. Keys match Footsteps' surface vocabulary.
const SURFACES: Dictionary = {
	"concrete": {"decay": 55.0, "lowpass": 0.70, "tone_hz": 0.0, "tone_mix": 0.0, "amp": 0.80},
	"grass": {"decay": 85.0, "lowpass": 0.22, "tone_hz": 0.0, "tone_mix": 0.0, "amp": 0.50},
	"sand": {"decay": 70.0, "lowpass": 0.18, "tone_hz": 0.0, "tone_mix": 0.0, "amp": 0.45},
	"metal": {"decay": 28.0, "lowpass": 0.88, "tone_hz": 2100.0, "tone_mix": 0.50, "amp": 0.85},
	"wood": {"decay": 48.0, "lowpass": 0.50, "tone_hz": 420.0, "tone_mix": 0.35, "amp": 0.72},
	"water": {"decay": 42.0, "lowpass": 0.62, "tone_hz": 0.0, "tone_mix": 0.0, "amp": 0.68},
}

## Surface used when a key isn't in SURFACES (matches Footsteps.DEFAULT_SURFACE).
const FALLBACK_SURFACE: String = "concrete"


## Voicing params for a surface key, falling back to concrete when unknown.
static func params_for(surface: String) -> Dictionary:
	return SURFACES.get(surface, SURFACES[FALLBACK_SURFACE])


## Synthesize one footstep: an exponentially-decaying low-passed noise burst,
## optionally blended with a decaying tone for resonant surfaces, normalized to
## ±0.9. Deterministic for a given seed so tests and playback are repeatable.
static func step_frames(sample_rate: int, surface: String, rng_seed: int) -> PackedFloat32Array:
	var p := params_for(surface)
	var frame_count := maxi(int(float(sample_rate) * DURATION), 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var frames := PackedFloat32Array()
	frames.resize(frame_count)
	var prev := 0.0
	var peak := 0.0
	var tone_mix: float = p["tone_mix"]
	for i in frame_count:
		var t := float(i) / float(sample_rate)
		var env: float = exp(-float(p["decay"]) * t)
		prev = lerpf(prev, rng.randf_range(-1.0, 1.0), float(p["lowpass"]))
		var sample := prev
		if tone_mix > 0.0:
			sample = lerpf(sample, sin(TAU * float(p["tone_hz"]) * t), tone_mix)
		sample *= env * float(p["amp"])
		frames[i] = sample
		peak = maxf(peak, absf(sample))
	if peak > 0.0:
		for i in frame_count:
			frames[i] = frames[i] / peak * 0.9
	return frames


## Pack float frames into 16-bit little-endian PCM for AudioStreamWAV.
static func frames_to_wav16(frames: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(frames.size() * 2)
	for i in frames.size():
		bytes.encode_s16(i * 2, int(clampf(frames[i], -1.0, 1.0) * 32767.0))
	return bytes
