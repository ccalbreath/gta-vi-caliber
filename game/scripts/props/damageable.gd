class_name Damageable
extends RefCounted
## Pure hit-points model shared by anything that can be shot.
##
## No scene access — a Hittable node owns one of these and forwards damage to
## it, so the health/death bookkeeping is unit-tested (tests/unit/
## test_damageable.gd) independent of meshes, tweens, or physics.

var max_health: float
var health: float


func _init(maximum: float = 100.0) -> void:
	max_health = maxf(maximum, 0.0001)
	health = max_health


func is_dead() -> bool:
	return health <= 0.0


## Apply damage (negative/zero ignored). Returns true only on the hit that drops
## health to zero, so a caller can trigger the death response exactly once.
func apply(amount: float) -> bool:
	if is_dead():
		return false
	health = maxf(health - maxf(amount, 0.0), 0.0)
	return is_dead()


## Remaining health in [0, 1] for HUD bars and damage tints.
func health_fraction() -> float:
	return health / max_health


## Restore to full (target respawn).
func revive() -> void:
	health = max_health
