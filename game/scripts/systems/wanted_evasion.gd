class_name WantedEvasion
extends RefCounted
## Pure "go cold" wanted-evasion state machine for the police-response system.
##
## Models the GTA evasion lifecycle: while a cop has line of sight (or a crime is
## in progress) you are VISIBLE; the moment you break sight a search countdown
## runs (SEARCHING — the HUD flashes the stars); if it reaches zero unseen you go
## COLD and the wanted level should clear. Re-sighting at any point snaps back to
## VISIBLE and refills the timer.
##
## No scene access — a node owns one and feeds it line-of-sight + delta, so the
## whole curve is unit-tested (tests/unit/test_wanted_evasion.gd).

## Evasion phases. VISIBLE: seen now / committing crime, timer full. SEARCHING:
## unseen, countdown running. COLD: countdown elapsed, wanted should clear.
enum State { VISIBLE, SEARCHING, COLD }

var search_duration: float
var _state: int = State.VISIBLE
var _time_left: float


func _init(duration: float = 12.0) -> void:
	# Guard against a zero/negative duration so the countdown is always finite
	# and search_progress() can never divide by zero.
	search_duration = maxf(duration, 0.001)
	_time_left = search_duration


func state() -> int:
	return _state


func is_visible() -> bool:
	return _state == State.VISIBLE


func is_searching() -> bool:
	return _state == State.SEARCHING


func is_cold() -> bool:
	return _state == State.COLD


## Seconds remaining on the search countdown: full while VISIBLE, 0 when COLD.
func time_left() -> float:
	return clampf(_time_left, 0.0, search_duration)


## 0.0 at the start of a search, ramping to 1.0 at COLD. 0.0 while VISIBLE.
## Drives a HUD flash/needle; monotonic within one uninterrupted search.
func search_progress() -> float:
	if _state == State.VISIBLE:
		return 0.0
	if _state == State.COLD:
		return 1.0
	var elapsed := search_duration - clampf(_time_left, 0.0, search_duration)
	return clampf(elapsed / search_duration, 0.0, 1.0)


## Core tick. seen_by_police true -> snap to VISIBLE and refill (the GTA "they
## spotted you again" reset). false -> VISIBLE starts the countdown, SEARCHING
## decrements it by delta and flips to COLD at zero. COLD stays COLD until a
## reset/crime. Negative/zero delta is treated as no time passing.
func update(seen_by_police: bool, delta: float) -> void:
	if seen_by_police:
		_state = State.VISIBLE
		_time_left = search_duration
		return

	if _state == State.COLD:
		return

	if _state == State.VISIBLE:
		# Just lost sight: begin searching from a full timer.
		_state = State.SEARCHING

	var step := maxf(delta, 0.0)
	_time_left = clampf(_time_left - step, 0.0, search_duration)
	if _time_left <= 0.0:
		_time_left = 0.0
		_state = State.COLD


## Back to VISIBLE with a full timer (respawn, or any state reset).
func reset() -> void:
	_state = State.VISIBLE
	_time_left = search_duration


## A fresh crime keeps you hot even if momentarily unseen: force VISIBLE + refill.
func notify_crime() -> void:
	_state = State.VISIBLE
	_time_left = search_duration
