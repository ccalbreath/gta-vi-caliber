class_name PhoneModel
extends RefCounted
## Pure phone logic: which app is open, kinetic feed scrolling, and the call
## state machine.
##
## Static functions only — no scene access, no time source of its own (the node
## passes `delta`) — so behaviour is deterministic and unit-tested
## (tests/unit/test_phone_model.gd). The Phone node owns the mutable state
## (open app, scroll offset/velocity, call timer) and calls these helpers each
## frame; presentation and input live there.

## The phone's apps. HOME is the launcher; CALL is the in-call screen reached
## from CONTACTS, not a home-grid icon.
enum App { HOME, PHOTOS, CHIRP, CONTACTS, CALL }

## Call progression. A call runs DIALING → RINGING → (CONNECTED | ENDED); the
## node resets its elapsed timer on each transition and reads advance_call().
enum Call { IDLE, DIALING, RINGING, CONNECTED, ENDED }

## Functional home-grid apps, in order, with display label and accent hue (0..1).
## Decorative-only tiles can be appended by the node; these three are wired.
const HOME_APPS: Array[Dictionary] = [
	{"app": App.PHOTOS, "label": "Instasnap", "hue": 0.92},
	{"app": App.CHIRP, "label": "Chirp", "hue": 0.55},
	{"app": App.CONTACTS, "label": "Phone", "hue": 0.36},
]

## Seconds spent "Calling…" before the line starts ringing.
const DIAL_SECONDS: float = 1.2

## Per-second fraction of scroll velocity retained — kinetic friction after a
## flick. Lower = stops sooner. Applied as velocity *= pow(RETAIN, dt).
const SCROLL_RETAIN: float = 0.06

## A flick is "spent" (snaps to rest) once its speed drops below this (px/s).
const SCROLL_STOP_EPSILON: float = 4.0


## Largest scrollable offset (px) for content of `content_h` in a `view_h`
## viewport. Zero when everything already fits.
static func max_offset(content_h: float, view_h: float) -> float:
	return maxf(content_h - view_h, 0.0)


## Clamp a scroll offset into [0, max_offset]. The feed can't scroll past its top
## or its last post.
static func clamp_offset(offset: float, content_h: float, view_h: float) -> float:
	return clampf(offset, 0.0, max_offset(content_h, view_h))


## Advance kinetic scrolling one frame. Integrates offset by velocity, decays the
## velocity by friction, and clamps to the content bounds — killing the velocity
## when it hits an edge or falls below SCROLL_STOP_EPSILON. Returns the new
## {offset, velocity}. Pure: the node passes its own stored values back in.
static func integrate_scroll(
	offset: float, velocity: float, content_h: float, view_h: float, delta: float
) -> Dictionary:
	var new_offset := offset + velocity * delta
	var new_velocity := velocity * pow(SCROLL_RETAIN, delta)
	if absf(new_velocity) < SCROLL_STOP_EPSILON:
		new_velocity = 0.0
	var limit := max_offset(content_h, view_h)
	if new_offset <= 0.0:
		new_offset = 0.0
		new_velocity = 0.0
	elif new_offset >= limit:
		new_offset = limit
		new_velocity = 0.0
	return {"offset": new_offset, "velocity": new_velocity}


## Apply a discrete wheel/drag step immediately, clamped — used for mouse-wheel
## notches and to seed a flick. Positive `amount` scrolls the content up (toward
## later posts), matching natural touch.
static func scroll_by(offset: float, amount: float, content_h: float, view_h: float) -> float:
	return clamp_offset(offset + amount, content_h, view_h)


## Next call state given how long the current one has run. The node resets its
## elapsed timer whenever the returned state differs from the current one.
## DIALING holds for DIAL_SECONDS, RINGING for `ring_seconds`, then resolves to
## CONNECTED if `will_answer` else ENDED. CONNECTED/ENDED/IDLE are terminal here.
static func advance_call(
	state: Call, elapsed: float, will_answer: bool, ring_seconds: float
) -> Call:
	match state:
		Call.DIALING:
			return Call.RINGING if elapsed >= DIAL_SECONDS else Call.DIALING
		Call.RINGING:
			if elapsed < ring_seconds:
				return Call.RINGING
			return Call.CONNECTED if will_answer else Call.ENDED
		_:
			return state


## Status line under the contact's name on the call screen, given the live call
## state and how long it's held. CONNECTED shows the running M:SS duration.
static func call_status_text(state: Call, elapsed: float) -> String:
	match state:
		Call.DIALING:
			return "Calling…"
		Call.RINGING:
			return "Ringing…"
		Call.CONNECTED:
			return format_duration(elapsed)
		Call.ENDED:
			return "Call ended"
		_:
			return ""


## Seconds → "M:SS" (e.g. 75.0 → "1:15"), for the in-call timer.
static func format_duration(seconds: float) -> String:
	var total := int(maxf(seconds, 0.0))
	return "%d:%02d" % [total / 60, total % 60]
