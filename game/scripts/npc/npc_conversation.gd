class_name NpcConversation
extends RefCounted
## Two citizens talking — gloriously past each other. Zips two voices' "chat"
## banks (NpcDialogue) into an alternating exchange. The lines never actually
## answer one another, and that mismatch — a Conspiracy Vendor and an
## Aggressively Calm Yogi nodding along to entirely different conversations — is
## the joke. The crowd stops being parallel solo agents and starts feeling social.
##
## Pure + deterministic (same voices + seed = same scene), so it unit-tests
## headless (tests/unit/test_npc_conversation.gd). Citizen plays an exchange out
## over time, one bubble per turn.


## Build an alternating exchange of `turns` lines between two voices. Each entry
## is {speaker, text}: speaker 0 = voice_a (even turns), 1 = voice_b (odd turns).
static func exchange(voice_a: String, voice_b: String, seed_value: int, turns: int = 4) -> Array:
	var out: Array = []
	var n := maxi(turns, 1)
	for i in n:
		var even := i % 2 == 0
		var voice := voice_a if even else voice_b
		# Spread the seed per turn so consecutive lines differ.
		out.append(
			{
				"speaker": 0 if even else 1,
				"text": NpcDialogue.bark(voice, "chat", seed_value + i * 101)
			}
		)
	return out


## A single opening line in `voice` — what a citizen says when it notices a
## neighbour and decides, against its better judgement, to make conversation.
static func greeting(voice: String, seed_value: int) -> String:
	return NpcDialogue.bark(voice, "greet", seed_value)
