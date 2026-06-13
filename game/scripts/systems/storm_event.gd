class_name StormEvent
extends RefCounted
## A discrete severe TROPICAL STORM sweeping Vice City — the Florida set-piece on
## top of the continuous WeatherState front. Where WeatherState owns ambient
## fog/rain/wetness, this models a named storm's LIFECYCLE (calm → watch →
## warning → landfall → aftermath → clearing) and the gameplay CONSEQUENCES that
## ride its intensity: blinding rain, slick roads, flooding low ground, power
## outages that kill the neon, looting opportunity while the cops are swamped, and
## NPC evacuation pressure.
##
## Intensity follows a smooth bump that peaks at landfall (mid-storm) and eases off,
## so a controller just trigger()s a storm and advance(dt)s it; everything else is
## a pure read of the current intensity. Scene-free + deterministic — unit-tested
## headless (tests/unit/test_storm_event.gd). A WeatherController can drive its rain
## from intensity(); crime/economy systems read looting_opportunity(); a power grid
## reads power_outage_chance(); CrowdDirector reads evacuation_pressure().

const DEFAULT_DURATION: float = 180.0
## Intensity at/above which the storm is "landfall" — stay-indoors dangerous.
const LANDFALL_THRESHOLD: float = 0.7
## Elevation (m) at/above which ground no longer floods at peak intensity.
const FLOOD_CEILING_M: float = 5.0
## Peak visibility loss and road-grip loss at full intensity.
const VIS_DROP: float = 0.8
const GRIP_DROP: float = 0.5

# Phase boundaries along the 0..1 storm progress.
const WATCH_END: float = 0.15
const WARNING_END: float = 0.4
const LANDFALL_END: float = 0.6
const AFTERMATH_END: float = 0.85

var _duration: float = DEFAULT_DURATION
var _progress: float = 0.0
var _active: bool = false


func _init(duration: float = DEFAULT_DURATION) -> void:
	_duration = maxf(duration, 1.0)


# --- Lifecycle ---------------------------------------------------------------


## Kick off a fresh storm from calm.
func trigger() -> void:
	_active = true
	_progress = 0.0


## Advance the storm clock; it passes (deactivates) once progress reaches 1.
func advance(dt: float) -> void:
	if not _active or dt <= 0.0:
		return
	_progress = clampf(_progress + dt / _duration, 0.0, 1.0)
	if _progress >= 1.0:
		_active = false


func is_active() -> bool:
	return _active


func progress() -> float:
	return _progress


## Smooth bump: 0 at the edges, 1.0 at landfall (mid-storm). 0 when no storm.
func intensity() -> float:
	return pow(sin(_progress * PI), 2.0)


func phase() -> String:
	if not _active:
		return "calm"
	if _progress < WATCH_END:
		return "watch"
	if _progress < WARNING_END:
		return "warning"
	if _progress < LANDFALL_END:
		return "landfall"
	if _progress < AFTERMATH_END:
		return "aftermath"
	return "clearing"


func is_dangerous() -> bool:
	return intensity() >= LANDFALL_THRESHOLD


# --- Consequences (pure reads of the current intensity) ----------------------


## 1 = clear, dropping toward 0.2 at peak as rain blinds the streets.
func visibility() -> float:
	return clampf(1.0 - VIS_DROP * intensity(), 0.0, 1.0)


## Tyre grip on the wet roads, 1 dry → 0.5 at peak.
func road_grip() -> float:
	return clampf(1.0 - GRIP_DROP * intensity(), 0.0, 1.0)


## 0..1 chance the grid drops (kills neon/traffic lights) — only the strong half.
func power_outage_chance() -> float:
	return clampf((intensity() - 0.5) / 0.5, 0.0, 1.0)


## 0..1 flood depth risk at a given ground elevation (m): worst on low ground.
func flood_risk(elevation_m: float) -> float:
	return clampf(intensity() * (1.0 - maxf(elevation_m, 0.0) / FLOOD_CEILING_M), 0.0, 1.0)


## 0..1 — looting is easy while the storm has the city (and the cops) pinned down.
func looting_opportunity() -> float:
	return clampf((intensity() - 0.3) / 0.7, 0.0, 1.0)


## 0..1 — how hard NPCs are pushed to flee indoors.
func evacuation_pressure() -> float:
	return intensity()


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	return {"progress": _progress, "active": _active, "duration": _duration}


func from_dict(data: Dictionary) -> void:
	_duration = maxf(float(data.get("duration", DEFAULT_DURATION)), 1.0)
	_progress = clampf(float(data.get("progress", 0.0)), 0.0, 1.0)
	_active = bool(data.get("active", false))
