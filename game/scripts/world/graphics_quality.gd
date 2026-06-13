class_name GraphicsQuality
extends RefCounted
## Single source of truth for runtime graphics presets.
##
## The menu, live world, density-aware systems and benchmark all consume the
## same profile so a named tier always means the same render scale, AA strategy,
## shadow budget, environment tier and simulation density.

enum Tier { LOW, MEDIUM, HIGH, ULTRA }

const CONFIG_PATH: String = "user://settings.cfg"
const CONFIG_SECTION: String = "options"
const CONFIG_KEY: String = "graphics"
const PROJECT_SETTING: String = "rendering/quality_tier"
const DEFAULT_TIER: int = Tier.MEDIUM


## Return an immutable-by-convention profile for a tier. FSR2 is the sole AA
## path: below native resolution it upscales temporally, and at 1.0 it acts as
## TAA. Separate TAA, screen-space AA and MSAA stay off to avoid duplicate work.
static func profile(tier: int) -> Dictionary:
	match clamp_tier(tier):
		Tier.LOW:
			return {
				"tier": Tier.LOW,
				"name": "low",
				"render_scale": 0.67,
				"scaling_mode": Viewport.SCALING_3D_MODE_FSR2,
				"msaa": Viewport.MSAA_DISABLED,
				"use_taa": false,
				"screen_space_aa": Viewport.SCREEN_SPACE_AA_DISABLED,
				"mesh_lod_threshold": 4.0,
				"shadow_atlas_size": 2048,
				"directional_shadow_quality": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
				"positional_shadow_quality": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
				"shadow_distance": 120.0,
				"environment_tier": Tier.LOW,
				"crowd_multiplier": 0.25,
				"traffic_multiplier": 0.25,
			}
		Tier.HIGH:
			return {
				"tier": Tier.HIGH,
				"name": "high",
				"render_scale": 1.0,
				"scaling_mode": Viewport.SCALING_3D_MODE_FSR2,
				"msaa": Viewport.MSAA_DISABLED,
				"use_taa": false,
				"screen_space_aa": Viewport.SCREEN_SPACE_AA_DISABLED,
				"mesh_lod_threshold": 1.0,
				"shadow_atlas_size": 4096,
				"directional_shadow_quality": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
				"positional_shadow_quality": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
				"shadow_distance": 350.0,
				"environment_tier": Tier.HIGH,
				"crowd_multiplier": 1.0,
				"traffic_multiplier": 1.0,
			}
		Tier.ULTRA:
			return {
				"tier": Tier.ULTRA,
				"name": "ultra",
				"render_scale": 1.0,
				"scaling_mode": Viewport.SCALING_3D_MODE_FSR2,
				"msaa": Viewport.MSAA_DISABLED,
				"use_taa": false,
				"screen_space_aa": Viewport.SCREEN_SPACE_AA_DISABLED,
				"mesh_lod_threshold": 1.0,
				"shadow_atlas_size": 8192,
				"directional_shadow_quality": RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
				"positional_shadow_quality": RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
				"shadow_distance": 500.0,
				"environment_tier": Tier.ULTRA,
				"crowd_multiplier": 1.0,
				"traffic_multiplier": 1.0,
			}
		_:
			return {
				"tier": Tier.MEDIUM,
				"name": "medium",
				"render_scale": 0.85,
				"scaling_mode": Viewport.SCALING_3D_MODE_FSR2,
				"msaa": Viewport.MSAA_DISABLED,
				"use_taa": false,
				"screen_space_aa": Viewport.SCREEN_SPACE_AA_DISABLED,
				"mesh_lod_threshold": 2.0,
				"shadow_atlas_size": 2048,
				"directional_shadow_quality": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
				"positional_shadow_quality": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
				"shadow_distance": 220.0,
				"environment_tier": Tier.MEDIUM,
				"crowd_multiplier": 0.6,
				"traffic_multiplier": 0.6,
			}


## Apply the engine-global and root-viewport parts of a profile, then notify
## live scene systems that own environment, light or density settings.
static func apply_to_tree(tier: int, tree: SceneTree) -> void:
	if tree == null or tree.root == null:
		return
	var resolved := clamp_tier(tier)
	apply_engine(resolved, tree.root)
	tree.call_group("graphics_quality_aware", "apply_graphics_quality", resolved)


static func apply_engine(tier: int, viewport: Viewport) -> void:
	if viewport == null:
		return
	var p := profile(tier)
	viewport.scaling_3d_mode = int(p["scaling_mode"])
	viewport.scaling_3d_scale = float(p["render_scale"])
	viewport.msaa_3d = int(p["msaa"])
	viewport.use_taa = bool(p["use_taa"])
	viewport.screen_space_aa = int(p["screen_space_aa"])
	viewport.mesh_lod_threshold = float(p["mesh_lod_threshold"])
	RenderingServer.directional_shadow_atlas_set_size(int(p["shadow_atlas_size"]), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(int(p["directional_shadow_quality"]))
	RenderingServer.positional_soft_shadow_filter_set_quality(int(p["positional_shadow_quality"]))


## Environment variable wins for repeatable benchmark launches, followed by an
## explicit project setting, then the persisted menu selection.
static func resolved_tier(fallback: int = DEFAULT_TIER) -> int:
	var env_tier := tier_from_name(OS.get_environment("GTA_QUALITY"))
	if env_tier >= 0:
		return env_tier
	if ProjectSettings.has_setting(PROJECT_SETTING):
		return clamp_tier(int(ProjectSettings.get_setting(PROJECT_SETTING)))
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		return clamp_tier(int(cfg.get_value(CONFIG_SECTION, CONFIG_KEY, fallback)))
	return clamp_tier(fallback)


static func tier_from_name(value: String) -> int:
	match value.strip_edges().to_lower():
		"low":
			return Tier.LOW
		"medium":
			return Tier.MEDIUM
		"high":
			return Tier.HIGH
		"ultra":
			return Tier.ULTRA
	return -1


static func tier_name(tier: int) -> String:
	return str(profile(tier)["name"])


static func clamp_tier(tier: int) -> int:
	return clampi(tier, Tier.LOW, Tier.ULTRA)


## The settings UI exposes Low/Medium/High; Ultra remains an explicit launch or
## project override for captures and high-end testing.
static func clamp_menu_tier(tier: int) -> int:
	return clampi(tier, Tier.LOW, Tier.HIGH)
