extends RefCounted
## Unit tests for CinematicEnvironment — the premium lighting preset has the
## headline features (GI, screen-space reflections, bloom, volumetrics, filmic
## tonemap, sky) switched on, and enhance() upgrades an env in place.


func test_builds_an_environment() -> bool:
	return CinematicEnvironment.build() is Environment


func test_global_illumination_and_ao_on() -> bool:
	var e := CinematicEnvironment.build()
	return e.sdfgi_enabled and e.ssao_enabled and e.ssil_enabled


func test_screen_space_reflections_on() -> bool:
	# Glass curtain-walls need SSR to mirror the street/sky.
	return CinematicEnvironment.build().ssr_enabled


func test_bloom_and_volumetric_fog_on() -> bool:
	var e := CinematicEnvironment.build()
	return e.glow_enabled and e.volumetric_fog_enabled


func test_filmic_tonemap_and_grade() -> bool:
	var e := CinematicEnvironment.build()
	return e.tonemap_mode == Environment.TONE_MAPPER_ACES and e.adjustment_enabled


func test_has_a_sky() -> bool:
	return CinematicEnvironment.build().sky != null


func test_enhance_upgrades_in_place_without_forcing_gi() -> bool:
	# enhance() defaults to no SDFGI (streamed world) but still adds SSR + AO so
	# the live scene keeps its own sky while gaining the reflections/grade.
	var base := Environment.new()
	var e := CinematicEnvironment.enhance(base)
	return e == base and e.ssr_enabled and e.ssao_enabled and not e.sdfgi_enabled


func test_quality_low_is_cheap_but_not_flat() -> bool:
	# LOW must kill the flat look (ACES + grade + bloom) yet pay for none of the
	# screen-space / GI passes — the always-affordable gameplay floor.
	var e := CinematicEnvironment.apply_quality(Environment.new(), CinematicEnvironment.Quality.LOW)
	var graded := (
		e.tonemap_mode == Environment.TONE_MAPPER_ACES and e.glow_enabled and e.adjustment_enabled
	)
	var cheap := (
		not e.ssao_enabled
		and not e.ssr_enabled
		and not e.ssil_enabled
		and not e.volumetric_fog_enabled
		and not e.sdfgi_enabled
	)
	return graded and cheap


func test_quality_medium_adds_screenspace_only() -> bool:
	# MEDIUM (the default) buys SSAO + SSR but still withholds the GI pair that
	# tanks FPS on weaker GPUs.
	var e := CinematicEnvironment.apply_quality(
		Environment.new(), CinematicEnvironment.Quality.MEDIUM
	)
	return e.ssao_enabled and e.ssr_enabled and not e.ssil_enabled and not e.sdfgi_enabled


func test_quality_high_adds_indirect_and_volumetric() -> bool:
	var e := CinematicEnvironment.apply_quality(
		Environment.new(), CinematicEnvironment.Quality.HIGH
	)
	return e.ssil_enabled and e.volumetric_fog_enabled and not e.sdfgi_enabled


func test_quality_ultra_enables_gi() -> bool:
	var e := CinematicEnvironment.apply_quality(
		Environment.new(), CinematicEnvironment.Quality.ULTRA
	)
	return e.sdfgi_enabled and e.ssil_enabled and e.ssr_enabled and e.ssao_enabled


func test_apply_quality_is_idempotent_lowering_tier() -> bool:
	# Re-applying a lower tier must switch the heavies back off (not leave them
	# latched), so a runtime quality change can't strand SDFGI on.
	var e := Environment.new()
	CinematicEnvironment.apply_quality(e, CinematicEnvironment.Quality.ULTRA)
	CinematicEnvironment.apply_quality(e, CinematicEnvironment.Quality.LOW)
	return not e.sdfgi_enabled and not e.ssil_enabled and not e.ssr_enabled and not e.ssao_enabled


func test_apply_quality_preserves_existing_sky() -> bool:
	# The gameplay scene owns its day/night sky; apply_quality must not replace it.
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	e.sky = sky
	CinematicEnvironment.apply_quality(e, CinematicEnvironment.Quality.MEDIUM)
	return e.sky == sky and e.background_mode == Environment.BG_SKY


func test_apply_quality_preserves_authored_scene_grade() -> bool:
	var e := Environment.new()
	e.ambient_light_energy = 0.78
	e.tonemap_exposure = 0.82
	e.tonemap_white = 8.0
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.14
	e.adjustment_saturation = 1.33
	e.adjustment_brightness = 0.94
	e.fog_enabled = true
	e.fog_light_color = Color(1.0, 0.72, 0.5)
	e.fog_aerial_perspective = 0.85
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.012
	e.volumetric_fog_albedo = Color(1.0, 0.86, 0.72)
	CinematicEnvironment.apply_quality(e, CinematicEnvironment.Quality.HIGH)
	return (
		is_equal_approx(e.ambient_light_energy, 0.78)
		and is_equal_approx(e.tonemap_exposure, 0.82)
		and is_equal_approx(e.tonemap_white, 8.0)
		and is_equal_approx(e.adjustment_contrast, 1.14)
		and is_equal_approx(e.adjustment_saturation, 1.33)
		and is_equal_approx(e.adjustment_brightness, 0.94)
		and _colors_match(e.fog_light_color, Color(1.0, 0.72, 0.5))
		and is_equal_approx(e.fog_aerial_perspective, 0.85)
		and is_equal_approx(e.volumetric_fog_density, 0.012)
		and _colors_match(e.volumetric_fog_albedo, Color(1.0, 0.86, 0.72))
	)


func test_quality_preserves_authored_fog_density() -> bool:
	# Regression (issue #10's brown wash): assigning Environment.fog_mode
	# resets fog_density to 1.0 inside the engine setter, even when the mode
	# is unchanged. apply_quality must hand back the authored density, not the
	# clobber — miami authors 0.00008, and 1.0 fogs out the entire world.
	var e := Environment.new()
	e.fog_enabled = true
	e.fog_density = 0.00008
	CinematicEnvironment.apply_quality(e, CinematicEnvironment.Quality.MEDIUM)
	return is_equal_approx(e.fog_density, 0.00008)


func test_quality_defaults_fog_density_when_not_authored() -> bool:
	# The other arm of the same assignment: a scene without authored fog still
	# gets the light aerial-perspective default, not the engine's 1.0.
	var e := Environment.new()
	e.fog_enabled = false
	CinematicEnvironment.apply_quality(e, CinematicEnvironment.Quality.MEDIUM)
	return is_equal_approx(e.fog_density, 0.0008)


func _colors_match(a: Color, b: Color) -> bool:
	return (
		is_equal_approx(a.r, b.r)
		and is_equal_approx(a.g, b.g)
		and is_equal_approx(a.b, b.b)
		and is_equal_approx(a.a, b.a)
	)
