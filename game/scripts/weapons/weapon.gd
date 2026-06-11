class_name Weapon
extends RefCounted
## Runtime firing state for one carried weapon: ammo, cooldown, reload, bloom.
##
## Holds mutable state but no scene access and no RNG — the owner ticks it,
## asks can_fire(), calls fire(), and does the raycast itself using the exposed
## `spread`. This keeps the whole fire/reload/bloom state machine unit-testable
## (tests/unit/test_weapon.gd) against a plain WeaponStats.

var stats: WeaponStats
## Rounds currently in the magazine.
var ammo: int
## Spare rounds carried outside the magazine.
var reserve: int
## Current cone half-angle (radians); grows with each shot, recovers in tick().
var spread: float

var _cooldown: float = 0.0
var _reload_remaining: float = 0.0


func _init(weapon_stats: WeaponStats, start_reserve: int = -1) -> void:
	stats = weapon_stats
	ammo = stats.mag_size
	reserve = stats.reserve_max if start_reserve < 0 else start_reserve
	spread = stats.base_spread


func is_reloading() -> bool:
	return _reload_remaining > 0.0


## True when a shot is allowed: rounds loaded, off cooldown, not mid-reload.
func can_fire() -> bool:
	return ammo > 0 and _cooldown <= 0.0 and not is_reloading()


## Consume one round: decrement ammo, start the cooldown, bloom the cone.
## Returns true if a shot actually went off (so the owner only raycasts then).
func fire() -> bool:
	if not can_fire():
		return false
	ammo -= 1
	_cooldown = 1.0 / stats.fire_rate
	spread = minf(spread + stats.spread_per_shot, stats.max_spread)
	return true


## Begin a reload if it would do anything (not already reloading, mag not full,
## spare rounds available). Returns whether the reload started.
func start_reload() -> bool:
	if is_reloading() or ammo >= stats.mag_size or reserve <= 0:
		return false
	_reload_remaining = stats.reload_time
	return true


## Advance cooldown, reload timer (refilling the mag on completion), and bloom
## recovery for one frame.
func tick(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(_cooldown - delta, 0.0)
	if is_reloading():
		_reload_remaining -= delta
		if _reload_remaining <= 0.0:
			_reload_remaining = 0.0
			_complete_reload()
	else:
		spread = maxf(spread - stats.spread_recovery * delta, stats.base_spread)


func _complete_reload() -> void:
	var needed: int = stats.mag_size - ammo
	var take: int = mini(needed, reserve)
	ammo += take
	reserve -= take
