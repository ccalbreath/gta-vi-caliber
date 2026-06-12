class_name EmergencyServices
extends RefCounted
## Pure dispatch model for civilian emergency services — ambulances, fire trucks,
## and paramedics responding to incidents (a wreck, a fire, a downed pedestrian).
##
## Distinct from the police layers (PoliceDispatch/PoliceEscalation/PoliceResponse):
## those summon armed pursuit at a wanted level, this routes the *help* services
## (medical/fire) toward an incident and runs the paramedic-on-scene timer. The
## one police-shaped role here is POLICE_BACKUP for a SHOOTING — coordination, not
## a duplicate of the pursuit math.
##
## Static dispatch helpers (no scene/RNG/node state, deterministic, unit-tested in
## tests/unit/test_emergency_services.gd) plus one small stateful response timer
## (_init/begin/tick/has_arrived/progress/treating/cancel/reset) that a responder
## node ticks each frame to drive the siren-run → on-scene → treating sequence.
## Spatial math is on the XZ plane (y ignored), matching CombatAi / NpcBrain /
## PoliceDispatch.

## Which service rolls out — an ambulance for the hurt, a fire truck for fire,
## police backup to secure a violent scene. A spawner maps each to a prefab.
enum Service { AMBULANCE, FIRE_TRUCK, POLICE_BACKUP }

## What happened. WRECK = a vehicle collision, FIRE = a structure/vehicle ablaze,
## INJURY = a downed/hurt pedestrian, SHOOTING = a violent crime scene.
enum Incident { WRECK, FIRE, INJURY, SHOOTING }

## Response timer phases: idle before begin(), EN_ROUTE driving to the scene,
## then TREATING once on-scene and working the victim.
enum Phase { IDLE, EN_ROUTE, TREATING }

## At/above this many wanted stars a scene is "hot": unarmed medical and fire crews
## won't approach until the heat drops (you scared them off). Police backup, being
## armed, still rolls regardless.
const HOT_SCENE_STARS: int = 3

## Severity (0 unhurt … 1 fatal) at/above which revival fails outright — past
## saving by the time the medic arrives.
const UNREVIVABLE_SEVERITY: float = 1.0

## Stateful response-timer fields (the static helpers above are stateless). `phase`
## is the public run state; `_response_delay`/`_elapsed` drive the siren-run clock.
var phase: Phase = Phase.IDLE

var _response_delay: float
var _elapsed: float = 0.0


## The primary service for an incident. Fire → fire truck, injury/wreck → ambulance,
## shooting → police backup. An unknown/out-of-range incident defaults to an
## ambulance (help-first: someone is probably hurt).
static func service_for(incident: int) -> int:
	match incident:
		Incident.FIRE:
			return Service.FIRE_TRUCK
		Incident.WRECK:
			return Service.AMBULANCE
		Incident.INJURY:
			return Service.AMBULANCE
		Incident.SHOOTING:
			return Service.POLICE_BACKUP
		_:
			return Service.AMBULANCE


## Travel time (seconds) from a dispatch point to the incident at a given response
## speed, on the XZ plane. Guarded: zero/negative speed returns INF (can't get
## there), so callers treat it as "no responder available".
static func eta(dispatch_pos: Vector3, incident_pos: Vector3, response_speed: float) -> float:
	if response_speed <= 0.0:
		return INF
	var dx := incident_pos.x - dispatch_pos.x
	var dz := incident_pos.z - dispatch_pos.z
	return sqrt(dx * dx + dz * dz) / response_speed


## The closest responder to an incident. Each responder is a Dictionary with at
## least a `pos` (Vector3); other keys (e.g. `service`) are carried through intact.
## Returns the winning Dictionary, or {} when the list is empty / has no usable pos.
static func nearest_responder(incident_pos: Vector3, responders: Array) -> Dictionary:
	var best := {}
	var best_d := INF
	for responder: Dictionary in responders:
		if not responder.has("pos"):
			continue
		var pos: Vector3 = responder["pos"]
		var dx := pos.x - incident_pos.x
		var dz := pos.z - incident_pos.z
		var d := dx * dx + dz * dz
		if d < best_d:
			best_d = d
			best = responder
	return best


## Whether help should actually be dispatched to this incident now.
## - SHOOTING always gets POLICE_BACKUP — armed crews go in regardless of heat,
##   whether or not the player caused it.
## - Unarmed medical/fire crews refuse a HOT scene (wanted >= HOT_SCENE_STARS)
##   *that the player caused*: you scared them off, no ambulance rolls into your
##   active gunfight. A hot scene the player didn't cause (e.g. a pile-up beside an
##   unrelated chase) still gets help — the crews aren't afraid of you there.
## Below the hot threshold, any known incident is dispatched.
static func should_dispatch(incident: int, player_caused: bool, wanted_stars: int) -> bool:
	if service_for(incident) == Service.POLICE_BACKUP:
		return true
	if player_caused and wanted_stars >= HOT_SCENE_STARS:
		return false
	return true


## Paramedic revival odds (0 … 1) by victim injury severity (0 unhurt … 1 fatal).
## Falls linearly as the victim is more hurt; at/above UNREVIVABLE_SEVERITY it's 0.
static func revive_chance(injury_severity: float) -> float:
	var s := clampf(injury_severity, 0.0, 1.0)
	if s >= UNREVIVABLE_SEVERITY:
		return 0.0
	return 1.0 - s


# --- Stateful response timer ------------------------------------------------


## response_delay = seconds of siren-run before the unit reaches the scene.
func _init(response_delay: float = 6.0) -> void:
	_response_delay = maxf(response_delay, 0.0)


## Dispatch the unit: start the run to the scene. No-op if already running.
func begin() -> void:
	if phase != Phase.IDLE:
		return
	phase = Phase.EN_ROUTE
	_elapsed = 0.0


## Advance the run. No-op before begin() or once on-scene. Crossing the delay flips
## EN_ROUTE → TREATING exactly once (the medic starts working the victim).
func tick(delta: float) -> void:
	if phase != Phase.EN_ROUTE:
		return
	_elapsed += maxf(delta, 0.0)
	if _elapsed >= _response_delay:
		_elapsed = _response_delay
		phase = Phase.TREATING


## True once the unit has reached the scene (i.e. is treating).
func has_arrived() -> bool:
	return phase == Phase.TREATING


## True while a paramedic is on-scene working the victim (post-arrival).
func treating() -> bool:
	return phase == Phase.TREATING


## Run progress 0 … 1 toward arrival. 1.0 once on-scene; 1.0 too when the delay is
## zero (instant response) so an immediate unit reads as fully en route to done.
func progress() -> float:
	if phase == Phase.IDLE:
		return 0.0
	if phase == Phase.TREATING:
		return 1.0
	if _response_delay <= 0.0:
		return 1.0
	return clampf(_elapsed / _response_delay, 0.0, 1.0)


## Stand the unit down mid-run (false alarm / victim already gone). Back to idle.
func cancel() -> void:
	phase = Phase.IDLE
	_elapsed = 0.0


## Full reset to a fresh, un-dispatched unit (alias of cancel for symmetry).
func reset() -> void:
	cancel()
