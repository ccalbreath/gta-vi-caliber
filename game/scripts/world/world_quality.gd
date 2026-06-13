class_name WorldQuality
extends WorldEnvironment
## Applies a GPU-budget-gated cinematic grade to this scene's WorldEnvironment at
## runtime, so the gameplay scene gets premium lighting without baking the
## expensive GI passes into the .tscn (which would force the cost on every GPU,
## the regression LOOP_HANDOFF flagged). The tier resolves from $GTA_QUALITY or
## defaults to MEDIUM — see GraphicsQuality.resolved_tier.
##
## The scene keeps its own sky/background; only the grade + AO/reflections/GI
## layers are touched, so SkyController/DayNight tinting still drives the sky.

@export_range(0, 3, 1) var minimum_tier: int = GraphicsQuality.Tier.LOW


func _ready() -> void:
	add_to_group("graphics_quality_aware")
	if environment == null:
		environment = Environment.new()
	var tier := maxi(GraphicsQuality.resolved_tier(), minimum_tier)
	GraphicsQuality.apply_engine(tier, get_viewport())
	apply_graphics_quality(tier)


func apply_graphics_quality(tier: int) -> void:
	if environment == null:
		environment = Environment.new()
	var effective_tier := maxi(GraphicsQuality.clamp_tier(tier), minimum_tier)
	var p := GraphicsQuality.profile(effective_tier)
	CinematicEnvironment.apply_quality(environment, int(p["environment_tier"]))
