class_name CombatTextMotion
extends RefCounted
## Pure rise/fade curve for floating damage numbers.
##
## Scene-free so the popup motion is unit-tested (tests/unit/
## test_combat_text_motion.gd) while CombatText just applies it each frame. A
## popup eases upward (decelerating) over its lifetime and holds full opacity
## before fading out in the back half so the number is readable on impact.


## Vertical offset (metres) at time t into a `duration`-second life. Ease-out so
## it pops up fast then settles.
static func rise(t: float, duration: float, height: float) -> float:
	var p := clampf(t / maxf(duration, 0.0001), 0.0, 1.0)
	return height * (1.0 - (1.0 - p) * (1.0 - p))


## Opacity in [0, 1]: full until fade_start of the life, then linear to zero.
static func alpha(t: float, duration: float, fade_start: float = 0.5) -> float:
	var p := clampf(t / maxf(duration, 0.0001), 0.0, 1.0)
	if p <= fade_start:
		return 1.0
	return clampf(1.0 - (p - fade_start) / maxf(1.0 - fade_start, 0.0001), 0.0, 1.0)


static func is_done(t: float, duration: float) -> bool:
	return t >= duration
