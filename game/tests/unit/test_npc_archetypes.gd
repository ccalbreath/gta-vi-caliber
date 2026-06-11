extends RefCounted
## Unit tests for NpcArchetypes — the citizen census. Every archetype must be
## well-formed (the rest of the stack indexes these fields blind), schedules
## must cover the full day, and seeding must be stable.


func test_catalog_is_populated() -> bool:
	return NpcArchetypes.all().size() >= 10


func test_every_archetype_is_well_formed() -> bool:
	for c in NpcArchetypes.all():
		for key in ["id", "name", "schedule", "personality", "voice", "tint", "quirk"]:
			if not c.has(key):
				return false
		if not (c["schedule"] is Array) or (c["schedule"] as Array).is_empty():
			return false
		if not (c["tint"] is Color):
			return false
	return true


func test_ids_are_unique() -> bool:
	var seen := {}
	for c in NpcArchetypes.all():
		if seen.has(c["id"]):
			return false
		seen[c["id"]] = true
	return true


func test_schedules_cover_the_whole_clock() -> bool:
	# No matter the hour, every archetype must yield a real (non-idle-fallback)
	# block — i.e. its routine has no gaps. Sample every half hour.
	for c in NpcArchetypes.all():
		var h := 0.0
		while h < 24.0:
			var block := NpcSchedule.activity_at(c["schedule"], h)
			if block == NpcSchedule.IDLE:
				return false
			h += 0.5
	return true


func test_by_id_round_trips() -> bool:
	var first: Dictionary = NpcArchetypes.all()[0]
	return NpcArchetypes.by_id(first["id"])["name"] == first["name"]


func test_by_id_unknown_is_empty() -> bool:
	return NpcArchetypes.by_id("nobody_real").is_empty()


func test_pick_is_deterministic_and_wraps() -> bool:
	var n := NpcArchetypes.all().size()
	var a := NpcArchetypes.pick(3)
	var b := NpcArchetypes.pick(3 + n)  # wraps to same index
	return a["id"] == b["id"]
