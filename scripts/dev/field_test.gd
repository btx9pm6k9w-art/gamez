extends Node
## Developer field test: scripted checks of line of fire, movement smoothness
## and pathfinding, printed as FIELD lines. Starts Mission 1 without the menu.
##   godot --path . -- --field-test [--field-test-out=/some/folder]

var main: Node
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--field-test-out="):
			out_dir = arg.trim_prefix("--field-test-out=")
	_run.call_deferred()


func _units(team: int, id: String) -> Array[Unit]:
	var out: Array[Unit] = []
	for u: Unit in main.battlefield.units[team]:
		if u.unit_id == id and u.is_alive():
			out.append(u)
	return out


func _place(u: Unit, p: Vector3) -> void:
	p.y = main.battlefield.terrain.height_at(p)
	u.global_position = p
	u.order_stop()


## Orders `u` to `target` and samples where its model is drawn every frame.
func _smoothness(label: String, u: Unit, target: Vector3, cap: int) -> void:
	Engine.max_fps = cap
	u.order_move(target)
	await get_tree().create_timer(1.2).timeout # let it get up to speed
	var steps: PackedFloat32Array = []
	var backward := 0
	var last := u.model.global_position
	var heading := (target - u.global_position).normalized()
	heading.y = 0.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500:
		# Sample what is about to be drawn: process_frame fires before the units'
		# own _process has interpolated their models for this frame.
		await RenderingServer.frame_pre_draw
		var d := u.model.global_position - last
		d.y = 0.0
		last = u.model.global_position
		steps.append(d.length() / maxf(get_process_delta_time(), 0.0001)) # drawn speed this frame
		if d.dot(heading) < -0.001:
			backward += 1
	var mean := 0.0
	for s in steps:
		mean += s
	mean /= maxf(steps.size(), 1)
	var dev := 0.0
	var worst := 0.0
	for s in steps:
		dev += (s - mean) * (s - mean)
		worst = maxf(worst, absf(s - mean))
	dev = sqrt(dev / maxf(steps.size(), 1))
	print("FIELD smooth %-22s cap=%d frames=%d drawn_speed mean=%.2f m/s stddev=%.2f worst_dev=%.2f backward_frames=%d (unit speed %.1f)" % [
		label, cap, steps.size(), mean, dev, worst, backward, float(u.def["speed"])])
	u.order_stop()


func _path(label: String, from: Vector3, to: Vector3, layers: int) -> void:
	var map: RID = (main.battlefield as Battlefield).get_world_3d().navigation_map
	from.y = main.battlefield.terrain.height_at(from)
	to.y = main.battlefield.terrain.height_at(to)
	var path := NavigationServer3D.map_get_path(map, from, to, true, layers)
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	var miss := -1.0 if path.is_empty() else Vector2(path[path.size() - 1].x - to.x, path[path.size() - 1].z - to.z).length()
	print("FIELD path %-28s points=%d length=%.0f m straight=%.0f m ends %.1f m from target" % [
		label, path.size(), length, from.distance_to(to), miss])


func _fog_checks() -> void:
	var bf: Battlefield = main.battlefield
	var vision: Node = bf.vision
	if vision == null:
		print("FIELD fog: no vision node")
		return
	vision.update_now()
	var hidden := 0
	var shown := 0
	var wrong := 0
	for u: Unit in bf.units[Battlefield.IRAN]:
		if not u.is_alive():
			continue
		var seen: bool = vision.is_visible_at(u.global_position)
		if u.visible != seen:
			wrong += 1
		if u.visible:
			shown += 1
		else:
			hidden += 1
	var own_dark := 0
	for u: Unit in bf.units[Battlefield.COALITION]:
		if u.is_alive() and not vision.is_visible_at(u.global_position):
			own_dark += 1
	print("FIELD fog enemies shown=%d hidden=%d mismatched=%d; own units standing in fog=%d (expect 0)" % [shown, hidden, wrong, own_dark])
	# A hidden enemy must not be auto-targeted by a coalition unit.
	var seeker: Unit = bf.units[Battlefield.COALITION][0]
	var found := bf.find_target(seeker, 400.0)
	print("FIELD fog find_target with 400 m radius returns %s" % ("nothing" if found == null else "%s, visible=%s" % [found.unit_id, found.visible]))
	# Cost of one fog update including the texture upload.
	var t0 := Time.get_ticks_usec()
	for i in 20:
		vision._last_pixels = PackedByteArray() # force the upload path
		vision.update_now()
	var per_update := (Time.get_ticks_usec() - t0) / 20000.0
	print("FIELD fog update_now with upload: %.2f ms each on the main thread (runs %.0f times a second)" % [per_update, 1.0 / float(vision.TICK)])
	await get_tree().process_frame


## Speeds time up and logs what each AI group is doing until two waves have
## been sent and had time to arrive.
func _watch_waves() -> void:
	var ai: SimpleAI = main.ai
	Engine.time_scale = 5.0
	var last_pos := {}
	var game_t := 0.0
	var seen_waves := 0
	var after_second := 0.0
	while game_t < 260.0 and after_second < 60.0:
		await get_tree().create_timer(10.0).timeout # scaled: 10 game seconds
		game_t += 10.0
		if ai.waves_sent > seen_waves:
			seen_waves = ai.waves_sent
			print("FIELD ai t=%.0f wave %d sent from %s" % [game_t, seen_waves, ai.last_wave_from])
		if seen_waves >= 2:
			after_second += 10.0
		for g: Dictionary in ai.groups:
			var alive: Array[Unit] = []
			for u in g["units"]:
				if is_instance_valid(u) and u.is_alive():
					alive.append(u)
			if alive.is_empty():
				continue
			var centre := Vector3.ZERO
			var still := 0
			for u in alive:
				centre += u.global_position
				var key := u.get_instance_id()
				if last_pos.has(key) and (last_pos[key] as Vector3).distance_to(u.global_position) < 0.5:
					still += 1
				last_pos[key] = u.global_position
			centre /= alive.size()
			var spread := 0.0
			for u in alive:
				spread = maxf(spread, u.global_position.distance_to(centre))
			print("FIELD ai t=%.0f %-7s phase=%-8s alive=%d/%d at (%.0f,%.0f) spread=%.0f m, to stage %.0f m, to target %.0f m, not moving=%d" % [
				game_t, g["role"], g["phase"], alive.size(), g["start"], centre.x, centre.z, spread,
				centre.distance_to(g["stage"]), centre.distance_to(g["target"]), still])
	Engine.time_scale = 1.0


func _run() -> void:
	main.rig.edge_pan = false
	var bf: Battlefield = main.battlefield
	await get_tree().create_timer(4.0).timeout # navmesh bake and mission start

	# --- Pathfinding on both navigation layers.
	var start := Vector3(64, 0, 160)
	var oil := Vector3(Terrain.OIL_FIELD.x, 0, Terrain.OIL_FIELD.y)
	for row in [["vehicle: base to village", start, Vector3(100, 0, 100), Battlefield.NAV_LAYER_VEHICLE],
			["vehicle: base to oil field", start, oil, Battlefield.NAV_LAYER_VEHICLE],
			["vehicle: village to oil", Vector3(100, 0, 100), oil, Battlefield.NAV_LAYER_VEHICLE],
			["infantry: base to village", start, Vector3(100, 0, 100), Battlefield.NAV_LAYER_INFANTRY],
			["infantry: base to oil field", start, oil, Battlefield.NAV_LAYER_INFANTRY],
			["vehicle: wave entry east", Vector3(184, 0, 118), start, Battlefield.NAV_LAYER_VEHICLE],
			["vehicle: wave entry north", Vector3(112, 0, 8), start, Battlefield.NAV_LAYER_VEHICLE]]:
		_path(row[0], row[1], row[2], row[3])

	# --- Line of fire across a village house.
	var house: Node3D
	for prop: Dictionary in bf.props:
		if prop["kind"] == "building" and prop["alive"] and Vector2(prop["node"].position.x - 100.0, prop["node"].position.z - 100.0).length() < 20.0:
			house = prop["node"]
			break
	var rangers := _units(Battlefield.COALITION, "ranger")
	var tanks := _units(Battlefield.COALITION, "abrams")
	var foes := _units(Battlefield.IRAN, "irgc")
	if house and not rangers.is_empty() and not foes.is_empty() and not tanks.is_empty():
		# Clear the village so only the two test units matter.
		for u: Unit in bf.units[Battlefield.IRAN].duplicate():
			if u != foes[0] and u.global_position.distance_to(house.position) < 45.0:
				_place(u, Vector3(150, 0, 30))
		var side := Vector3(1, 0, 0).rotated(Vector3.UP, house.rotation.y)
		var ranger := rangers[0]
		var foe := foes[0]
		_place(ranger, house.position - side * 9.0)
		_place(foe, house.position + side * 9.0)
		foe.order_hold()
		await get_tree().create_timer(0.6).timeout
		print("FIELD los ranger behind house: has_line_of_fire=%s (expect false), distance %.1f m, range %.1f" % [
			ranger.has_line_of_fire(foe), ranger.global_position.distance_to(foe.global_position), float(ranger.def["range"])])
		var hp0 := foe.hp
		var p0 := ranger.global_position
		ranger.order_attack(foe)
		var first_hit := -1.0
		var moved_at_hit := 0.0
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 7000 and is_instance_valid(foe) and foe.is_alive():
			await get_tree().process_frame
			if first_hit < 0.0 and foe.hp < hp0:
				first_hit = (Time.get_ticks_msec() - t0) / 1000.0
				moved_at_hit = ranger.global_position.distance_to(p0)
		print("FIELD los ranger attack: first damage after %.1f s, having walked %.1f m; ranger walked %.1f m in total" % [
			first_hit, moved_at_hit, ranger.global_position.distance_to(p0)])

		# Tank shell against the wall: a fresh enemy behind the same house.
		if foes.size() > 1 and is_instance_valid(house):
			var foe2 := foes[1]
			var tank := tanks[0]
			_place(ranger, Vector3(64, 0, 160)) # out of the way, so only the tank can hurt the enemy
			_place(tank, house.position - side * 16.0)
			_place(foe2, house.position + side * 7.0)
			foe2.order_hold()
			var house_hp := -1.0
			for prop: Dictionary in bf.props:
				if prop["node"] == house:
					house_hp = prop["hp"]
			var foe_hp := foe2.hp
			await get_tree().create_timer(0.6).timeout
			print("FIELD los tank behind house: has_line_of_fire=%s (expect false)" % tank.has_line_of_fire(foe2))
			tank.order_hold()
			tank.target = foe2
			await get_tree().create_timer(5.0).timeout
			var house_now := -1.0
			for prop: Dictionary in bf.props:
				if prop["node"] == house:
					house_now = prop["hp"]
			print("FIELD los tank hold-fire 5 s: house hp %.0f -> %.0f, enemy hp %.0f -> %.0f" % [
				house_hp, house_now, foe_hp, foe2.hp if is_instance_valid(foe2) else 0.0])
	else:
		print("FIELD los skipped: house=%s rangers=%d foes=%d" % [house != null, rangers.size(), foes.size()])

	# --- Movement smoothness, capped and uncapped.
	GameSettings.fps_cap = 0
	tanks = _units(Battlefield.COALITION, "abrams")
	if tanks.size() > 1:
		var tank2 := tanks[1]
		_place(tank2, Vector3(70, 0, 150))
		# Both legs head the same way so a U-turn does not pollute the numbers.
		await _smoothness("tank", tank2, Vector3(95, 0, 146), 60)
		await _smoothness("tank", tank2, Vector3(125, 0, 141), 0)
	var soldiers := _units(Battlefield.COALITION, "ranger")
	if soldiers.size() > 1:
		_place(soldiers[1], Vector3(70, 0, 156))
		await _smoothness("ranger", soldiers[1], Vector3(84, 0, 154), 60)
		await _smoothness("ranger", soldiers[1], Vector3(100, 0, 152), 0)
	var boats := _units(Battlefield.COALITION, "patrol_boat")
	if not boats.is_empty():
		var boat := boats[0]
		var leg := Vector3(-8, 0, -40)
		await _smoothness("patrol boat", boat, boat.global_position + leg, 60)
		await _smoothness("patrol boat", boat, boat.global_position + leg, 0)

	Engine.max_fps = 0
	await _fog_checks()

	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
		for view in [["coast", Vector3(60, 0, 150)], ["hills", Vector3(140, 0, 60)], ["creek", Vector3(60, 0, 112)]]:
			main.rig.focus_on(view[1])
			await get_tree().create_timer(1.2).timeout
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			if get_viewport().use_hdr_2d:
				img.linear_to_srgb()
			img.save_jpg(out_dir.path_join("shading_%s.jpg" % view[0]), 0.92)
	await _watch_waves()
	print("FIELD done")
	get_tree().quit()
