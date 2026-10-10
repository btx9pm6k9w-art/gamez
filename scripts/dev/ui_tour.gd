extends Node
## Developer UI tour: walks the main menu, briefing and in-game HUD states and
## saves a native-resolution screenshot of each, then quits.
##   godot --path . -- --ui-tour=/some/folder

var out_dir := "user://ui_tour"
var main: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ui-tour="):
			out_dir = arg.trim_prefix("--ui-tour=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameSettings.apply_preset(GameSettings.Preset.HIGH)
	_run.call_deferred()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if get_viewport().use_hdr_2d:
		img.linear_to_srgb()
	img.save_jpg(out_dir.path_join(file + ".jpg"), 0.92)
	print("TOUR saved %s %dx%d fps=%d" % [file, img.get_width(), img.get_height(), Engine.get_frames_per_second()])


func _overlay_child(script_file: String) -> Node:
	for c in main._overlay_layer.get_children():
		var sc := c.get_script() as Script
		if sc and sc.resource_path.get_file() == script_file:
			return c
	return null


func _run() -> void:
	main.rig.edge_pan = false
	await _wait(3.0)
	await _shot("a_main_menu")

	var menu := _overlay_child("main_menu.gd")
	menu._leave(menu.campaign)
	await _wait(3.0)
	await _shot("b_briefing")

	var briefing := _overlay_child("briefing.gd")
	briefing._begin()
	await _wait(6.0)
	var own: Array[Unit] = []
	for u: Unit in main.battlefield.units[Battlefield.COALITION]:
		if not u.is_air:
			own.append(u)
	var same: Array[Unit] = []
	for u in own:
		if u.unit_id == own[0].unit_id and same.size() < 4:
			same.append(u)
	main.selection.select_units(same)
	await _wait(1.0)
	await _shot("c_units_selected")

	main.selection.select_units(own)
	await _wait(1.0)
	await _shot("d_mixed_selection")

	main.selection.select_units([] as Array[Unit])
	main.economy.build("ranger")
	main.economy.build("abrams")
	await _wait(2.0)
	await _shot("e_build_queued")

	get_viewport().warp_mouse(get_viewport().get_visible_rect().size * Vector2(0.55, 0.5))
	main.selection.use_command("strike")
	await _wait(1.0)
	await _shot("f_strike_armed")
	main.selection._disarm()

	main.battlefield.set_time_of_day(Battlefield.TimeOfDay.GOLDEN_HOUR)
	await _wait(2.5)
	await _shot("g_golden_hour")
	print("TOUR done")
	get_tree().quit()
