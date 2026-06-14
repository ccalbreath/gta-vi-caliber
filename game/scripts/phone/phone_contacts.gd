class_name PhoneContacts
extends RefCounted
## The player's in-world friend roster — the people the phone can call and whose
## posts fill the social feeds.
##
## Pure data + static helpers (no scene access) so feed generation and the call
## flow stay deterministic and unit-tested (tests/unit/test_phone_contacts.gd).
## Each contact's `status` decides whether a call connects (see will_answer):
## "online" picks up, "away" goes to voicemail after a longer ring, "offline"
## misses immediately. The Phone node maps these to live Pedestrians by name when
## one is nearby, so calling a friend you can see makes them react in the world.

## Presence states, ordered most- to least-reachable.
const ONLINE: String = "online"
const AWAY: String = "away"
const OFFLINE: String = "offline"

## Fixed friend roster. `hue` (0..1) seeds the contact's avatar colour and tints
## their posts so a handle reads as the same person across apps.
const ROSTER: Array[Dictionary] = [
	{"name": "Mara", "handle": "mara_b", "status": ONLINE, "hue": 0.02},
	{"name": "Devin", "handle": "dev.ortiz", "status": ONLINE, "hue": 0.58},
	{"name": "Coop", "handle": "cooper", "status": AWAY, "hue": 0.11},
	{"name": "Lena", "handle": "lena.k", "status": ONLINE, "hue": 0.83},
	{"name": "Rae", "handle": "rae_rae", "status": AWAY, "hue": 0.34},
	{"name": "Tomas", "handle": "t0mas", "status": OFFLINE, "hue": 0.66},
	{"name": "Priya", "handle": "priya.v", "status": ONLINE, "hue": 0.92},
	{"name": "Jules", "handle": "jules", "status": OFFLINE, "hue": 0.46},
]


## The full roster (copied so callers can't mutate the constant).
static func roster() -> Array[Dictionary]:
	return ROSTER.duplicate(true)


## Just the @handles, in roster order — the authors a feed draws from.
static func handles() -> PackedStringArray:
	var out := PackedStringArray()
	for c in ROSTER:
		out.append(c["handle"])
	return out


## Contact dict by display name, or empty if there's no such friend.
static func by_name(name: String) -> Dictionary:
	for c in ROSTER:
		if c["name"] == name:
			return c
	return {}


## Whether a call to this contact connects. Online friends pick up; everyone
## else ends the call (away → voicemail, offline → missed) once ringing ends.
static func will_answer(contact: Dictionary) -> bool:
	return contact.get("status", OFFLINE) == ONLINE


## Seconds the phone rings before resolving — away friends ring longer (you're
## waiting on voicemail) than reachable or clearly-absent ones.
static func ring_seconds(contact: Dictionary) -> float:
	return 5.0 if contact.get("status", OFFLINE) == AWAY else 3.0


## Short presence label for the contacts list ("Active now" / "Away" / "Offline").
static func presence_label(contact: Dictionary) -> String:
	match contact.get("status", OFFLINE):
		ONLINE:
			return "Active now"
		AWAY:
			return "Away"
		_:
			return "Offline"
