class_name InformantController
extends Node
## Owns the player's ONE informant network and runs a meet against PlayerStats: pay the retainer
## to build trust, then collect any reliable tip into the wallet. Self-wires by group
## ("informants"); Informant zones meet a contact against this shared network. The retainer is
## charged BEFORE trust is built, so you never earn an informant's trust without actually paying.
## Owns ONE InformantNetwork (tests/unit/test_informant_network.gd); verified informant_probe.gd.

signal met(id: String, trust: float, tip_cash: int)

var _network: InformantNetwork


func _ready() -> void:
	_network = InformantNetwork.new()
	add_to_group("informants")


## Meet an informant: pay `retainer` from PlayerStats to build trust, then bank any reliable tip.
## Returns the tip cash collected (0 if their intel wasn't good enough yet / couldn't afford the
## retainer / no wallet).
func meet(id: String, retainer: int) -> int:
	if _network == null or not _network.has_informant(id) or retainer <= 0:
		return 0  # a non-positive retainer can't buy a (free) tip — you have to actually pay
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats == null or not stats.has_method("spend_money") or not stats.has_method("add_money"):
		return 0
	# Charge the retainer BEFORE building trust, so a short wallet doesn't buy their loyalty free.
	if not stats.spend_money(retainer):
		return 0
	_network.pay_retainer(id, retainer)
	var tip := _network.request_tip(id)
	var cash := 0
	if bool(tip["reliable"]):
		cash = int(tip["value"])
		stats.add_money(cash)
	met.emit(id, _network.trust_of(id), cash)
	return cash


# --- Queries (passthroughs for the zones / HUD) ------------------------------


func trust_of(id: String) -> float:
	return _network.trust_of(id) if _network != null else 0.0


func is_reliable(id: String) -> bool:
	return _network != null and _network.is_reliable(id)


func informant_count() -> int:
	return _network.informant_count() if _network != null else 0
