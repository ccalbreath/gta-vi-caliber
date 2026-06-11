class_name NpcMemory
extends RefCounted
## A citizen's short memory of mayhem it witnessed the player cause. Seeing a
## neighbour gunned down (catching the panic) burns in a memory that fades over
## a minute or so; while it lingers and the culprit is in sight, the citizen
## recognises them and reacts — the city remembers what you did, for a while.
##
## Pure and deterministic (intensity + time → state), so it unit-tests headless
## (tests/unit/test_npc_memory.gd). The Citizen owns the mutable intensity and
## calls these; humour lives in NpcDialogue.witness_bark.

## Above this, a citizen is openly rattled and will call the player out.
const ALARMED: float = 0.6
## Above this, it still remembers enough to recognise the player.
const UNEASY: float = 0.25


## Fade a memory intensity toward 0 over `dt` seconds. ~0.08/s ≈ a 12 s fade from
## a full scare to "uneasy", forgotten entirely in ~13 s.
static func decay(memory: float, dt: float, rate: float = 0.08) -> float:
	return maxf(memory - rate * dt, 0.0)


## A label for how vividly this is remembered: "alarmed" / "uneasy" / "none".
static func category(memory: float) -> String:
	if memory >= ALARMED:
		return "alarmed"
	if memory >= UNEASY:
		return "uneasy"
	return "none"


## Does the citizen recognise the culprit right now? It must still remember (at
## least "uneasy") and have the player within recognition range.
static func recognizes(memory: float, player_distance: float, range_m: float = 12.0) -> bool:
	return memory >= UNEASY and player_distance <= range_m
