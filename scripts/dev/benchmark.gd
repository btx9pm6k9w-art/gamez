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
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	GameSettings.fps_cap = 0
	for cam in get_tree().root.find_children("*", "RTSCamera", true, false):
		(cam as RTSCamera).edge_pan = false # an idle cursor at a screen edge would drift the view
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


## Prints how many mesh instances each kind of prop contributes, largest first.
func _print_census() -> void:
	var bf := get_tree().root.find_child("Battlefield", true, false)
	var counts := {}
	var total := 0
	for n in get_tree().root.find_children("*", "MeshInstance3D", true, false):
		total += 1
	if bf:
		for prop: Dictionary in bf.props:
			var node: Node3D = prop["node"]
			if is_instance_valid(node):
				var k: String = prop["kind"]
				var c: Array = counts.get(k, [0, 0])
				c[0] += 1
				c[1] += node.find_children("*", "MeshInstance3D", true, false).size() + (1 if node is MeshInstance3D else 0)
				counts[k] = c
	var kinds := counts.keys()
	kinds.sort_custom(func(a: String, b: String) -> bool: return counts[a][1] > counts[b][1])
	print("BENCH census mesh_instances_total=%d" % total)
	for k: String in kinds:
		print("BENCH census %-12s props=%d mesh_instances=%d" % [k, counts[k][0], counts[k][1]])


## Freezes one group of scripted nodes after another (cumulative) and prints the
## frame rate after each, to show which per-frame script costs the most.
func _run_scripts() -> void:
	GameSettings.apply_preset(GameSettings.Preset.LOW)
	await _measure("low, everything running", 4.0, 2.5)
	var groups := {}
	for n in get_tree().root.find_children("*", "", true, false):
		var sc := n.get_script() as Script
		if sc == null or n == self or n is Benchmark:
			continue
		var key := sc.resource_path.get_file()
		if not groups.has(key):
			groups[key] = []
		groups[key].append(n)
	for key: String in groups:
		for n: Node in groups[key]:
			if is_instance_valid(n):
				n.process_mode = Node.PROCESS_MODE_DISABLED
		await _measure("- %s (%d)" % [key, groups[key].size()], 0.8, 1.6)
	print("BENCH done")
	get_tree().quit()


## Hides one part of the scene after another (cumulative) and prints the frame
## rate after each, to show which content costs the most to draw.
func _run_hide() -> void:
	var preset := GameSettings.Preset.HIGH
	GameSettings.apply_preset(preset)
	await _measure("high, everything visible", 4.0, 2.5)
	var bf := get_tree().root.find_child("Battlefield", true, false)
	var by_kind := {}
	for prop: Dictionary in bf.props:
		if is_instance_valid(prop["node"]):
			if not by_kind.has(prop["kind"]):
				by_kind[prop["kind"]] = []
			by_kind[prop["kind"]].append(prop["node"])
	for kind: String in by_kind:
		for n: Node3D in by_kind[kind]:
			n.visible = false
		await _measure("- props: %s (%d)" % [kind, by_kind[kind].size()], 0.6, 1.6)
	for u in get_tree().get_nodes_in_group("units"):
		(u as Node3D).visible = false
	await _measure("- units", 0.6, 1.6)
	for child in bf.get_children():
		if child is Node3D and (child as Node3D).visible and not child is Camera3D and child.get_class() != "Node3D" or child is Terrain:
			if child is WorldEnvironment or child is DirectionalLight3D or child.name == "CameraRig":
				continue
			(child as Node3D).visible = false
			await _measure("- %s" % child.name, 0.6, 1.6)
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	await _measure("- all HUD layers", 0.6, 1.6)
	VFX.process_mode = Node.PROCESS_MODE_DISABLED
	for c in VFX.get_children():
		if c is Node3D:
			(c as Node3D).visible = false
	await _measure("- vfx nodes", 0.6, 1.6)
	print("BENCH done")
	get_tree().quit()


## From High, steps down toward Medium one setting at a time (cumulative).
func _run_high_costs() -> void:
	var env: Environment = GameSettings._env
	var rs := RenderingServer
	GameSettings.apply_preset(GameSettings.Preset.HIGH)
	await _measure("high", 4.0, 2.5)
	var steps := {
		"+ metalfx spatial + taa": func() -> void:
			get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_METALFX_SPATIAL
			get_viewport().use_taa = true,
		"+ bilinear + taa": func() -> void: get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR,
		"+ no taa (fxaa)": func() -> void:
			get_viewport().use_taa = false
			get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA,
		"+ post pass hidden": func() -> void: GameSettings.preset_changed.emit(GameSettings.Preset.LOW),
		"+ hud hidden": func() -> void:
			for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
				(layer as CanvasLayer).visible = false,
		"+ ssr off": func() -> void: env.ssr_enabled = false,
		"+ shadow filter low": func() -> void: rs.directional_soft_shadow_filter_set_quality(rs.SHADOW_QUALITY_SOFT_LOW),
		"+ shadow atlas 2K": func() -> void: rs.directional_shadow_atlas_set_size(2048, true),
		"+ ssao quality low": func() -> void: rs.environment_set_ssao_quality(rs.ENV_SSAO_QUALITY_LOW, true, 0.5, 2, 50.0, 300.0),
		"+ ssao off": func() -> void: env.ssao_enabled = false,
		"+ glow off": func() -> void: env.glow_enabled = false,
		"+ shadows off": func() -> void: GameSettings._sun.shadow_enabled = false,
	}
	for label: String in steps:
		(steps[label] as Callable).call()
		await _measure(label, 2.0, 2.5)
	print("BENCH done")
	get_tree().quit()


func _run() -> void:
	_print_census()
	if "--benchmark-high-costs" in OS.get_cmdline_user_args():
		_run_high_costs()
		return
	if "--benchmark-hide" in OS.get_cmdline_user_args():
		_run_hide()
		return
	if "--benchmark-scripts" in OS.get_cmdline_user_args():
		_run_scripts()
		return
	if "--benchmark-costs" in OS.get_cmdline_user_args():
		_run_costs()
		return
	var start_preset := GameSettings.preset
	var win := get_window()
	print("BENCH adapter=%s window=%s screen_scale=%.1f" % [
		RenderingServer.get_video_adapter_name(), win.size, DisplayServer.screen_get_scale()])
	var presets := [GameSettings.Preset.LOW, GameSettings.Preset.MEDIUM, GameSettings.Preset.HIGH, GameSettings.Preset.ULTRA]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--benchmark-only="): # e.g. --benchmark-only=2 for High
			presets = [int(arg.trim_prefix("--benchmark-only="))]
	for p: int in presets:
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
		var vp_rid := vp.get_viewport_rid()
		print("BENCH timing preset=%s render_cpu_ms=%.1f render_gpu_ms=%.1f process_ms=%.1f physics_ms=%.1f nav_ms=%.1f objects_drawn=%d primitives=%dk" % [
			GameSettings.PRESET_NAMES[p],
			RenderingServer.viewport_get_measured_render_time_cpu(vp_rid) + RenderingServer.get_frame_setup_time_cpu(),
			RenderingServer.viewport_get_measured_render_time_gpu(vp_rid),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000])
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
