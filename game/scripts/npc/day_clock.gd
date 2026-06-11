class_name DayClock
extends RefCounted
## A compressed day/night clock. Real seconds tick a 24-hour game clock at a
## configurable rate (a 24-minute day by default), so a citizen's morning
## commute, lunch, and last call all happen while the player watches. The
## CityDirector owns one and citizens read `hour` to plan their day via NpcMind.
##
## Pure state + math (no nodes, no engine time), so it unit-tests headless
## (tests/unit/test_day_clock.gd) — `advance(delta)` is fed whatever delta the
## caller has, real or simulated.

## Current clock hour in [0, 24).
var hour: float = 8.0
## Real seconds for one full in-game day. 1440 = a 24-minute day (1 min/hour).
var day_length_sec: float = 1440.0


func _init(start_hour: float = 8.0, day_length: float = 1440.0) -> void:
	hour = fposmod(start_hour, 24.0)
	day_length_sec = maxf(day_length, 1.0)


## Advance the clock by `delta` real seconds, wrapping past midnight.
func advance(delta: float) -> void:
	var hours_per_sec := 24.0 / day_length_sec
	hour = fposmod(hour + delta * hours_per_sec, 24.0)


## Coarse part-of-day label, handy for lighting hooks and dialogue flavour.
func phase() -> String:
	if hour < 6.0:
		return "night"
	if hour < 12.0:
		return "morning"
	if hour < 18.0:
		return "afternoon"
	if hour < 22.0:
		return "evening"
	return "night"


## "HH:MM" for debug HUDs.
func clock_text() -> String:
	var h := int(hour)
	var m := int((hour - float(h)) * 60.0)
	return "%02d:%02d" % [h, m]
