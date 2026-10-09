extends Node
## Graphics quality presets, input map and persisted options.
##
## The world registers its Environment and sun here; every preset change is
## applied live (no restart), so players can compare F1..F4 in game.

signal preset_changed(preset: int)

enum Preset { LOW, MEDIUM, HIGH, ULTRA }

const PRESET_NAMES := ["Low", "Medium", "High", "Ultra"]
const SETTINGS_PATH := "user://settings.cfg"

var preset: int = Preset.HIGH
var particle_budget: float = 1.0
var hdr_output: bool = false

var _env: Environment
var _sun: DirectionalLight3D


func _ready() -> void:
	_register_input_actions()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		preset = int(cfg.get_value("graphics", "preset", detect_preset()))
		hdr_output = bool(cfg.get_value("graphics", "hdr_output", OS.get_name() == "macOS"))
	else:
		preset = detect_preset()
		# MacBook Pro XDR and Studio Display screens get real HDR highlights.
		hdr_output = OS.get_name() == "macOS"

	get_window().hdr_output_requested = hdr_output


## Picks a starting preset from the GPU name. Apple M-series chips get High or
## Ultra; integrated and entry-level discrete GPUs (the 4 GB ThinkPad) get Low.
func detect_preset() -> int:
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	if OS.get_name() == "macOS":
		for chip in ["m4", "m5", "max", "pro", "ultra"]:
			if adapter.contains(chip):
				return Preset.ULTRA
		return Preset.HIGH
	if adapter.contains("rtx 4") or adapter.contains("rtx 5") or adapter.contains("rx 7") or adapter.contains("rx 9"):
		return Preset.ULTRA
	if adapter.contains("rtx") or adapter.contains("rx 6"):
		return Preset.HIGH
	if adapter.contains("gtx") or adapter.contains("rx 5"):
		return Preset.MEDIUM
	return Preset.LOW


func register_world(env: Environment, sun: DirectionalLight3D) -> void:
	_env = env
	_sun = sun
	apply_preset(preset)


func set_hdr_output(enabled: bool) -> void:
	hdr_output = enabled
	get_window().hdr_output_requested = enabled
	_save()


func apply_preset(p: int) -> void:
	preset = clampi(p, Preset.LOW, Preset.ULTRA)
	var vp := get_viewport()
	var metal := RenderingServer.get_current_rendering_driver_name() == "metal"
	var temporal_upscaler := Viewport.SCALING_3D_MODE_METALFX_TEMPORAL if metal else Viewport.SCALING_3D_MODE_FSR2

	# Resolution scale and anti-aliasing. Temporal upscalers replace TAA.
	match preset:
		Preset.LOW:
			vp.scaling_3d_mode = temporal_upscaler
			vp.scaling_3d_scale = 0.67
		Preset.MEDIUM:
			vp.scaling_3d_mode = temporal_upscaler
			vp.scaling_3d_scale = 0.77
		Preset.HIGH:
			vp.scaling_3d_mode = temporal_upscaler
			vp.scaling_3d_scale = 0.85
		Preset.ULTRA:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
	vp.use_taa = preset == Preset.ULTRA
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA if preset == Preset.LOW else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.mesh_lod_threshold = [4.0, 2.0, 1.0, 0.5][preset]

	# Shadows.
	var atlas: int = [2048, 2048, 4096, 8192][preset]
	RenderingServer.directional_shadow_atlas_set_size(atlas, preset < Preset.HIGH)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		[RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][preset])
	RenderingServer.positional_soft_shadow_filter_set_quality(
		[RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][preset])
	if _sun:
		_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if preset == Preset.LOW else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		_sun.directional_shadow_max_distance = [90.0, 130.0, 170.0, 220.0][preset]

	# Screen-space effects and global illumination.
	RenderingServer.environment_set_ssao_quality(
		[RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, RenderingServer.ENV_SSAO_QUALITY_LOW,
		RenderingServer.ENV_SSAO_QUALITY_HIGH, RenderingServer.ENV_SSAO_QUALITY_ULTRA][preset],
		preset < Preset.HIGH, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_ssil_quality(
		[RenderingServer.ENV_SSIL_QUALITY_VERY_LOW, RenderingServer.ENV_SSIL_QUALITY_LOW,
		RenderingServer.ENV_SSIL_QUALITY_MEDIUM, RenderingServer.ENV_SSIL_QUALITY_HIGH][preset],
		preset < Preset.ULTRA, 0.5, 4, 50.0, 300.0)
	RenderingServer.environment_set_ssr_half_size(preset < Preset.ULTRA)
	RenderingServer.environment_set_ssr_roughness_quality(
		[RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_DISABLED, RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_LOW,
		RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_MEDIUM, RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_HIGH][preset])
	RenderingServer.environment_set_sdfgi_ray_count(
		[RenderingServer.ENV_SDFGI_RAY_COUNT_8, RenderingServer.ENV_SDFGI_RAY_COUNT_16,
		RenderingServer.ENV_SDFGI_RAY_COUNT_32, RenderingServer.ENV_SDFGI_RAY_COUNT_64][preset])
	RenderingServer.gi_set_use_half_resolution(preset < Preset.ULTRA)
	RenderingServer.environment_set_volumetric_fog_volume_size([64, 96, 128, 160][preset], [48, 64, 96, 128][preset])
	RenderingServer.environment_set_volumetric_fog_filter_active(preset >= Preset.HIGH)

	if _env:
		_env.ssao_enabled = preset >= Preset.MEDIUM
		_env.ssil_enabled = preset >= Preset.MEDIUM
		_env.ssr_enabled = preset >= Preset.MEDIUM
		_env.ssr_max_steps = [16, 32, 64, 96][preset]
		_env.sdfgi_enabled = preset >= Preset.HIGH
		_env.sdfgi_cascades = 6 if preset == Preset.ULTRA else 4
		_env.volumetric_fog_enabled = preset >= Preset.MEDIUM
		_env.glow_enabled = preset >= Preset.MEDIUM
		_env.fog_enabled = true

	particle_budget = [0.35, 0.6, 1.0, 1.5][preset]
	preset_changed.emit(preset)
	_save()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "preset", preset)
	cfg.set_value("graphics", "hdr_output", hdr_output)
	cfg.save(SETTINGS_PATH)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("quality_low"):
		apply_preset(Preset.LOW)
	elif event.is_action_pressed("quality_medium"):
		apply_preset(Preset.MEDIUM)
	elif event.is_action_pressed("quality_high"):
		apply_preset(Preset.HIGH)
	elif event.is_action_pressed("quality_ultra"):
		apply_preset(Preset.ULTRA)
	elif event.is_action_pressed("toggle_hdr"):
		set_hdr_output(not hdr_output)
	elif event.is_action_pressed("toggle_fullscreen"):
		var w := get_window()
		w.mode = Window.MODE_MAXIMIZED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN


func _register_input_actions() -> void:
	var keys := {
		"cam_left": [KEY_A, KEY_LEFT],
		"cam_right": [KEY_D, KEY_RIGHT],
		"cam_forward": [KEY_W, KEY_UP],
		"cam_back": [KEY_S, KEY_DOWN],
		"cam_rotate_left": [KEY_Q],
		"cam_rotate_right": [KEY_E],
		"order_attack_move": [KEY_R],
		"order_stop": [KEY_X],
		"ability_strike": [KEY_F],
		"cycle_time_of_day": [KEY_T],
		"select_all_army": [KEY_TAB],
		"quality_low": [KEY_F1],
		"quality_medium": [KEY_F2],
		"quality_high": [KEY_F3],
		"quality_ultra": [KEY_F4],
		"toggle_hdr": [KEY_F5],
		"toggle_fullscreen": [KEY_F11],
		"cancel": [KEY_ESCAPE],
	}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code: int in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)
