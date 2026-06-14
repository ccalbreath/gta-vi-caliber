class_name HeistPlanningBoard
extends Node3D
## A walk-up heist planning board: face it, press interact to RECRUIT the next crew
## member (each charged up-front to PlayerStats), and once the crew is fully staffed
## press again to PULL THE JOB. A bigger, better crew lifts the success odds but eats
## into your cut, so the take you keep shrinks as the roster grows. Consumes the
## unit-tested HeistCrew model (crew skill/cut -> odds + payout) and self-wires by
## group (interactables / player_stats) — no plumbing beyond dropping the node.
##
## The Interactable contract (see Interaction): joins group "interactables" and
## answers interact_prompt() + interact(player). All money is resolved against the
## live wallet; HeistCrew itself never touches PlayerStats. The attempt rolls a
## node-owned RandomNumberGenerator so a probe can seed (set_seed) and replay a
## deterministic outcome; gameplay leaves it on its random default.

## Fired when a crew member is recruited (role hired, crew size after the hire).
signal crew_hired(role: String, size: int)
## Fired when the staffed crew runs the job (success, take paid into the wallet).
signal heist_resolved(success: bool, take_paid: int)

## Per-member recruiting fee charged to the wallet before they join the crew.
@export var recruit_cost: int = 5000
## Base difficulty fed to HeistCrew.success_chance (a more skilled crew lifts it).
@export var base_difficulty: float = 0.5
## The heist's gross take; the player banks their crew-adjusted share on success.
@export var take: int = 100000

## Default roster recruited in order, one per interact. Each entry:
## {"role": String, "skill": float 0..1, "cut": float 0..1} — read HeistCrew for
## the valid ranges (skill/cut clamp to 0..1; combined cut may not exceed 100%).
var crew_specs: Array[Dictionary] = [
	{"role": "driver", "skill": 0.7, "cut": 0.2},
	{"role": "hacker", "skill": 0.65, "cut": 0.18},
	{"role": "gunman", "skill": 0.6, "cut": 0.16},
]

## The live crew model. Public so a planning/HUD UI can read odds and shares.
var crew: HeistCrew

var _rng := RandomNumberGenerator.new()
var _stats: Node = null


func _init() -> void:
	crew = HeistCrew.new(crew_specs.size())


func _ready() -> void:
	add_to_group("interactables")


## HUD hint: recruiting progress before the crew is full, the odds + share after.
func interact_prompt() -> String:
	if is_ready():
		var pct := int(round(crew.success_chance(base_difficulty) * 100.0))
		var share := int(round(crew.player_share() * 100.0))
		return "Pull heist (%d%% odds, keep %d%%)" % [pct, share]
	return "Recruit crew (%d/%d, $%d)" % [crew_size(), crew_specs.size(), recruit_cost]


## One press: recruit the next member while the crew is short-staffed, otherwise
## the crew is ready so run the job.
func interact(_player: Node) -> void:
	if is_ready():
		_attempt()
	else:
		_recruit()


## Charge the recruiting fee and add the next default member; no-op if the roster
## is already full or the fee can't be covered.
func _recruit() -> void:
	if crew_size() >= crew_specs.size():
		return
	var spec: Dictionary = crew_specs[crew_size()]
	var stats := _player_stats()
	if stats == null or not stats.has_method("spend_money"):
		return
	if not stats.spend_money(recruit_cost):
		return
	if not crew.add_member(str(spec["role"]), float(spec["skill"]), float(spec["cut"])):
		stats.add_money(recruit_cost)
		return
	crew_hired.emit(str(spec["role"]), crew.member_count())


## Roll the staffed crew against the difficulty; bank the player's share on a win,
## announce the outcome, then reset the crew so the board can be re-staffed and run again.
func _attempt() -> void:
	var ok := crew.attempt(base_difficulty, _rng)
	var paid := crew.payout(take, ok)
	if ok and paid > 0:
		var stats := _player_stats()
		if stats != null and stats.has_method("add_money"):
			stats.add_money(paid)
	heist_resolved.emit(ok, paid if ok else 0)
	crew = HeistCrew.new(crew_specs.size())


## Seed the attempt RNG so a test can replay a deterministic heist outcome.
func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value


## Current staffed crew size, for a HUD/probe readout.
func crew_size() -> int:
	return crew.member_count() if crew != null else 0


## Whether the full roster is staffed and the heist can be attempted.
func is_ready() -> bool:
	return crew != null and crew.member_count() >= crew_specs.size() and not crew_specs.is_empty()


func _player_stats() -> Node:
	if _stats == null or not is_instance_valid(_stats):
		_stats = get_tree().get_first_node_in_group("player_stats")
	return _stats
