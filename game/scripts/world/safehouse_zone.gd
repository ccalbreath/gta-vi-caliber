class_name SafehouseZone
extends Area3D
## Your safehouse — step inside to LAY LOW: you rest, healing up and shedding the
## wanted heat (the cops lose your trail), the genre's safe-haven beat. It's also a
## stash for cash kept safe off your person (deposit / withdraw). Consumes the
## tested Safehouse model; self-wires by group (player / player_health / wanted /
## player_stats). Needs a CollisionShape3D child; watches the player's collision
## layer (2). Verified in tests/safehouse_zone_probe.gd.
##
## The wanted heat is fully cleared on rest (the tracker exposes clear() but no
## partial cool) — the safehouse is a sanctuary you can't be tailed into.

signal rested(health_restored: float)

## The safehouse this zone is (the player's home — owned from the start here).
@export var safehouse_id: String = "home"
@export var district_id: String = "downtown"
## In-game hours of rest per visit (heals at Safehouse.HEAL_PER_HOUR).
@export var rest_hours: float = 8.0

var _safehouse: Safehouse


func _ready() -> void:
	_safehouse = Safehouse.new()
	_safehouse.acquire(safehouse_id, district_id)
	_safehouse.set_active(safehouse_id)
	add_to_group("safehouse")
	collision_mask |= 2
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or _safehouse == null:
		return
	var result := _safehouse.rest(rest_hours)
	var healed := float(result["health_restored"])
	var health := get_tree().get_first_node_in_group("player_health")
	if health != null and health.has_method("heal"):
		health.heal(healed)
	# Lay low: the safehouse sheds the heat (the cops lose the trail).
	var wanted := get_tree().get_first_node_in_group("wanted")
	if wanted != null and wanted.has_method("clear"):
		wanted.clear()
	rested.emit(healed)


## Deposit cash from the wallet into the safehouse stash (safe off your person).
## Returns the new stash balance, or -1 if the deposit couldn't be made (no wallet /
## can't afford it) so a caller can tell a no-op from a success.
func deposit(amount: int) -> int:
	var stats := get_tree().get_first_node_in_group("player_stats")
	if _safehouse == null or stats == null or not stats.has_method("spend_money"):
		return -1
	if amount <= 0 or not ("money" in stats) or int(stats.money) < amount:
		return -1
	stats.spend_money(amount)
	return _safehouse.stash(amount)


## Withdraw cash from the stash back to the wallet. Returns the amount taken.
func withdraw_cash(amount: int) -> int:
	var stats := get_tree().get_first_node_in_group("player_stats")
	if _safehouse == null or stats == null or not stats.has_method("add_money"):
		return 0
	var taken := _safehouse.withdraw(amount)
	if taken > 0:
		stats.add_money(taken)
	return taken


## Cash currently banked in this safehouse's stash, for a HUD readout.
func stash_balance() -> int:
	return _safehouse.stash_balance(safehouse_id) if _safehouse != null else 0
