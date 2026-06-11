class_name InputRemap
extends RefCounted
## Rebindable input: (de)serialize InputEvents to plain dicts, merge user
## overrides onto defaults, and apply a config to the live InputMap. The pure
## conversion/merge/validation is unit-tested (tests/unit/test_input_remap.gd);
## the apply/capture helpers touch the InputMap singleton and are the thin layer
## a settings screen or the save system calls. Supports the three event kinds a
## rebind UI produces: keyboard keys, gamepad buttons, gamepad axes.


## Serialize one InputEvent to a savable dict, or {} if it's a kind we don't
## persist (so callers can filter it out).
static func event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "keycode": (event as InputEventKey).physical_keycode}
	if event is InputEventJoypadButton:
		return {"type": "joy_button", "index": (event as InputEventJoypadButton).button_index}
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return {"type": "joy_axis", "axis": motion.axis, "value": signf(motion.axis_value)}
	return {}


## Rebuild an InputEvent from a dict produced by event_to_dict, or null if the
## dict is malformed/unknown.
static func dict_to_event(cfg: Dictionary) -> InputEvent:
	match cfg.get("type", ""):
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = int(cfg.get("keycode", 0))
			return key
		"joy_button":
			var button := InputEventJoypadButton.new()
			button.button_index = int(cfg.get("index", 0))
			return button
		"joy_axis":
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(cfg.get("axis", 0))
			motion.axis_value = float(cfg.get("value", 1.0))
			return motion
	return null


## Merge user overrides onto defaults: an action present in `overrides` replaces
## the whole event list for that action; actions only in `defaults` pass through.
## Returns a new dict and never mutates its inputs.
static func merge(defaults: Dictionary, overrides: Dictionary) -> Dictionary:
	var result: Dictionary = defaults.duplicate(true)
	for action in overrides:
		result[action] = overrides[action]
	return result


## True when `config` is a well-formed action->event-list map: every value is a
## non-empty Array of dicts that dict_to_event can rebuild.
static func is_valid(config: Dictionary) -> bool:
	for action in config:
		var events = config[action]
		if not (events is Array) or (events as Array).is_empty():
			return false
		for event_cfg in events:
			if not (event_cfg is Dictionary) or dict_to_event(event_cfg) == null:
				return false
	return true


## Read the current bindings for `actions` from the live InputMap into a config
## dict (the defaults a rebind UI starts from). Unknown actions are skipped.
static func capture(actions: PackedStringArray) -> Dictionary:
	var config: Dictionary = {}
	for action in actions:
		if not InputMap.has_action(action):
			continue
		var events: Array = []
		for event in InputMap.action_get_events(action):
			var cfg := event_to_dict(event)
			if not cfg.is_empty():
				events.append(cfg)
		config[action] = events
	return config


## Apply a config to the live InputMap, replacing each named action's events.
## Ignores actions that don't exist and malformed event dicts. Returns the count
## of actions actually rebound.
static func apply(config: Dictionary) -> int:
	var rebound := 0
	for action in config:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for event_cfg in config[action]:
			var event := dict_to_event(event_cfg)
			if event != null:
				InputMap.action_add_event(action, event)
		rebound += 1
	return rebound
