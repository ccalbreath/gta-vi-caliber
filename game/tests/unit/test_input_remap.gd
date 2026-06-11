extends RefCounted
## Unit tests for InputRemap (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass). Covers the pure conversion/merge/
## validation; the InputMap apply/capture helpers are integration-only.


func test_key_round_trips() -> bool:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	var rebuilt := InputRemap.dict_to_event(InputRemap.event_to_dict(key)) as InputEventKey
	return rebuilt != null and rebuilt.physical_keycode == KEY_W


func test_joy_button_round_trips() -> bool:
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	var dict := InputRemap.event_to_dict(button)
	var rebuilt := InputRemap.dict_to_event(dict) as InputEventJoypadButton
	return dict["type"] == "joy_button" and rebuilt.button_index == JOY_BUTTON_A


func test_joy_axis_round_trips_sign() -> bool:
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.7
	var rebuilt := (
		InputRemap.dict_to_event(InputRemap.event_to_dict(motion)) as InputEventJoypadMotion
	)
	# Sign is preserved and normalized to a full ±1 deflection.
	return rebuilt.axis == JOY_AXIS_LEFT_X and absf(rebuilt.axis_value - 1.0) < 0.0001


func test_unknown_event_serializes_empty() -> bool:
	return InputRemap.event_to_dict(InputEventMouseMotion.new()).is_empty()


func test_dict_to_event_rejects_unknown() -> bool:
	return InputRemap.dict_to_event({"type": "telepathy"}) == null


func test_merge_override_replaces_action() -> bool:
	var defaults := {"jump": [{"type": "key", "keycode": KEY_SPACE}]}
	var overrides := {"jump": [{"type": "joy_button", "index": JOY_BUTTON_A}]}
	var merged := InputRemap.merge(defaults, overrides)
	return merged["jump"][0]["type"] == "joy_button"


func test_merge_passes_through_untouched_actions() -> bool:
	var defaults := {"jump": [{"type": "key", "keycode": KEY_SPACE}], "fire": []}
	var merged := InputRemap.merge(defaults, {"fire": [{"type": "key", "keycode": KEY_F}]})
	return merged["jump"][0]["keycode"] == KEY_SPACE


func test_merge_does_not_mutate_defaults() -> bool:
	var defaults := {"jump": [{"type": "key", "keycode": KEY_SPACE}]}
	InputRemap.merge(defaults, {"jump": [{"type": "key", "keycode": KEY_J}]})
	return defaults["jump"][0]["keycode"] == KEY_SPACE


func test_is_valid_accepts_well_formed() -> bool:
	return InputRemap.is_valid({"jump": [{"type": "key", "keycode": KEY_SPACE}]})


func test_is_valid_rejects_empty_event_list() -> bool:
	return not InputRemap.is_valid({"jump": []})


func test_is_valid_rejects_malformed_event() -> bool:
	return not InputRemap.is_valid({"jump": [{"type": "nope"}]})
