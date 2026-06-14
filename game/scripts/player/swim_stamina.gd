class_name SwimStamina
extends RefCounted
## Pure swim-stamina / oxygen meter for the player when in water.
##
## No scene access — the swim node (SwimMotion lives one layer below for the raw
## motion math) owns one of these and feeds it submersion/sprint/depth/time, so
## the breath-and-fatigue curves are unit-tested (tests/unit/test_swim_stamina.gd).
## This is the math layer ABOVE the motion: oxygen drains while the head is under
## (faster the deeper you dive), refills at the surface; stamina drains while
## swimming (more when sprinting) and recovers while idle/floating.

## Oxygen lost per second at the surface depth (depth 0), scaled up by pressure.
const OXYGEN_DRAIN_PER_SECOND: float = 1.0
## Oxygen regained per second of breathing at the surface (a gasp recovers fast).
const OXYGEN_REFILL_PER_SECOND: float = 5.0
## Stamina lost per second of ordinary swimming.
const STAMINA_DRAIN_PER_SECOND: float = 4.0
## Extra stamina lost per second while sprint-swimming, on top of the base drain.
const SPRINT_STAMINA_EXTRA: float = 8.0
## Stamina regained per second while idle/floating (slower than it drains).
const STAMINA_RECOVER_PER_SECOND: float = 3.0
## Metres of depth that double the pressure (1 atm at surface, 2 atm at this depth).
const DEPTH_PER_ATMOSPHERE: float = 10.0
## Swim-speed multiplier once exhausted — you can still paddle, just slowly.
const EXHAUSTED_SPEED_FACTOR: float = 0.5
## Swim-speed multiplier while sprinting (only granted while stamina lasts).
const SPRINT_SPEED_FACTOR: float = 1.6

var max_oxygen: float
var oxygen_value: float
var max_stamina: float
var stamina_value: float


func _init(maximum_oxygen: float = 20.0, maximum_stamina: float = 100.0) -> void:
	max_oxygen = maxf(maximum_oxygen, 0.0001)
	oxygen_value = max_oxygen
	max_stamina = maxf(maximum_stamina, 0.0001)
	stamina_value = max_stamina


## Advance one frame. `is_underwater` true means the head is under (the swim node
## decides this); `depth` is how far below the surface the head is, in metres
## (negative treated as 0). Oxygen drains underwater, faster the deeper you are,
## and refills at the surface. Stamina drains while swimming — more when
## sprinting — and recovers while idle/floating. Both stay clamped to [0, max].
func update(is_underwater: bool, is_sprinting: bool, depth: float, delta: float) -> void:
	var step := maxf(delta, 0.0)
	if is_underwater:
		oxygen_value -= OXYGEN_DRAIN_PER_SECOND * pressure_at(depth) * step
	else:
		oxygen_value += OXYGEN_REFILL_PER_SECOND * step
	oxygen_value = clampf(oxygen_value, 0.0, max_oxygen)

	var swimming := is_underwater or depth > 0.0
	if swimming:
		var drain := STAMINA_DRAIN_PER_SECOND
		# Sprint only costs extra while there is stamina to spend it on.
		if is_sprinting and stamina_value > 0.0:
			drain += SPRINT_STAMINA_EXTRA
		stamina_value -= drain * step
	else:
		stamina_value += STAMINA_RECOVER_PER_SECOND * step
	stamina_value = clampf(stamina_value, 0.0, max_stamina)


func oxygen() -> float:
	return oxygen_value


func oxygen_fraction() -> float:
	return oxygen_value / max_oxygen


func stamina() -> float:
	return stamina_value


func stamina_fraction() -> float:
	return stamina_value / max_stamina


## Out of breath while still under: this is when drowning damage begins.
func is_drowning(is_underwater: bool) -> bool:
	return is_underwater and oxygen_value <= 0.0


## No stamina left — sprint is disabled and swim speed is throttled.
func is_exhausted() -> bool:
	return stamina_value <= 0.0


## Drowning damage for this frame: `dps` per second once oxygen is gone and the
## head is under, zero while there is any breath left. Negative inputs guarded.
func drown_damage(is_underwater: bool, delta: float, dps: float) -> float:
	if not is_drowning(is_underwater):
		return 0.0
	return maxf(dps, 0.0) * maxf(delta, 0.0)


## Effective swim speed: throttled to a crawl when exhausted, boosted while
## sprinting — but the sprint boost only applies while stamina remains, so an
## exhausted player can't sprint their way out of trouble.
func swim_speed(base_speed: float, is_sprinting: bool) -> float:
	if is_exhausted():
		return base_speed * EXHAUSTED_SPEED_FACTOR
	if is_sprinting:
		return base_speed * SPRINT_SPEED_FACTOR
	return base_speed


## Water pressure in atmospheres at `depth` metres (1.0 at the surface, rising
## linearly with depth). Informational, and the multiplier on oxygen drain so a
## deep dive burns breath faster. Negative depth clamps to the surface.
func pressure_at(depth: float) -> float:
	return 1.0 + maxf(depth, 0.0) / DEPTH_PER_ATMOSPHERE


## Instant breath refill on reaching air (a surfacing gasp), without touching
## stamina — fatigue doesn't vanish the moment your head clears the water.
func surface() -> void:
	oxygen_value = max_oxygen


## Back to a fresh dive: full breath and full stamina.
func reset() -> void:
	oxygen_value = max_oxygen
	stamina_value = max_stamina
