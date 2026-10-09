extends Node3D
## Unit showcase: every unit on a slow turntable under neutral daylight, so the
## models can be judged without playing. Open with F8 in game, or
##   godot --path . -- --showcase [--showcase-shot=/some/file.png]

const SPACING := 11.0
const PER_ROW := 5

var _turntables: Array[Node3D] = []
var _shot_path := ""
var _time := 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--showcase-shot="):
			_shot_path = arg.trim_prefix("--showcase-shot=")

	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.42, 0.7)
	sky_mat.sky_horizon_color = Color(0.72, 0.78, 0.84)
	sky_mat.ground_bottom_color = Color(0.3, 0.27, 0.22)
	sky_mat.ground_horizon_color = Color(0.72, 0.74, 0.76)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.62, 0.56, 0.46)
	floor_mat.roughness = 0.95
	floor_mesh.material_override = floor_mat
	add_child(floor_mesh)

	var ids := UnitDefs.DEFS.keys()
	var rows := ceili(ids.size() / float(PER_ROW))
	for i in ids.size():
		var def: Dictionary = UnitDefs.DEFS[ids[i]]
		var row := i / PER_ROW
		var pos := Vector3((i % PER_ROW - (PER_ROW - 1) * 0.5) * SPACING, 0, (row - (rows - 1) * 0.5) * SPACING)
		var table := Node3D.new()
		table.position = pos
		add_child(table)
		var model := UnitModels.build(def["model"], def["faction"], ids[i])
		if def.get("air", false) or def["model"] == "drone":
			model.position.y = 2.0
		table.add_child(model)
		UnitModels.set_state(model, "move" if i % 2 == 0 else "shoot")
		_turntables.append(table)

		var pad := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 4.6
		disc.bottom_radius = 4.6
		disc.height = 0.08
		pad.mesh = disc
		var pad_mat := StandardMaterial3D.new()
		pad_mat.albedo_color = Color(0.2, 0.45, 0.6) if def["faction"] == "coalition" else Color(0.6, 0.25, 0.2)
		pad.material_override = pad_mat
		pad.position = pos + Vector3.UP * 0.04
		add_child(pad)

		var nose := MeshInstance3D.new() # marks the unit's front (-Z)
		var prism := PrismMesh.new()
		prism.size = Vector3(1.0, 1.0, 0.05)
		nose.mesh = prism
		nose.rotation_degrees = Vector3(-90, 0, 0)
		nose.position = Vector3(0, 0.1, -4.0)
		table.add_child(nose)
		var ruler := MeshInstance3D.new() # 2 m tall reference post
		var post := BoxMesh.new()
		post.size = Vector3(0.1, 2.0, 0.1)
		ruler.mesh = post
		ruler.position = Vector3(3.6, 1.0, 0)
		table.add_child(ruler)

		var label := Label3D.new()
		label.text = def["display"]
		label.font_size = 96
		label.pixel_size = 0.008
		label.outline_size = 24
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = pos + Vector3(0, 0.3, 5.4)
		add_child(label)

	var cam := Camera3D.new()
	cam.fov = 38.0
	cam.position = Vector3(0, 34.0 + rows * 6.0, 30.0 + rows * 12.0)
	add_child(cam)
	cam.look_at(Vector3(0, 1.0, 1.5))
	cam.make_current()


func _process(delta: float) -> void:
	_time += delta
	for t in _turntables:
		t.rotation.y = -0.6 + _time * (0.0 if _shot_path != "" else 0.5)
	if _shot_path != "" and _time > 2.5 and _shot_path.get_extension() == "":
		# A folder: save one close-up per unit instead of the overview.
		var dir := _shot_path
		_shot_path = ""
		set_process(false)
		DirAccess.make_dir_recursive_absolute(dir)
		var cam := get_viewport().get_camera_3d()
		cam.fov = 30.0
		for i in _turntables.size():
			var p := _turntables[i].position
			cam.position = p + Vector3(9, 8, 12)
			cam.look_at(p + Vector3.UP * 1.2)
			await get_tree().create_timer(0.4).timeout
			await RenderingServer.frame_post_draw
			var shot := get_viewport().get_texture().get_image()
			shot.convert(Image.FORMAT_RGBA8)
			if get_viewport().use_hdr_2d:
				shot.linear_to_srgb()
			shot.resize(shot.get_width() / 3, shot.get_height() / 3)
			shot.save_jpg(dir.path_join("unit_%02d.jpg" % i), 0.85)
		get_tree().quit()
		return
	if _shot_path != "" and _time > 2.5:
		var path := _shot_path
		_shot_path = ""
		set_process(false)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		if get_viewport().use_hdr_2d:
			img.linear_to_srgb()
		img.save_png(path)
		get_tree().quit()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and (k.physical_keycode == KEY_F8 or k.physical_keycode == KEY_ESCAPE):
		get_tree().change_scene_to_file("res://scenes/main.tscn")
