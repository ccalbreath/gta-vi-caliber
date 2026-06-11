class_name SaveData
extends RefCounted
## Pure (de)serialization for a save snapshot.
##
## No file or scene access — SaveManager gathers a plain Dictionary of game
## state, this wraps it with a version and turns it to/from JSON text, and the
## round-trip + malformed-input handling is unit-tested (tests/unit/
## test_save_data.gd). Decode never throws: bad input yields an empty snapshot.

const VERSION: int = 1


## Wrap a state snapshot with a version header and serialise to JSON text.
static func encode(snapshot: Dictionary) -> String:
	return JSON.stringify({"version": VERSION, "data": snapshot})


## Parse save text back to the inner snapshot. Returns {} for anything that
## isn't a versioned object with a Dictionary payload, so callers can trust the
## shape without try/catch.
static func decode(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data: Variant = (parsed as Dictionary).get("data")
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data


## The format version embedded in save text, or 0 if absent/unparseable. Lets a
## loader migrate or reject old saves.
static func version_of(text: String) -> int:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	return int((parsed as Dictionary).get("version", 0))
