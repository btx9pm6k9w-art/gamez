class_name Benchmark
extends Node
## Developer benchmark: cycles the graphics presets, logs average frame rate
## and saves a screenshot of each. Started by main.gd when the game is run with
##   godot --path . -- --benchmark [--benchmark-out=/some/folder]

const WARMUP := 4.0 # lets shaders compile and SDFGI converge after a switch
const MEASURE := 6.0

var out_dir := "user://benchmark"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--benchmark-out="):
			out_dir = arg.trim_prefix("--benchmark-out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameSettings.fps_cap = 0
	_run.call_deferred()


func _measure(label: String, warmup: float, seconds: float) -> void:
	await get_tree().create_timer(warmup).timeout
	var frames := 0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < seconds * 1e6:
		await get_tree().process_frame
		frames += 1
	print("BENCH cost %-28s fps=%.1f" % [label, frames / ((Time.get_ticks_usec() - t0) / 1e6)])


## Starts from Ultra and turns features down one after another (cumulative),
## printing the frame rate after each step to show where the time goes.
func _run_costs() -> void:
	var env: Environment = GameSettings._env
	var vp := get_viewport()
	var rs := RenderingServer
	GameSettings.apply_preset(GameSettings.Preset.ULTRA)
	await _measure("ultra", 4.0, 3.0)
	var steps := {
		"+ ssil half size": func() -> void: rs.environment_set_ssil_quality(rs.ENV_SSIL_QUALITY_MEDIUM, true, 0.5, 4, 50.0, 300.0),
		"+ ssao half size": func() -> void: rs.environment_set_ssao_quality(rs.ENV_SSAO_QUALITY_HIGH, true, 0.5, 2, 50.0, 300.0),
		"+ volumetric fog 128x96": func() -> void: rs.environment_set_volumetric_fog_volume_size(128, 96),
		"+ shadows 4K": func() -> void: rs.directional_shadow_atlas_set_size(4096, false),
		"+ sdfgi 4 cascades 32 rays": func() -> void:
			env.sdfgi_cascades = 4
			rs.environment_set_sdfgi_ray_count(rs.ENV_SDFGI_RAY_COUNT_32),
		"+ ssr half size": func() -> void: rs.environment_set_ssr_half_size(true),
		"+ metalfx at 65% scale": func() -> void:
			vp.use_taa = false
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_METALFX_TEMPORAL
			vp.scaling_3d_scale = 0.65,
		"+ metalfx at 50% scale": func() -> void: vp.scaling_3d_scale = 0.5,
		"+ ssil off": func() -> void: env.ssil_enabled = false,
		"+ ssr off": func() -> void: env.ssr_enabled = false,
		"+ volumetric fog off": func() -> void: env.volumetric_fog_enabled = false,
		"+ sdfgi off": func() -> void: env.sdfgi_enabled = false,
		"+ ssao off": func() -> void: env.ssao_enabled = false,
		"+ glow off": func() -> void: env.glow_enabled = false,
		"+ post-process pass off": func() -> void: GameSettings.preset_changed.emit(GameSettings.Preset.LOW),
		"+ shadows off": func() -> void: GameSettings._sun.shadow_enabled = false,
	}
	for label: String in steps:
		(steps[label] as Callable).call()
		await _measure(label, 2.5, 2.5)
	print("BENCH done")
	get_tree().quit()


func _run() -> void:
	if "--benchmark-costs" in OS.get_cmdline_user_args():
		_run_costs()
		return
	var start_preset := GameSettings.preset
	var win := get_window()
	print("BENCH adapter=%s window=%s screen_scale=%.1f" % [
		RenderingServer.get_video_adapter_name(), win.size, DisplayServer.screen_get_scale()])
	for p in [GameSettings.Preset.LOW, GameSettings.Preset.MEDIUM, GameSettings.Preset.HIGH, GameSettings.Preset.ULTRA]:
		GameSettings.apply_preset(p)
		await get_tree().create_timer(WARMUP).timeout
		var frames := 0
		var worst := 0.0
		var t0 := Time.get_ticks_usec()
		while Time.get_ticks_usec() - t0 < MEASURE * 1e6:
			var f0 := Time.get_ticks_usec()
			await get_tree().process_frame
			worst = maxf(worst, (Time.get_ticks_usec() - f0) / 1000.0)
			frames += 1
		var secs := (Time.get_ticks_usec() - t0) / 1e6
		var vp := get_viewport()
		var cam := vp.get_camera_3d()
		var ground: Vector3 = Plane(Vector3.UP, 0.0).intersects_ray(cam.global_position, -cam.global_basis.z)
		print("BENCH ui_scale=%.2f visible=%s centre_unprojects_to=%s" % [
			win.content_scale_factor, vp.get_visible_rect().size, cam.unproject_position(ground)])
		print("BENCH preset=%s fps=%.1f worst_frame_ms=%.1f render=%dx%d draw_calls=%d vram_mb=%.0f" % [
			GameSettings.PRESET_NAMES[p], frames / secs, worst,
			int(win.size.x * vp.scaling_3d_scale), int(win.size.y * vp.scaling_3d_scale),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0])
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		if vp.use_hdr_2d: # the HDR 2D buffer is linear; PNGs are sRGB
			img.linear_to_srgb()
		img.save_png(out_dir.path_join("preset_%d_%s.png" % [p, GameSettings.PRESET_NAMES[p].to_lower()]))
	GameSettings.apply_preset(start_preset)
	print("BENCH done")
	get_tree().quit()
