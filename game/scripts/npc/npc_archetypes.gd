class_name NpcArchetypes
extends RefCounted
## The census of who lives in this city — a catalog of absurd citizens, each a
## bundle of {daily routine, personality, dialogue voice, visual tint, quirk}.
## This is the data the rest of the NPC stack animates: NpcMind reads the
## schedule + personality, NpcDialogue reads the voice, the spawner reads the
## tint. Humour and absurdity are load-bearing here — a city of "Pedestrian 01"
## clones is dead; a city where the crossing guard is a method actor preparing
## for the role of a lifetime is alive.
##
## Pure data + deterministic selection, scene-free, unit-tested headless
## (tests/unit/test_npc_archetypes.gd). Every binary asset stays out of here;
## colours are just tints applied to the shared procedural HumanoidBody.

# --- shared daily-routine templates -----------------------------------------
# Authored most-specific-first; midnight-wrapping blocks allowed (see NpcSchedule).

## Classic 9-to-5: commute, desk, gym, home, sleep.
const NINE_TO_FIVE: Array = [
	{"start": 7.0, "end": 9.0, "activity": "commute", "place": "street"},
	{"start": 9.0, "end": 12.5, "activity": "work", "place": "office"},
	{"start": 12.5, "end": 13.5, "activity": "eat", "place": "diner"},
	{"start": 13.5, "end": 17.5, "activity": "work", "place": "office"},
	{"start": 17.5, "end": 19.0, "activity": "goof_off", "place": "gym"},
	{"start": 19.0, "end": 22.5, "activity": "socialize", "place": "bar"},
	{"start": 22.5, "end": 7.0, "activity": "sleep", "place": "home"},
]

## Night owl: sleeps through the day, works/plays the night.
const NIGHT_OWL: Array = [
	{"start": 4.0, "end": 13.0, "activity": "sleep", "place": "home"},
	{"start": 13.0, "end": 18.0, "activity": "goof_off", "place": "park"},
	{"start": 18.0, "end": 22.0, "activity": "eat", "place": "diner"},
	{"start": 22.0, "end": 4.0, "activity": "work", "place": "bar"},
]

## Gig worker: forever in motion, no fixed desk.
const STREET_HUSTLE: Array = [
	{"start": 8.0, "end": 11.0, "activity": "work", "place": "street"},
	{"start": 11.0, "end": 12.0, "activity": "eat", "place": "street"},
	{"start": 12.0, "end": 19.0, "activity": "work", "place": "street"},
	{"start": 19.0, "end": 23.0, "activity": "socialize", "place": "bar"},
	{"start": 23.0, "end": 8.0, "activity": "sleep", "place": "home"},
]

## Retiree: unhurried, park-bench tempo, early to bed.
const SLOW_LIFE: Array = [
	{"start": 6.0, "end": 9.0, "activity": "goof_off", "place": "park"},
	{"start": 9.0, "end": 12.0, "activity": "loiter", "place": "street"},
	{"start": 12.0, "end": 13.0, "activity": "eat", "place": "diner"},
	{"start": 13.0, "end": 18.0, "activity": "loiter", "place": "park"},
	{"start": 18.0, "end": 20.0, "activity": "socialize", "place": "bar"},
	{"start": 20.0, "end": 6.0, "activity": "sleep", "place": "home"},
]

# --- the citizens ------------------------------------------------------------
# personality.discipline in [-1,1]: how hard a desperate drive has to push before
# this NPC ditches the plan. voice -> NpcDialogue bank. tint -> shirt colour hint.

const CITIZENS: Array = [
	{
		"id": "doomsday_barista",
		"name": "Doomsday Barista",
		"schedule": NINE_TO_FIVE,
		"personality": {"discipline": 0.3},
		"voice": "doomsday",
		"tint": Color(0.30, 0.22, 0.18),
		"quirk": "reads the coming apocalypse in your latte foam",
	},
	{
		"id": "pigeon_influencer",
		"name": "Pigeon Influencer",
		"schedule": STREET_HUSTLE,
		"personality": {"discipline": -0.6},
		"voice": "influencer",
		"tint": Color(0.85, 0.45, 0.70),
		"quirk": "livestreams pigeons to an audience of four",
	},
	{
		"id": "method_crossing_guard",
		"name": "Method Crossing Guard",
		"schedule": NINE_TO_FIVE,
		"personality": {"discipline": 0.9},
		"voice": "method_actor",
		"tint": Color(0.90, 0.78, 0.15),
		"quirk": "has been preparing for this crosswalk role for six years",
	},
	{
		"id": "conspiracy_vendor",
		"name": "Conspiracy Hot-Dog Vendor",
		"schedule": STREET_HUSTLE,
		"personality": {"discipline": -0.2},
		"voice": "conspiracy",
		"tint": Color(0.65, 0.20, 0.18),
		"quirk": "is pretty sure the pigeons are surveillance drones",
	},
	{
		"id": "aggressively_calm_yogi",
		"name": "Aggressively Calm Yoga Instructor",
		"schedule": SLOW_LIFE,
		"personality": {"discipline": 0.5},
		"voice": "yogi",
		"tint": Color(0.55, 0.72, 0.62),
		"quirk": "will find your center whether you consent or not",
	},
	{
		"id": "retired_stunt_double",
		"name": "Retired Stunt Double",
		"schedule": SLOW_LIFE,
		"personality": {"discipline": 0.0},
		"voice": "stunt_double",
		"tint": Color(0.28, 0.30, 0.34),
		"quirk": "instinctively rolls away from mild inconveniences",
	},
	{
		"id": "off_duty_mime",
		"name": "Off-Duty Mime (Still On)",
		"schedule": NIGHT_OWL,
		"personality": {"discipline": -0.4},
		"voice": "mime",
		"tint": Color(0.92, 0.92, 0.92),
		"quirk": "is trapped in an invisible box and also fine with it",
	},
	{
		"id": "overcaffeinated_intern",
		"name": "Over-Caffeinated Intern",
		"schedule": NINE_TO_FIVE,
		"personality": {"discipline": -0.8},
		"voice": "intern",
		"tint": Color(0.35, 0.55, 0.85),
		"quirk": "has replaced blood with cold brew and a dream",
	},
	{
		"id": "philosophical_dog_walker",
		"name": "Philosophical Dog-Walker",
		"schedule": SLOW_LIFE,
		"personality": {"discipline": 0.2},
		"voice": "philosopher",
		"tint": Color(0.45, 0.40, 0.55),
		"quirk": "walks seven dogs and one unexamined life",
	},
	{
		"id": "feral_food_critic",
		"name": "Feral Food Critic",
		"schedule": NIGHT_OWL,
		"personality": {"discipline": -0.3},
		"voice": "food_critic",
		"tint": Color(0.70, 0.55, 0.25),
		"quirk": "rates everything, including this sidewalk, out of five stars",
	},
	{
		"id": "unlicensed_life_coach",
		"name": "Unlicensed Life Coach",
		"schedule": NINE_TO_FIVE,
		"personality": {"discipline": -0.1},
		"voice": "life_coach",
		"tint": Color(0.80, 0.60, 0.30),
		"quirk": "believes in you aggressively and for a small fee",
	},
	{
		"id": "weather_anchor_nobody_hired",
		"name": "Self-Appointed Weather Anchor",
		"schedule": STREET_HUSTLE,
		"personality": {"discipline": 0.4},
		"voice": "weather",
		"tint": Color(0.25, 0.45, 0.60),
		"quirk": "delivers a live forecast to anyone within earshot",
	},
]


## Every archetype, in declaration order (stable for tests + seeding).
static func all() -> Array:
	return CITIZENS


## Look one up by id, or {} if unknown.
static func by_id(id: String) -> Dictionary:
	for c in CITIZENS:
		if c["id"] == id:
			return c
	return {}


## Deterministically pick an archetype from a seed (e.g. an NPC's spawn index),
## so the same NPC is always the same person across reloads.
static func pick(seed_value: int) -> Dictionary:
	var n := CITIZENS.size()
	if n == 0:
		return {}
	return CITIZENS[posmod(seed_value, n)]
