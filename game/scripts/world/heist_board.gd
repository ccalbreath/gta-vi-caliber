class_name HeistBoard
extends Node3D
## A heist — the big score. Step into the Planning zone to CASE the joint: each
## visit completes one prep task (recon, gear, an inside man), cutting the risk and
## padding the take. Once the plan is ready, step into the Vault zone to PULL it: it
## rolls against your success chance and either banks your cut of the score
## (PlayerStats) or you get CAUGHT — heat to the wanted tracker and nothing taken.
## Consumes the tested HeistJob trio (HeistPlan + HeistCrew + HeistComplication) and
## self-wires by group (player / player_stats / wanted).
##
## Expects two Area3D children named "Planning" and "Vault", each with a
## CollisionShape3D; both watch the player's collision layer (2). One score per board
## (a pulled job is done). Verified in tests/heist_board_probe.gd.

signal prep_done(progress: float)
signal heist_resolved(success: bool, take: int)

## Cap on the crime reports a single job's heat maps to (no add-amount API on the
## wanted tracker, so heat is fed as repeated report_crime calls).
const MAX_HEAT_REPORTS: int = 8

## Heist approach: "loud" (min 1 prep), "stealth" (2), or "smart" (3) — lower risk
## and a bigger take, but more casing.
@export var approach: String = "smart"
## Gross value of the score before the approach/prep/complication/crew-cut maths.
@export var base_take: int = 50000
## Base WantedSystem heat the job draws (more if it's blown).
@export var base_heat: int = 4
## Prep tasks to case; completing them raises the odds (count should meet the
## approach's min prep).
@export var prep_tasks: PackedStringArray = ["recon", "gear", "inside_man"]

var _job: HeistJob
var _plan_zone: Area3D
var _vault_zone: Area3D
var _rng: RandomNumberGenerator
var _prep_index: int = 0
var _pulled: bool = false


func _ready() -> void:
	_job = HeistJob.new()
	_job.plan().set_approach(approach)
	for task: Variant in prep_tasks:
		_job.plan().add_prep(str(task))
	_assemble_crew()
	var min_prep: int = int(HeistPlan.APPROACHES.get(approach, {}).get("min_prep", 0))
	if prep_tasks.size() < min_prep:
		push_warning(
			(
				"HeistBoard: '%s' needs %d prep tasks but %d given — the vault is unreachable"
				% [approach, min_prep, prep_tasks.size()]
			)
		)
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	add_to_group("heist_board")
	_plan_zone = get_node_or_null("Planning") as Area3D
	_vault_zone = get_node_or_null("Vault") as Area3D
	if _plan_zone != null:
		_plan_zone.collision_mask |= 2
		_plan_zone.body_entered.connect(_on_plan_entered)
	if _vault_zone != null:
		_vault_zone.collision_mask |= 2
		_vault_zone.body_entered.connect(_on_vault_entered)


func _assemble_crew() -> void:
	var crew := _job.crew()
	crew.add_member("driver", 0.7, 0.15)
	crew.add_member("hacker", 0.8, 0.2)
	crew.add_member("muscle", 0.6, 0.15)


func _on_plan_entered(body: Node) -> void:
	if not body.is_in_group("player") or _pulled or _prep_index >= prep_tasks.size():
		return
	# Case the joint: complete the next prep task in order.
	_job.plan().complete_prep(str(prep_tasks[_prep_index]))
	_prep_index += 1
	prep_done.emit(_job.plan().prep_progress())


func _on_vault_entered(body: Node) -> void:
	if not body.is_in_group("player") or _pulled or not _job.plan().is_ready():
		return  # not cased enough yet — keep planning
	_pulled = true
	var success := _job.roll(_rng)
	var result := _job.resolve(success, base_take, base_heat)
	if success:
		var take := int(result["take"])
		var stats := get_tree().get_first_node_in_group("player_stats")
		if stats != null and stats.has_method("add_money"):
			stats.add_money(take)
	_report_heat(int(result["heat"]))
	var tracker := get_tree().get_first_node_in_group("stats")
	if tracker != null and tracker.has_method("add"):
		tracker.add("heists_done", 1)
	heist_resolved.emit(success, int(result["take"]))


## Feed the resolved heat to the wanted tracker as crime reports — it has no
## add-amount API, so more heat (a bigger base_heat or a blown job) means more
## reports, which is what makes those knobs actually bite.
func _report_heat(heat: int) -> void:
	var wanted := get_tree().get_first_node_in_group("wanted")
	if wanted == null or not wanted.has_method("report_crime"):
		return
	for _i in mini(maxi(heat, 0), MAX_HEAT_REPORTS):
		wanted.report_crime(false)


## Current 0..1 success chance of the plan as cased so far, for a HUD readout.
func success_chance() -> float:
	return _job.success_chance() if _job != null else 0.0


## Whether the plan is cased enough to pull.
func is_ready() -> bool:
	return _job != null and _job.plan().is_ready()


## Inject a seeded RNG for a deterministic roll (tests / fixed-odds events).
func set_rng(rng: RandomNumberGenerator) -> void:
	if rng != null:
		_rng = rng
