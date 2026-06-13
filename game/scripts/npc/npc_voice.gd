class_name NpcVoice
extends RefCounted
## Turns an NPC's archetype + a written line into operating-system text-to-speech
## parameters, and decides WHO is allowed to speak right now. The city already
## talks — NpcDialogue/NpcConversation pick the lines and Citizen floats them as
## speech bubbles — this layer lets those lines come out as an actual voice
## through DisplayServer's OS TTS, so two citizens chatting past each other are
## HEARD, not just read.
##
## Scene-free and deterministic so it unit-tests headless
## (tests/unit/test_npc_voice.gd). The OS TTS channel is a single serialized
## voice, so Citizen passes DisplayServer.tts_is_speaking() in as `channel_busy`
## and we simply decline to queue while it is in use — no manager node, no
## autoload (AGENTS.md forbids new autoloads). Each archetype maps to a stable
## voice slot plus a pitch/rate character, so the Doomsday Barista rumbles slowly
## and the Over-Caffeinated Intern gabbles.

## Per-archetype voice character. `slot` spreads archetypes across whatever OS
## voices are installed (taken modulo the available count); pitch/rate shape the
## delivery. A `mute` archetype (the mime) is "heard" as silence — its bubble
## still shows. Keyed by the NpcArchetypes voice id.
const PROFILES: Dictionary = {
	"doomsday": {"slot": 0, "pitch": 0.7, "rate": 0.85},
	"influencer": {"slot": 1, "pitch": 1.5, "rate": 1.35},
	"method_actor": {"slot": 2, "pitch": 1.0, "rate": 0.8},
	"conspiracy": {"slot": 3, "pitch": 0.95, "rate": 1.2},
	"yogi": {"slot": 4, "pitch": 0.85, "rate": 0.75},
	"stunt_double": {"slot": 5, "pitch": 1.1, "rate": 1.45},
	"mime": {"slot": 6, "pitch": 1.0, "rate": 1.0, "mute": true},
	"intern": {"slot": 7, "pitch": 1.3, "rate": 1.5},
	"philosopher": {"slot": 8, "pitch": 0.8, "rate": 0.8},
	"food_critic": {"slot": 9, "pitch": 1.05, "rate": 0.95},
	"life_coach": {"slot": 10, "pitch": 1.2, "rate": 1.25},
	"weather": {"slot": 11, "pitch": 1.1, "rate": 1.3},
}

## Clamp ranges so a wild profile can't ask the OS synth for something silly.
const PITCH_MIN: float = 0.6
const PITCH_MAX: float = 1.8
const RATE_MIN: float = 0.6
const RATE_MAX: float = 1.8


## TTS parameters for a voice given how many OS voices are installed: returns
## {voice_index, pitch, rate, mute}. voice_index is always a valid index into a
## list of `voice_count` voices (0 when none), so the caller never indexes out of
## range or divides by zero. An unknown voice derives a stable slot from the
## string hash, so even ad-hoc archetypes get a consistent character.
static func params_for(voice: String, voice_count: int) -> Dictionary:
	var profile: Dictionary = PROFILES.get(voice, {})
	var slot: int = int(profile.get("slot", absi(voice.hash())))
	var count: int = maxi(voice_count, 1)
	return {
		"voice_index": posmod(slot, count),
		"pitch": clampf(float(profile.get("pitch", 1.0)), PITCH_MIN, PITCH_MAX),
		"rate": clampf(float(profile.get("rate", 1.0)), RATE_MIN, RATE_MAX),
		"mute": bool(profile.get("mute", false)),
	}


## What the synth should actually say for a written line, or "" when nothing
## should be spoken. Strips purely-visual lines — a mime's "(gestures at a wall)",
## an ellipsis murmur, art with no words — so the OS voice never reads stage
## directions aloud, and drops parenthetical asides inside an otherwise spoken
## line. A line with no letters or digits left is not worth voicing.
static func speakable(text: String) -> String:
	var stripped := _strip_parentheticals(text).strip_edges()
	for c in stripped:
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9"):
			return stripped
	return ""


## Should this NPC take the single OS voice channel right now? Decline when the
## channel is busy (we never build a backlog), when the speaker is too far to be
## worth voicing (OS TTS is not spatial, so only near NPCs speak), or when this
## speaker spoke too recently. Pure, so the policy is unit-tested.
static func should_speak(
	distance: float,
	max_distance: float,
	time_since_last: float,
	cooldown: float,
	channel_busy: bool
) -> bool:
	if channel_busy:
		return false
	if distance > max_distance:
		return false
	return time_since_last >= cooldown


## Drop parenthetical asides, collapsing what's left. Unbalanced parentheses are
## tolerated (depth never goes negative).
static func _strip_parentheticals(text: String) -> String:
	var out := ""
	var depth := 0
	for c in text:
		if c == "(":
			depth += 1
		elif c == ")":
			depth = maxi(depth - 1, 0)
		elif depth == 0:
			out += c
	return out
