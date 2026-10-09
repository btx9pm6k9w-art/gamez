class_name SelectionManager
extends Node
## Mouse and keyboard command layer: click and box selection, double-click
## select-by-type, control groups, move / attack / attack-move / stop orders,
## formation spreading and the commander's Precision Strike.

signal selection_changed(units: Array[Unit])
signal strike_ready_changed(ready: bool)

const DRAG_THRESHOLD := 6.0
const STRIKE_COOLDOWN := 25.0
const STRIKE_DELAY := 3.0

var battlefield: Battlefield
var rig: RTSCamera
var selected: Array[Unit] = []
var groups := {}
var drag_start := Vector2.ZERO
var dragging := false
var attack_move_armed := false
var strike_armed := false
var strike_cooldown := 0.0
var hovered: Unit

var _last_click_time := 0.0
var _last_group_key := -1
var _last_group_time := 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if strike_armed:
					_fire_strike(mb.position)
					return
				if attack_move_armed:
					_issue_ground_order(mb.position, true)
					attack_move_armed = false
					return
				drag_start = mb.position
				dragging = true
			elif dragging:
				dragging = false
				if drag_start.distance_to(mb.position) > DRAG_THRESHOLD:
					_box_select(Rect2(drag_start, mb.position - drag_start).abs(), mb.shift_pressed)
				else:
					_click_select(mb.position, mb.shift_pressed, mb.double_click)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			attack_move_armed = false
			strike_armed = false
			var u := _unit_at(mb.position)
			if u != null and u.team != Battlefield.COALITION:
				for s in selected:
					s.order_attack(u)
				VFX.ground_ring(u.global_position, Color(3, 0.4, 0.3, 1), u.def["radius"] * 1.6, 0.5)
				Audio.play_ui("ui_confirm")
			else:
				_issue_ground_order(mb.position, false)
	elif event is InputEventMouseMotion:
		hovered = _unit_at((event as InputEventMouseMotion).position)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode >= KEY_0 and k.keycode <= KEY_9:
			_handle_group_key(k.keycode - KEY_0, k.ctrl_pressed or k.meta_pressed)
			return
		if event.is_action_pressed("order_stop"):
			for s in selected:
				s.order_stop()
		elif event.is_action_pressed("order_attack_move"):
			attack_move_armed = not selected.is_empty()
		elif event.is_action_pressed("ability_strike"):
			strike_armed = strike_cooldown <= 0.0
			if not strike_armed:
				Audio.play_ui("ui_error")
		elif event.is_action_pressed("select_all_army"):
			_set_selection(_own_units())
		elif event.is_action_pressed("cycle_time_of_day"):
			battlefield.cycle_time_of_day()
		elif event.is_action_pressed("cancel"):
			attack_move_armed = false
			strike_armed = false


func _process(delta: float) -> void:
	if strike_cooldown > 0.0:
		strike_cooldown = maxf(strike_cooldown - delta, 0.0)
		if strike_cooldown == 0.0:
			strike_ready_changed.emit(true)
	# Drop dead units from the selection and groups.
	var alive := selected.filter(func(u: Unit) -> bool: return is_instance_valid(u) and u.is_alive())
	if alive.size() != selected.size():
		var typed: Array[Unit] = []
		typed.assign(alive)
		selected = typed
		selection_changed.emit(selected)


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


func _issue_ground_order(screen: Vector2, attack_move: bool) -> void:
	var own := _only_own(selected)
	if own.is_empty():
		return
	var p := ground_point(screen)
	if p == Vector3.INF:
		return
	VFX.ground_ring(p, Color(3, 1.2, 0.3, 1) if attack_move else Color(0.5, 3, 1.2, 1), 1.2, 0.6)
	Audio.play_ui("ui_confirm")
	# Spread the group in a loose grid around the click, facing the move.
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
	# Heavy units in front, infantry behind.
	own.sort_custom(func(a: Unit, b: Unit) -> bool: return float(a.def["radius"]) > float(b.def["radius"]))
	for i in own.size():
		var row := i / cols
		var col := i % cols
		var offset := right * (col - (cols - 1) * 0.5) * spacing - dir * row * spacing
		var dest := battlefield.terrain.clamp_to_map(p + offset)
		own[i].order_move(dest, attack_move)


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
	var trail := VFX.make_trail()
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
