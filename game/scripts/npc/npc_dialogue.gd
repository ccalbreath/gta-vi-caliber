class_name NpcDialogue
extends RefCounted
## The city's comic voice: procedural NPC barks. Given a citizen's voice (from
## NpcArchetypes), what it's doing, and a seed, it returns a one-liner. Humour
## and absurdity are the whole point — these lines are most of what sells "this
## crowd is alive and unwell" to a player walking past.
##
## Deterministic: the same (voice, context, seed) always yields the same line,
## so it unit-tests headless (tests/unit/test_npc_dialogue.gd) and an NPC's
## patter is stable frame to frame. Banks are keyed by voice then context;
## anything missing falls back to a generic bank so every NPC can always speak.
## Lines may contain {slots} filled from absurd word banks, seeded so the fill
## is stable too.

## Map an NpcMind activity to a dialogue context (several activities share one).
const ACTIVITY_CONTEXT: Dictionary = {
	"work": "work",
	"eat": "eat",
	"sleep": "sleep",
	"socialize": "socialize",
	"goof_off": "goof_off",
	"commute": "commute",
	"loiter": "idle",
	"freshen_up": "idle",
}

## Word banks for {slot} fills. Absurd by design.
const NOUNS: PackedStringArray = [
	"a sentient parking meter",
	"the concept of Tuesday",
	"my emotional support stapler",
	"a pigeon with opinions",
	"the void, but cozy",
	"an unpaid invoice",
	"a haunted vending machine",
	"my third favourite cloud",
]
const PLACES: PackedStringArray = [
	"the DMV of the soul",
	"a parking garage at 3am",
	"the good Wendy's",
	"a Build-A-Bear in crisis",
	"the suburbs of my mind",
	"aisle seven",
]
const ANIMALS: PackedStringArray = [
	"a raccoon",
	"seven confident geese",
	"a tactical squirrel",
	"a possum named Greg",
	"a committee of crows",
]

## voice -> context -> lines. See generic bank below for the fallback contexts.
const BANKS: Dictionary = {
	"doomsday":
	{
		"idle":
		[
			"The foam spelled a warning this morning. It said 'low tip'.",
			"Enjoy the sunlight. I've read the espresso. I've seen things.",
			"We're all just beans, waiting to be ground. Anyway, oat milk?",
		],
		"work":
		[
			"This is a medium. It is also an omen.",
			"Your order is ready. So, in a cosmic sense, is the end.",
		],
		"see_player": ["You. The grounds mentioned you. Wear a scarf."],
	},
	"influencer":
	{
		"idle":
		[
			"Okay but the LIGHTING on {noun} right now? Unreal. Like and subscribe.",
			"Guys. GUYS. We just hit four followers. We're basically a movement.",
			"Don't mind me, just getting B-roll of {animal} for the brand.",
		],
		"work": ["Smash that follow for more content about {place}."],
		"see_player": ["Wait, are you filming me? No? ...Could you?"],
	},
	"method_actor":
	{
		"idle":
		[
			"I am not 'a guy with a sign'. I AM the sign.",
			"To truly halt traffic, one must first halt oneself. Spiritually.",
		],
		"work": ["STOP. (I have waited my whole life to mean it this much.)"],
		"see_player": ["Don't break my concentration. I'm a crosswalk now."],
	},
	"conspiracy":
	{
		"idle":
		[
			"Hot dogs? Sure. But have you ever seen one CHARGE its battery?",
			"The pigeons aren't real. {animal} told me. {animal} is also not real.",
			"They put fluoride in the relish. Wake up. Mustard?",
		],
		"work": ["That'll be six bucks. Cash. The card readers LISTEN."],
		"see_player": ["You're either with me or you're {noun} in a trench coat."],
		"chat": ["Don't look now, but that lamppost has been TAKING NOTES. Anyway, how are you?"],
	},
	"yogi":
	{
		"idle":
		[
			"Breathe in. Now hold it. Hold it. ...You may release it in 2027.",
			"Your aura is double-parked. We will be fixing that. Together.",
		],
		"work": ["Inhale calm. Exhale {noun}. Namaste, aggressively."],
		"see_player": ["I can sense your tension from here. It owes me money."],
		"chat": ["Mm. I hear your words, but your CHAKRAS are mumbling. Speak up, chakras."],
	},
	"stunt_double":
	{
		"idle":
		[
			"Stairs? In THIS economy? I roll down those now.",
			"Sorry, reflex. I see a curb, I prepare to be set on fire.",
		],
		"flee": ["AND WE'RE RUNNING — this is the good part — protect the face!"],
		"see_player": ["Don't worry about me, I've fallen off {place}. On purpose."],
	},
	"mime":
	{
		"idle": ["...", "(gestures at an invisible wall, deeply moved)", "(silent, but judging)"],
		"see_player": ["(points at you, then at an invisible rope, urgently)"],
		"chat": ["(nods vigorously, mimes a tiny violin, points at the sky, weeps)"],
	},
	"intern":
	{
		"idle":
		[
			"I've been awake since Tuesday and I have NEVER felt more employable.",
			"Is this load-bearing? Is ME load-bearing? Anyway I reorganized {place}.",
		],
		"work": ["Synergy! I don't know what it means but I did SO much of it."],
		"see_player": ["Do you need anything? A coffee? A merger? I'm so ready."],
	},
	"philosopher":
	{
		"idle":
		[
			"If a dog walks a man, is anyone truly on a leash? ...Steve, heel.",
			"We are all just {animal}, briefly convinced we have a schedule.",
		],
		"see_player": ["You there — do you exist, or are you also avoiding emails?"],
		"chat": ["But IS a hot dog a sandwich, or is the sandwich us? ...Steve. STEVE. Heel."],
	},
	"food_critic":
	{
		"idle":
		[
			"This bench: two stars. Ambitious silhouette, no follow-through.",
			"The air today has notes of bus and regret. I've had worse Tuesdays.",
		],
		"eat": ["I'll allow it. Three stars. The pickle showed real courage."],
		"see_player": ["Your vibe? Unseasoned. But promising. I'll allow it."],
		"chat":
		["This conversation: a bold three stars. Slightly overcooked, but the texture? Fun."],
	},
	"life_coach":
	{
		"idle":
		[
			"You didn't wake up today to be MEDIUM. That'll be $40.",
			"Your only competition is the {noun} you were yesterday. Believe it.",
		],
		"see_player": ["I see GREATNESS in you. Also an invoice. Mostly greatness."],
	},
	"weather":
	{
		"idle":
		[
			"And it's a balmy sidewalk out there, folks, with a 70% chance of {animal}.",
			"Live, from this exact spot: skies are doing their absolute best.",
		],
		"work": ["Doppler says feelings later, clearing to mild smugness by five."],
		"see_player": ["You heard it here first: YOU are the storm front, champ."],
	},
}

## The safety net — any voice missing a context borrows these.
const GENERIC: Dictionary = {
	"idle": ["Hm.", "Another day in {place}, I guess.", "I should really call {noun}."],
	"work": ["Working, working, always working.", "This job and I have an understanding."],
	"eat": ["Mmh. Food.", "I would die for this sandwich, conditionally."],
	"sleep": ["Zzz...", "Five more minutes. Or years."],
	"socialize": ["So anyway, that's my whole thing about {noun}.", "Cheers, I guess!"],
	"goof_off": ["I'm not procrastinating, I'm marinating.", "Wheee, sort of."],
	"commute": ["Move, MOVE — oh. Sorry. We're all in this.", "Another commute, another me."],
	"see_player": ["Oh, hey.", "Do I know you? No? Cool, cool.", "Watch where you're vibing."],
	"flee": ["NOPE.", "This is a problem for running-me!", "I respect violence too much to stay!"],
	"gawk":
	["Are you SEEING this?!", "Somebody's having a day.", "I'm not staring, you're staring."],
	"bump": ["Hey! Walkin' here!", "Personal space is a {place}, my friend.", "Oof. Rude."],
	"greet":
	[
		"Oh — hi! We're both just. Out here. Existing.",
		"Hey, you! Big fan of {noun}, by the way.",
		"Morning! Or — is it? Time is {place} to me now.",
	],
	"chat":
	[
		"So I told them, I said, '{noun} is not a personality.' They disagreed.",
		"Anyway, long story short, I no longer trust {animal}.",
		"You ever just think about {place}? No? ...Just me, then.",
		"Totally. Totally. ...Wait, what are we agreeing about?",
		"And THAT'S why I don't do Tuesdays anymore.",
		"Mm-hm. Mm-hm. Big if true. What were you saying?",
	],
}


## Resolve {slots} in a line deterministically from `seed_value`.
static func _fill(line: String, seed_value: int) -> String:
	var out := line
	if out.contains("{noun}"):
		out = out.replace("{noun}", NOUNS[posmod(seed_value, NOUNS.size())])
	if out.contains("{place}"):
		out = out.replace("{place}", PLACES[posmod(seed_value * 7 + 1, PLACES.size())])
	if out.contains("{animal}"):
		out = out.replace("{animal}", ANIMALS[posmod(seed_value * 13 + 2, ANIMALS.size())])
	return out


## Pick a line for (voice, context), filling slots. Falls back to the generic
## bank, then to a last-resort murmur, so this never returns "".
static func bark(voice: String, context: String, seed_value: int) -> String:
	var lines := _lines_for(voice, context)
	if lines.is_empty():
		return "..."
	var line := String(lines[posmod(seed_value, lines.size())])
	return _fill(line, seed_value)


## Convenience: bark for a brain decision (maps its activity to a context).
static func bark_for_activity(voice: String, activity: String, seed_value: int) -> String:
	var context := String(ACTIVITY_CONTEXT.get(activity, "idle"))
	return bark(voice, context, seed_value)


## The candidate lines for (voice, context) with generic fallback. Public so the
## spawner can pre-warm or count a voice's repertoire.
static func _lines_for(voice: String, context: String) -> Array:
	var voice_bank: Dictionary = BANKS.get(voice, {})
	if voice_bank.has(context) and not (voice_bank[context] as Array).is_empty():
		return voice_bank[context]
	if GENERIC.has(context):
		return GENERIC[context]
	return []
