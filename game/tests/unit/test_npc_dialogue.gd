extends RefCounted
## Unit tests for NpcDialogue — the bark engine. Determinism, never-empty
## output, slot filling, and the generic fallback are the contract the spawner
## relies on. (The jokes are not unit-testable. You'll have to trust me.)


func test_bark_is_deterministic() -> bool:
	var a := NpcDialogue.bark("conspiracy", "idle", 42)
	var b := NpcDialogue.bark("conspiracy", "idle", 42)
	return a == b and a != ""


func test_bark_varies_with_seed() -> bool:
	# Across the seed space, a multi-line bank must produce more than one result.
	var seen := {}
	for s in 12:
		seen[NpcDialogue.bark("doomsday", "idle", s)] = true
	return seen.size() >= 2


func test_unknown_voice_falls_back_to_generic() -> bool:
	var line := NpcDialogue.bark("there_is_no_such_voice", "bump", 1)
	return line != "" and line != "..."


func test_unknown_context_still_speaks() -> bool:
	# No bank has "underwater_basket_weaving"; must not crash, returns the murmur.
	return NpcDialogue.bark("yogi", "underwater_basket_weaving", 0) == "..."


func test_slots_are_filled() -> bool:
	# Force a line that contains a slot and confirm no raw {token} survives.
	for s in 20:
		var line := NpcDialogue.bark("influencer", "idle", s)
		if line.contains("{") or line.contains("}"):
			return false
	return true


func test_slot_fill_draws_from_word_banks() -> bool:
	# A filled slot must resolve to an actual catalogue entry, not garbage. Scan
	# seeds until we hit an influencer line that carried a {noun} or {animal}
	# slot, then confirm the substituted text is a real bank word.
	for s in 24:
		var line := NpcDialogue.bark("influencer", "idle", s)
		for word in NpcDialogue.NOUNS:
			if line.contains(word):
				return true
		for word in NpcDialogue.ANIMALS:
			if line.contains(word):
				return true
	return false


func test_bark_for_activity_maps_to_context() -> bool:
	# "loiter" maps to the "idle" context; should match a direct idle bark.
	var via := NpcDialogue.bark_for_activity("food_critic", "loiter", 3)
	var direct := NpcDialogue.bark("food_critic", "idle", 3)
	return via == direct


func test_every_voice_can_speak_every_reaction() -> bool:
	# Spawner fires these on player proximity/collision — none may come back empty.
	for c in NpcArchetypes.all():
		for ctx in ["see_player", "flee", "gawk", "bump", "idle"]:
			if NpcDialogue.bark(c["voice"], ctx, 1) == "":
				return false
	return true


func test_weather_bark_speaks_every_condition() -> bool:
	for cond in ["clear", "cloudy", "overcast", "rain"]:
		if NpcDialogue.weather_bark("conspiracy", cond, 1) == "":
			return false
	return true


func test_weather_anchor_gets_its_own_forecast() -> bool:
	# The "weather" voice should pull a distinct line from everyone else's grumble.
	var anchor := NpcDialogue.weather_bark("weather", "rain", 0)
	var civilian := NpcDialogue.weather_bark("conspiracy", "rain", 0)
	return anchor != "" and anchor != civilian


func test_weather_bark_is_deterministic() -> bool:
	var a := NpcDialogue.weather_bark("yogi", "overcast", 5)
	var b := NpcDialogue.weather_bark("yogi", "overcast", 5)
	return a == b and a != ""


func test_witness_bark_nonempty_and_filled() -> bool:
	for s in 12:
		var line := NpcDialogue.witness_bark(s)
		if line == "" or line.contains("{") or line.contains("}"):
			return false
	return true


func test_witness_bark_is_deterministic() -> bool:
	var a := NpcDialogue.witness_bark(7)
	var b := NpcDialogue.witness_bark(7)
	return a == b
