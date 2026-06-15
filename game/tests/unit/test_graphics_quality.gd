class_name TestGraphicsQuality
extends GdUnitTestSuite
## Contract tests for the shared runtime graphics profiles.

const MIAMI_SCENE := preload("res://scenes/world/miami.tscn")


func test_named_tiers_round_trip() -> void:
	assert_int(GraphicsQuality.tier_from_name("low")).is_equal(GraphicsQuality.Tier.LOW)
	assert_int(GraphicsQuality.tier_from_name("MEDIUM")).is_equal(GraphicsQuality.Tier.MEDIUM)
	assert_int(GraphicsQuality.tier_from_name(" high ")).is_equal(GraphicsQuality.Tier.HIGH)
	assert_int(GraphicsQuality.tier_from_name("ultra")).is_equal(GraphicsQuality.Tier.ULTRA)
	assert_int(GraphicsQuality.tier_from_name("unknown")).is_equal(-1)


func test_all_tiers_use_only_fsr2_for_antialiasing() -> void:
	for tier in [
		GraphicsQuality.Tier.LOW,
		GraphicsQuality.Tier.MEDIUM,
		GraphicsQuality.Tier.HIGH,
		GraphicsQuality.Tier.ULTRA,
	]:
		var p := GraphicsQuality.profile(tier)
		assert_int(int(p["scaling_mode"])).is_equal(Viewport.SCALING_3D_MODE_FSR2)
		assert_int(int(p["msaa"])).is_equal(Viewport.MSAA_DISABLED)
		assert_bool(bool(p["use_taa"])).is_false()
		assert_int(int(p["screen_space_aa"])).is_equal(Viewport.SCREEN_SPACE_AA_DISABLED)


func test_render_scale_and_shadow_budget_increase_with_quality() -> void:
	var low := GraphicsQuality.profile(GraphicsQuality.Tier.LOW)
	var medium := GraphicsQuality.profile(GraphicsQuality.Tier.MEDIUM)
	var high := GraphicsQuality.profile(GraphicsQuality.Tier.HIGH)
	assert_bool(float(low["render_scale"]) < float(medium["render_scale"])).is_true()
	assert_bool(float(medium["render_scale"]) < float(high["render_scale"])).is_true()
	assert_bool(float(low["shadow_distance"]) < float(medium["shadow_distance"])).is_true()
	assert_bool(float(medium["shadow_distance"]) < float(high["shadow_distance"])).is_true()
	assert_bool(int(medium["shadow_atlas_size"]) <= int(high["shadow_atlas_size"])).is_true()


func test_low_environment_and_density_are_cheapest() -> void:
	var low := GraphicsQuality.profile(GraphicsQuality.Tier.LOW)
	var medium := GraphicsQuality.profile(GraphicsQuality.Tier.MEDIUM)
	var high := GraphicsQuality.profile(GraphicsQuality.Tier.HIGH)
	assert_int(int(low["environment_tier"])).is_equal(CinematicEnvironment.Quality.LOW)
	assert_bool(float(low["crowd_multiplier"]) < float(medium["crowd_multiplier"])).is_true()
	assert_bool(float(medium["crowd_multiplier"]) < float(high["crowd_multiplier"])).is_true()
	assert_bool(float(low["traffic_multiplier"]) < float(medium["traffic_multiplier"])).is_true()
	assert_bool(float(medium["traffic_multiplier"]) < float(high["traffic_multiplier"])).is_true()


func test_low_disables_expensive_environment_effects() -> void:
	var env := CinematicEnvironment.apply_quality(Environment.new(), GraphicsQuality.Tier.LOW)
	assert_bool(env.ssao_enabled).is_false()
	assert_bool(env.ssr_enabled).is_false()
	assert_bool(env.ssil_enabled).is_false()
	assert_bool(env.volumetric_fog_enabled).is_false()
	assert_bool(env.sdfgi_enabled).is_false()


func test_medium_keeps_high_tier_effects_disabled() -> void:
	var env := CinematicEnvironment.apply_quality(Environment.new(), GraphicsQuality.Tier.MEDIUM)
	assert_bool(env.ssao_enabled).is_true()
	assert_bool(env.ssr_enabled).is_true()
	assert_bool(env.ssil_enabled).is_false()
	assert_bool(env.volumetric_fog_enabled).is_false()
	assert_bool(env.sdfgi_enabled).is_false()


func test_apply_engine_configures_viewport_without_duplicate_aa() -> void:
	var viewport := SubViewport.new()
	GraphicsQuality.apply_engine(GraphicsQuality.Tier.MEDIUM, viewport)
	var p := GraphicsQuality.profile(GraphicsQuality.Tier.MEDIUM)
	assert_int(viewport.scaling_3d_mode).is_equal(Viewport.SCALING_3D_MODE_FSR2)
	assert_float(viewport.scaling_3d_scale).is_equal_approx(float(p["render_scale"]), 0.0001)
	assert_int(viewport.msaa_3d).is_equal(Viewport.MSAA_DISABLED)
	assert_bool(viewport.use_taa).is_false()
	assert_int(viewport.screen_space_aa).is_equal(Viewport.SCREEN_SPACE_AA_DISABLED)
	assert_float(viewport.mesh_lod_threshold).is_equal_approx(
		float(p["mesh_lod_threshold"]), 0.0001
	)
	viewport.free()


func test_graphics_menu_tier_clamps_to_visible_options() -> void:
	assert_int(GraphicsQuality.clamp_menu_tier(-10)).is_equal(GraphicsQuality.Tier.LOW)
	assert_int(GraphicsQuality.clamp_menu_tier(99)).is_equal(GraphicsQuality.Tier.HIGH)


func test_miami_allows_the_low_quality_tier() -> void:
	var scene := MIAMI_SCENE.instantiate()
	var world_quality := scene.get_node("WorldEnvironment") as WorldQuality
	assert_bool(world_quality != null).is_true()
	assert_int(world_quality.minimum_tier).is_equal(GraphicsQuality.Tier.LOW)
	scene.free()
