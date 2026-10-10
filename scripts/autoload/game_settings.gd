extends Node
## Graphics quality presets, input map and persisted options.
##
## The world registers its Environment and sun here; every preset change is
## applied live (no restart), so players can compare F1..F4 in game.

signal preset_changed(preset: int)

enum Preset { LOW, MEDIUM, HIGH, ULTRA }

const PRESET_NAMES := ["Low", "Medium", "High", "Ultra"]
const SETTINGS_PATH := "user://settings.cfg"
## Bumped when the presets change meaning, so a saved choice is re-detected.
const SETTINGS_VERSION := 2
## Highest resolution scale per preset, and the most megapixels the 3D scene is
## rendered at before upscaling. Without the budget a maximised window on a
## Retina display renders 8+ MP natively and Ultra drops below 20 fps on an M4 Pro.
const MAX_SCALE := [0.67, 0.77, 0.85, 1.0]
## Measured on an M4 Pro at 8.6 MP: High at 5.0 MP holds about 60 fps and looks
## clearly sharper than the earlier 3.2 MP (internal 2237 x 1430 was visibly soft
## and stair-stepped on shadow and unit edges); Ultra 6.5 MP (native was 25 fps).
const PIXEL_BUDGET_MP := [2.6, 3.8, 5.0, 6.5]
## The HUD is laid out for a 1080-pixel-tall window and scaled up from there.
const UI_BASE_HEIGHT := 1080.0

var preset: int = Preset.HIGH
var particle_budget: float = 1.0
var hdr_output: bool = false
## Frame-rate cap (0 = uncapped). 60 keeps laptop fans and battery calm; an
## RTS gains nothing from rendering 120 frames a second on a ProMotion screen.
var fps_cap: int = 60

var _env: Environment
var _sun: DirectionalLight3D


func _ready() -> void:
	_register_input_actions()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and int(cfg.get_value("graphics", "version", 1)) == SETTINGS_VERSION:
		preset = int(cfg.get_value("graphics", "preset", detect_preset()))
		hdr_output = bool(cfg.get_value("graphics", "hdr_output", OS.get_name() == "macOS"))
	else:
		preset = detect_preset()
		# MacBook Pro XDR and Studio Display screens get real HDR highlights.
		hdr_output = OS.get_name() == "macOS"

	get_window().hdr_output_requested = hdr_output
	get_window().size_changed.connect(_on_window_resized)
	_on_window_resized()


## Picks a starting preset from the GPU name. Apple M-series chips get High or
## Ultra; integrated and entry-level discrete GPUs (the 4 GB ThinkPad) get Low.
func detect_preset() -> int:
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	if OS.get_name() == "macOS":
		# Measured on an M4 Pro at a maximised Retina window: High holds about
		# 60 fps, Ultra about half that, so only the biggest GPUs start on Ultra.
		for chip in ["max", "ultra"]:
			if adapter.contains(chip):
				return Preset.ULTRA
		for chip in ["m3", "m4", "m5", "pro"]:
			if adapter.contains(chip):
				return Preset.HIGH
		return Preset.MEDIUM
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
	# Measured on an M4 Pro at an 8.6 MP Retina window: MetalFX temporal costs
	# about 8 ms a frame, MetalFX spatial plus TAA about 2.5 ms, so Metal uses
	# the spatial upscaler. FSR 2 (unmeasured) stays the choice elsewhere.
	var upscaler := Viewport.SCALING_3D_MODE_METALFX_SPATIAL if metal else Viewport.SCALING_3D_MODE_FSR2

	# Resolution scale and anti-aliasing. Temporal upscalers replace TAA; Ultra
	# only renders natively (with TAA) when the window fits its pixel budget.
	var scale := render_scale()
	var native := scale >= 1.0
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if native else upscaler
	vp.scaling_3d_scale = scale
	vp.use_taa = native or (metal and preset >= Preset.MEDIUM) # FSR 2 brings its own temporal AA
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if preset == Preset.LOW else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.mesh_lod_threshold = [4.0, 2.0, 1.0, 0.5][preset]

	# Shadows.
	var atlas: int = [2048, 2048, 4096, 4096][preset]
	RenderingServer.directional_shadow_atlas_set_size(atlas, preset < Preset.HIGH)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		[RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][preset])
	RenderingServer.positional_soft_shadow_filter_set_quality(
		[RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][preset])
	if _sun:
		# Every shadow split redraws the whole battlefield (trees, shrubs, props),
		# so only Ultra pays for four of them.
		_sun.directional_shadow_mode = [DirectionalLight3D.SHADOW_ORTHOGONAL, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
			DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS][preset]
		_sun.directional_shadow_max_distance = [90.0, 100.0, 100.0, 160.0][preset]

	# Screen-space effects and global illumination.
	RenderingServer.environment_set_ssao_quality(
		[RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, RenderingServer.ENV_SSAO_QUALITY_LOW,
		RenderingServer.ENV_SSAO_QUALITY_MEDIUM, RenderingServer.ENV_SSAO_QUALITY_HIGH][preset],
		true, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_ssil_quality(
		[RenderingServer.ENV_SSIL_QUALITY_VERY_LOW, RenderingServer.ENV_SSIL_QUALITY_LOW,
		RenderingServer.ENV_SSIL_QUALITY_MEDIUM, RenderingServer.ENV_SSIL_QUALITY_MEDIUM][preset],
		true, 0.5, 4, 50.0, 300.0)
	RenderingServer.environment_set_ssr_half_size(true)
	RenderingServer.environment_set_sdfgi_ray_count(
		[RenderingServer.ENV_SDFGI_RAY_COUNT_8, RenderingServer.ENV_SDFGI_RAY_COUNT_16,
		RenderingServer.ENV_SDFGI_RAY_COUNT_16, RenderingServer.ENV_SDFGI_RAY_COUNT_32][preset])
	RenderingServer.gi_set_use_half_resolution(true)
	RenderingServer.environment_set_volumetric_fog_volume_size([64, 64, 96, 128][preset], [48, 48, 64, 96][preset])
	RenderingServer.environment_set_volumetric_fog_filter_active(preset >= Preset.HIGH)

	if _env:
		_env.ssao_enabled = preset >= Preset.MEDIUM
		# The full-screen lighting passes are the expensive part: screen-space
		# indirect light and SDFGI together halve the frame rate, so only Ultra
		# has them. See scripts/dev/benchmark.gd (--benchmark-costs).
		_env.ssil_enabled = preset >= Preset.ULTRA
		_env.ssr_enabled = preset >= Preset.HIGH
		_env.ssr_max_steps = [16, 32, 32, 64][preset]
		_env.sdfgi_enabled = preset >= Preset.ULTRA
		_env.sdfgi_cascades = 4
		_env.volumetric_fog_enabled = preset >= Preset.ULTRA # distance haze comes from the cheap depth fog
		_env.glow_enabled = preset >= Preset.MEDIUM
		_env.fog_enabled = true

	particle_budget = [0.35, 0.6, 1.0, 1.5][preset]
	Engine.max_fps = fps_cap
	preset_changed.emit(preset)
	_save()


## 3D resolution scale for the current preset and window size.
func render_scale() -> float:
	var size := get_window().size
	var megapixels := maxf(size.x * size.y / 1e6, 0.1)
	return clampf(sqrt(PIXEL_BUDGET_MP[preset] / megapixels), 0.5, MAX_SCALE[preset])


func _on_window_resized() -> void:
	var win := get_window()
	win.content_scale_factor = clampf(win.size.y / UI_BASE_HEIGHT, 1.0, 3.0)
	if _env:
		var scale := render_scale()
		if not is_equal_approx(scale, get_viewport().scaling_3d_scale):
			apply_preset(preset)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "version", SETTINGS_VERSION)
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
		# Classic RTS layout: arrows and the screen edge move the camera, the
		# left hand stays on the command keys (A attack-move, S stop, H hold,
		# P patrol), as in StarCraft, Red Alert 2 and C&C Remastered.
		"cam_left": [KEY_LEFT],
		"cam_right": [KEY_RIGHT],
		"cam_forward": [KEY_UP],
		"cam_back": [KEY_DOWN],
		"cam_rotate_left": [KEY_Q],
		"cam_rotate_right": [KEY_E],
		"cam_reset": [KEY_HOME],
		"cam_scroll_faster": [KEY_EQUAL],
		"cam_scroll_slower": [KEY_MINUS],
		"cam_lock_mouse": [KEY_F9],
		"jump_to_alert": [KEY_SPACE],
		"order_attack_move": [KEY_A, KEY_R],
		"order_stop": [KEY_S, KEY_X],
		"order_hold": [KEY_H],
		"order_patrol": [KEY_P],
		"toggle_voices": [KEY_V],
		"toggle_help": [KEY_F10, KEY_SLASH],
		"ability_strike": [KEY_F],
		"ability_airstrike": [KEY_G],
		"vfx_showcase": [KEY_F7],
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
