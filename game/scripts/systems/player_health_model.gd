class_name PlayerHealthModel
extends RefCounted
## Pure player health with regeneration.
##
## No scene access — the PlayerHealth node owns one and feeds it damage and
## time, so the regen-after-delay curve and death are unit-tested
## (tests/unit/test_player_health_model.gd). GTA-style: health regenerates to
## full a few seconds after the last hit.

var max_health: float
var health: float
var regen_rate: float
var regen_delay: float

var _since_damage: float = 0.0


func _init(maximum: float = 100.0, regen: float = 10.0, delay: float = 5.0) -> void:
	max_health = maxf(maximum, 0.0001)
	health = max_health
	regen_rate = regen
	regen_delay = delay


func is_dead() -> bool:
	return health <= 0.0


## Apply damage (negative ignored) and reset the regen timer. Returns true only
## on the hit that drops health to zero.
func apply(amount: float) -> bool:
	if is_dead():
		return false
	health = maxf(health - maxf(amount, 0.0), 0.0)
	_since_damage = 0.0
	return is_dead()


## Advance one frame: regenerate once regen_delay has elapsed since the last hit.
func tick(delta: float) -> void:
	if is_dead():
		return
	_since_damage += delta
	if _since_damage >= regen_delay:
		health = minf(health + regen_rate * delta, max_health)


func fraction() -> float:
	return health / max_health


func revive() -> void:
	health = max_health
	_since_damage = regen_delay
