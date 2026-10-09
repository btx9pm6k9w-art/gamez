class_name SelectionManager
extends Node
## Mouse and keyboard command layer: click and box selection, double-click
## and Ctrl+click select-by-type, control groups, move / attack / attack-move /
## stop / hold / patrol orders with Shift queueing, formation spreading, unit
## voice acknowledgements, "under attack" alerts with Space to jump, and the
## commander's Precision Strike and Airstrike.

const UnitVoice := preload("res://scripts/audio/unit_voice.gd")

signal selection_changed(units: Array[Unit])
signal strike_ready_changed(ready: bool)
signal alert_raised(pos: Vector3)

const DRAG_THRESHOLD := 6.0
const STRIKE_COOLDOWN := 25.0
const STRIKE_DELAY := 3.0
const AIRSTRIKE_COOLDOWN := 40.0

var battlefield: Battlefield
var rig: RTSCamera
var selected: Array[Unit] = []
var groups := {}
var drag_start := Vector2.ZERO
var dragging := false
var attack_move_armed := false
var patrol_armed := false
## Sidebar "Set rally point": the next left click places it.
var rally_armed := false
## Economy node when the mission has one (scripts/game/economy.gd).
var economy: Node
## Last place our units took fire, for Space and the minimap ping.
var alert_pos := Vector3.INF
var alert_time := -100.0
var strike_armed := false
var strike_cooldown := 0.0
var airstrike_armed := false
var airstrike_cooldown := 0.0
var hovered: Unit

var _last_click_time := 0.0
var _last_group_key := -1
var _last_group_time := 0.0
var _last_alert_raise := -100.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if strike_armed:
					_fire_strike(mb.position)
					return
				if airstrike_armed:
					_call_airstrike(mb.position)
					return
				if rally_armed:
					rally_armed = false
					var rp := ground_point(mb.position)
					if rp != Vector3.INF and economy != null:
						if battlefield.terrain.is_land(rp):
							economy.set_rally("infantry", rp)
							economy.set_rally("vehicle", rp)
						else:
							economy.set_rally("naval", rp)
						Audio.play_ui("ui_confirm")
					return
				if attack_move_armed or patrol_armed:
					var p := ground_point(mb.position)
					if p != Vector3.INF:
						if patrol_armed:
							_patrol_to(p)
						else:
							order_to_point(p, true, mb.shift_pressed)
					# Shift keeps the order armed so several points can be queued.
					if not mb.shift_pressed:
						attack_move_armed = false
						patrol_armed = false
					return
				drag_start = mb.position
				dragging = true
			elif dragging:
				dragging = false
				if drag_start.distance_to(mb.position) > DRAG_THRESHOLD:
					_box_select(Rect2(drag_start, mb.position - drag_start).abs(), mb.shift_pressed)
				else:
					_click_select(mb.position, mb.shift_pressed, mb.double_click or mb.ctrl_pressed or mb.meta_pressed)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if attack_move_armed or patrol_armed or strike_armed or airstrike_armed or rally_armed:
				# Right click cancels an armed order, as in every classic RTS.
				_disarm()
				return
			var u := _unit_at(mb.position)
			var own := _only_own(selected)
			if u != null and u.team != Battlefield.COALITION:
				for s in own:
					s.order_attack(u, mb.shift_pressed)
				VFX.ground_ring(u.global_position, Color(3, 0.4, 0.3, 1), u.def["radius"] * 1.6, 0.5)
				Audio.play_ui("ui_confirm")
				if not own.is_empty():
					UnitVoice.ack("attack", own[0].def["model"])
			else:
				var p := ground_point(mb.position)
				if p != Vector3.INF:
					order_to_point(p, false, mb.shift_pressed)
	elif event is InputEventMouseMotion:
		hovered = _unit_at((event as InputEventMouseMotion).position)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode >= KEY_0 and k.keycode <= KEY_9:
			_handle_group_key(k.keycode - KEY_0, k.ctrl_pressed or k.meta_pressed)
			return
		if event.is_action_pressed("order_stop"):
			for s in _only_own(selected):
				s.order_stop()
		elif event.is_action_pressed("order_hold"):
			for s in _only_own(selected):
				s.order_hold()
			if not _only_own(selected).is_empty():
				Audio.play_ui("ui_confirm")
		elif event.is_action_pressed("order_attack_move"):
			_disarm()
			attack_move_armed = not _only_own(selected).is_empty()
		elif event.is_action_pressed("order_patrol"):
			_disarm()
			patrol_armed = not _only_own(selected).is_empty()
		elif event.is_action_pressed("jump_to_alert"):
			if alert_pos != Vector3.INF:
				rig.focus_on(alert_pos)
		elif event.is_action_pressed("toggle_voices"):
			UnitVoice.toggle()
		elif event.is_action_pressed("ability_strike"):
			strike_armed = strike_cooldown <= 0.0
			airstrike_armed = false
			if not strike_armed:
				Audio.play_ui("ui_error")
		elif event.is_action_pressed("ability_airstrike"):
			airstrike_armed = airstrike_cooldown <= 0.0
			strike_armed = false
			if not airstrike_armed:
				Audio.play_ui("ui_error")
		elif event.is_action_pressed("vfx_showcase"):
			var f := rig.get_focus()
			f.y = battlefield.terrain.height_at(f)
			Airstrike.launch(battlefield, f, rig.camera.global_basis.x)
		elif event.is_action_pressed("select_all_army"):
			_set_selection(_own_units())
		elif event.is_action_pressed("cycle_time_of_day"):
			battlefield.cycle_time_of_day()
		elif event.is_action_pressed("cancel"):
			_disarm()


func _disarm() -> void:
	rally_armed = false
	attack_move_armed = false
	patrol_armed = false
	strike_armed = false
	airstrike_armed = false


func _process(delta: float) -> void:
	if strike_cooldown > 0.0:
		strike_cooldown = maxf(strike_cooldown - delta, 0.0)
		if strike_cooldown == 0.0:
			strike_ready_changed.emit(true)
	airstrike_cooldown = maxf(airstrike_cooldown - delta, 0.0)
	_check_alerts()
	# Drop dead units from the selection and groups.
	# Freed units cannot be passed to a typed parameter, so the lambda is untyped.
	var alive := selected.filter(func(u) -> bool: return is_instance_valid(u) and u.is_alive())
	if alive.size() != selected.size():
		var typed: Array[Unit] = []
		typed.assign(alive)
		selected = typed
		selection_changed.emit(selected)


## Raise an "under attack" alert when our units take fire somewhere the
## player is not looking, at most every 8 seconds (EVA-style spacing).
func _check_alerts() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var newest: Unit = null
	for u in _own_units():
		if now - u.last_hit_time < 0.5 and (newest == null or u.last_hit_time > newest.last_hit_time):
			newest = u
	if newest == null:
		return
	if now - alert_time > 1.0 or alert_pos.distance_to(newest.global_position) > 25.0:
		alert_pos = newest.global_position
		alert_time = now
	var off_screen := not _on_screen(newest) or not get_viewport().get_visible_rect().has_point(_screen_pos(newest))
	if off_screen and now - _last_alert_raise > 8.0:
		_last_alert_raise = now
		alert_raised.emit(alert_pos)
		UnitVoice.alert("under_attack")


func _own_units() -> Array[Unit]:
	var out: Array[Unit] = []
	for u: Unit in battlefield.units[Battlefield.COALITION]:
		if is_instance_valid(u) and u.is_alive() and not u.is_air:
			out.append(u)
	return out


func _screen_pos(u: Unit) -> Vector2:
	return rig.camera.unproject_position(u.aim_point())


func _on_screen(u: Unit) -> bool:
	return not rig.camera.is_position_behind(u.global_position)


func _unit_at(screen: Vector2) -> Unit:
	var best: Unit = null
	var best_d := 26.0
	for t in 2:
		for u: Unit in battlefield.units[t]:
			if not is_instance_valid(u) or not u.is_alive() or not _on_screen(u):
				continue
			var d := _screen_pos(u).distance_to(screen)
			var pick := 14.0 + float(u.def["radius"]) * 600.0 / maxf(rig.camera.global_position.distance_to(u.global_position), 1.0)
			if d < minf(pick, best_d):
				best_d = d
				best = u
	return best


func _set_selection(units: Array[Unit]) -> void:
	for u in selected:
		if is_instance_valid(u):
			u.selected = false
	selected = units
	for u in selected:
		u.selected = true
	if not selected.is_empty():
		Audio.play_ui("ui_select")
		if selected[0].team == Battlefield.COALITION:
			UnitVoice.ack("select", selected[0].def["model"])
	selection_changed.emit(selected)


func _click_select(pos: Vector2, additive: bool, double: bool) -> void:
	var u := _unit_at(pos)
	if u == null:
		if not additive:
			var none: Array[Unit] = []
			_set_selection(none)
		return
	if u.team != Battlefield.COALITION:
		var enemy: Array[Unit] = [u]
		_set_selection(enemy) # inspect an enemy
		return
	if double:
		var same: Array[Unit] = []
		var screen := get_viewport().get_visible_rect()
		for o in _own_units():
			if o.unit_id == u.unit_id and _on_screen(o) and screen.has_point(_screen_pos(o)):
				same.append(o)
		_set_selection(same)
		return
	var list: Array[Unit] = []
	if additive:
		list.assign(selected)
	if additive and list.has(u):
		list.erase(u)
	else:
		list.append(u)
	_set_selection(_only_own(list))


func _only_own(list: Array[Unit]) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in list:
		if is_instance_valid(u) and u.team == Battlefield.COALITION:
			out.append(u)
	return out


func _box_select(rect: Rect2, additive: bool) -> void:
	var list: Array[Unit] = []
	if additive:
		list = _only_own(selected)
	for u in _own_units():
		if _on_screen(u) and rect.has_point(_screen_pos(u)) and not list.has(u):
			list.append(u)
	_set_selection(list)


func ground_point(screen: Vector2) -> Vector3:
	var from := rig.camera.project_ray_origin(screen)
	var dir := rig.camera.project_ray_normal(screen)
	var space := battlefield.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 2000.0, 1)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		# Over the sea: intersect the water plane instead.
		if absf(dir.y) < 0.001:
			return Vector3.INF
		var t := (Terrain.WATER_LEVEL - from.y) / dir.y
		return from + dir * t if t > 0.0 else Vector3.INF
	return hit["position"]


## Move (or attack-move) the selection to a world point in a loose
## formation. With queue (Shift) the order is added after the current one.
func order_to_point(p: Vector3, attack_move: bool, queue := false) -> void:
	var own := _only_own(selected)
	if own.is_empty():
		return
	VFX.ground_ring(p, Color(3, 1.2, 0.3, 1) if attack_move else Color(0.5, 3, 1.2, 1), 1.2, 0.6)
	Audio.play_ui("ui_confirm")
	UnitVoice.ack("attack" if attack_move else "move", own[0].def["model"])
	var slots := _formation(own, p)
	for i in own.size():
		own[i].order_move(slots[i], attack_move, queue)


func _patrol_to(p: Vector3) -> void:
	var own := _only_own(selected)
	if own.is_empty():
		return
	VFX.ground_ring(p, Color(0.6, 1.2, 3, 1), 1.2, 0.6)
	Audio.play_ui("ui_confirm")
	UnitVoice.ack("move", own[0].def["model"])
	var slots := _formation(own, p)
	for i in own.size():
		own[i].order_patrol(slots[i])


## Spread a group in a loose grid around p, facing the move, heavy units in
## front and infantry behind. Sorts own in place to match the returned slots.
func _formation(own: Array[Unit], p: Vector3) -> Array[Vector3]:
	var center := Vector3.ZERO
	for u in own:
		center += u.global_position
	center /= own.size()
	var dir := (p - center)
	dir.y = 0
	dir = dir.normalized() if dir.length() > 0.5 else Vector3.FORWARD
	var right := dir.cross(Vector3.UP).normalized()
	var cols := ceili(sqrt(own.size()))
	var spacing := 3.2
	own.sort_custom(func(a: Unit, b: Unit) -> bool: return float(a.def["radius"]) > float(b.def["radius"]))
	var out: Array[Vector3] = []
	for i in own.size():
		var row := i / cols
		var col := i % cols
		var offset := right * (col - (cols - 1) * 0.5) * spacing - dir * row * spacing
		out.append(battlefield.terrain.clamp_to_map(p + offset))
	return out


func _handle_group_key(n: int, assign: bool) -> void:
	if assign:
		groups[n] = _only_own(selected)
		return
	if not groups.has(n):
		return
	var g: Array[Unit] = []
	for u: Unit in groups[n]:
		if is_instance_valid(u) and u.is_alive():
			g.append(u)
	_set_selection(g)
	var now := Time.get_ticks_msec() / 1000.0
	if _last_group_key == n and now - _last_group_time < 0.35 and not g.is_empty():
		rig.focus_on(g[0].global_position)
	_last_group_key = n
	_last_group_time = now


## Commander ability: hypersonic precision strike with a 3 s warning.
func _fire_strike(screen: Vector2) -> void:
	strike_armed = false
	var p := ground_point(screen)
	if p == Vector3.INF:
		return
	strike_cooldown = STRIKE_COOLDOWN
	strike_ready_changed.emit(false)
	var warn := VFX.ground_ring(p, Color(4, 0.3, 0.2, 1), 9.0, STRIKE_DELAY)
	warn.scale = Vector3.ONE * 18.0
	var missile := Node3D.new()
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.25
	cap.height = 3.0
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.8, 0.8, 0.82)
	m.metallic = 0.8
	m.roughness = 0.3
	cap.material = m
	body.mesh = cap
	missile.add_child(body)
	var trail := VFX.make_trail(1.4)
	trail.position = Vector3.DOWN * 1.6
	missile.add_child(trail)
	battlefield.add_child(missile)
	var start := p + Vector3(-60, 160, 40)
	missile.global_position = start
	missile.look_at(p, Vector3.FORWARD)
	missile.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
	trail.emitting = true
	var tw := battlefield.create_tween()
	Audio.play_ui("alert")
	tw.tween_interval(STRIKE_DELAY - 0.9)
	tw.tween_callback(func() -> void: Audio.play_3d("missile_incoming", p, 6.0, 1.0, 2))
	tw.tween_property(missile, "global_position", p, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		battlefield.blast(p, 400.0, 10.0, 4.5, Battlefield.COALITION, 6.0)
		VFX.burning(p, 12.0, 1.5)
		trail.emitting = false
		missile.queue_free())


## Commander ability: two jets bomb a line through the clicked point, flying
## across the screen so the whole run is in view.
func _call_airstrike(screen: Vector2) -> void:
	airstrike_armed = false
	var p := ground_point(screen)
	if p == Vector3.INF:
		return
	airstrike_cooldown = AIRSTRIKE_COOLDOWN
	Airstrike.launch(battlefield, p, rig.camera.global_basis.x)
