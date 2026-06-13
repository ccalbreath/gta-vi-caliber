class_name HitContractBoard
extends Node3D
## A playable assassination-contract board — the genre's "Lester hit" loop: step
## into the Board zone to take the next contract, then reach the Target zone to
## carry out the hit. Completing it banks the reward (PlayerStats) AND fires the
## contract's STOCK-MARKET SHOCK at a live StockMarket (group "stock_market"), so a
## player who invested in the rival first cashes in on the swing. Consumes the
## tested HitContract model and self-wires by group (player / player_stats / stats /
## stock_market). Like SideJobBoard, it's a self-contained activity dropped into the
## world.
##
## Expects two Area3D children named "Board" and "Target", each with a
## CollisionShape3D; both watch the player's collision layer (2). Verified headless
## in tests/hit_contract_probe.gd.

signal contract_accepted(id: String, reward: int)
signal contract_completed(reward: int, company_id: String)

## Minimum distance the player must travel from where they accepted before the hit
## counts — stops overlapping / adjacent Board+Target zones from auto-completing a
## contract for the full reward with no travel.
const MIN_TRAVEL: float = 5.0

var _board: HitContract
var _giver: Area3D
var _target: Area3D
var _accepted_at: Vector3 = Vector3.ZERO


func _ready() -> void:
	_board = HitContract.new()
	add_to_group("hit_contract_board")
	_giver = get_node_or_null("Board") as Area3D
	_target = get_node_or_null("Target") as Area3D
	if _giver != null:
		_giver.collision_mask |= 2
		_giver.body_entered.connect(_on_board_entered)
	if _target != null:
		_target.collision_mask |= 2
		_target.body_entered.connect(_on_target_entered)


func _on_board_entered(body: Node) -> void:
	if not body.is_in_group("player") or _board.has_active():
		return
	var pool := _board.available()
	if pool.is_empty():
		return
	var id: String = pool[0]
	if _board.accept(id):
		var node3d := body as Node3D
		_accepted_at = node3d.global_position if node3d != null else Vector3.ZERO
		contract_accepted.emit(id, _board.reward_of(id))


func _on_target_entered(body: Node) -> void:
	if not body.is_in_group("player") or not _board.has_active():
		return
	# Require real travel from where the contract was taken (overlapping zones must
	# not auto-complete for free).
	var node3d := body as Node3D
	if node3d != null and node3d.global_position.distance_to(_accepted_at) < MIN_TRAVEL:
		return
	var result := _board.complete()
	if not result.get("success", false):
		return
	var reward: int = result["reward"]
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats != null and stats.has_method("add_money"):
		stats.add_money(reward)
	var effect: Dictionary = result["market_effect"]
	_apply_market_shock(effect)
	var tracker := get_tree().get_first_node_in_group("stats")
	if tracker != null and tracker.has_method("add"):
		tracker.add("hits_done", 1)
	contract_completed.emit(reward, String(effect.get("company_id", "")))


## Fire the hit's market shock at a live StockMarket, if one is wired in (the
## decoupled cross-system payoff; no-op when no market node is present).
func _apply_market_shock(effect: Dictionary) -> void:
	var company_id := String(effect.get("company_id", ""))
	if company_id.is_empty():
		return
	var market := get_tree().get_first_node_in_group("stock_market")
	if market == null or not market.has_method("apply_rivalry_shock"):
		return
	market.apply_rivalry_shock(
		company_id, float(effect.get("magnitude", 0.0)), float(effect.get("spillover", 0.0))
	)


## Completed hits so far, for a HUD readout.
func hits_done() -> int:
	return _board.completed_count() if _board != null else 0
