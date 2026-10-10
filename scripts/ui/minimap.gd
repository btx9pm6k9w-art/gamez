extends Control
## Tactical map: terrain image, grid, units as faction-coloured blips, oil
## derricks, the camera's footprint, alert pings and a slow radar sweep.
## Left click or drag jumps the camera; right click orders the selection.

const UI := preload("res://scripts/ui/ui_theme.gd")

const SIZE := 220.0
const HEADER := 24.0

var battlefield: Battlefield
var selection: SelectionManager
var rig: RTSCamera
var economy: Node
var _tex: ImageTexture
var _sweep := 0.0


func setup(bf: Battlefield, sel: SelectionManager, camera_rig: RTSCamera) -> void:
	battlefield = bf
	selection = sel
	rig = camera_rig
	_tex = ImageTexture.create_from_image(bf.terrain.build_minimap_image())
	custom_minimum_size = Vector2(SIZE + 16, SIZE + HEADER + 16)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _map_rect() -> Rect2:
	return Rect2(Vector2(8, HEADER + 8), Vector2(SIZE, SIZE))


func _to_map(p: Vector3) -> Vector2:
	var r := _map_rect()
	return r.position + Vector2(p.x, p.z) / float(Battlefield.MAP_SIZE) * r.size


func _process(delta: float) -> void:
	_sweep = fmod(_sweep + delta * 0.9, TAU)
	queue_redraw()


func _draw() -> void:
	if battlefield == null:
		return
	draw_style_box(UI.panel_box(), Rect2(Vector2.ZERO, size))
	UI.draw_header(self, Vector2(8, 4), size.x - 16, "Tactical map")
	var r := _map_rect()
	draw_texture_rect(_tex, r, false, Color(0.85, 0.9, 0.95))
	var vision: Node = battlefield.vision
	if vision != null and vision.enabled:
		draw_texture_rect(vision.texture(), r, false)
	# Grid.
	for i in range(1, 8):
		var f := i / 8.0
		draw_line(r.position + Vector2(r.size.x * f, 0), r.position + Vector2(r.size.x * f, r.size.y), Color(UI.ACCENT, 0.07), 1.0)
		draw_line(r.position + Vector2(0, r.size.y * f), r.position + Vector2(r.size.x, r.size.y * f), Color(UI.ACCENT, 0.07), 1.0)
	# Radar sweep: a fading wedge behind a bright leading edge.
	var c := r.get_center()
	var reach := r.size.x * 0.5
	for k in 12:
		var a0 := _sweep - k * 0.06
		var a1 := a0 - 0.06
		var pts := PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * reach, c + Vector2(cos(a1), sin(a1)) * reach])
		draw_colored_polygon(pts, Color(UI.ACCENT, 0.09 * (1.0 - k / 12.0)))
	draw_line(c, c + Vector2(cos(_sweep), sin(_sweep)) * reach, Color(UI.ACCENT, 0.35), 1.0)
	draw_arc(c, reach, 0.0, TAU, 64, Color(UI.ACCENT, 0.12), 1.0, true)
	draw_arc(c, reach * 0.5, 0.0, TAU, 48, Color(UI.ACCENT, 0.08), 1.0, true)

	if economy != null:
		for i in economy.derricks.size():
			var dp: Vector3 = economy.derrick_position(i)
			if dp == Vector3.INF:
				continue
			var holder: int = economy.derricks[i]["owner"]
			var dc := UI.GOOD if holder == 0 else (UI.IRAN if holder == 1 else UI.WARN)
			var m := _to_map(dp)
			draw_colored_polygon(PackedVector2Array([m + Vector2(0, -5), m + Vector2(5, 0), m + Vector2(0, 5), m + Vector2(-5, 0)]), dc)
	for t in 2:
		for u: Unit in battlefield.units[t]:
			if not is_instance_valid(u) or not u.visible:
				continue
			var col := UI.COALITION if t == 0 else UI.IRAN
			if u.selected:
				col = Color.WHITE
			var p := _to_map(u.global_position)
			var half := 1.5 if u.is_air else (2.5 if u.def["radius"] > 1.0 else 1.8)
			draw_rect(Rect2(p - Vector2(half, half), Vector2(half, half) * 2.0), col)

	# Camera footprint.
	var corners := PackedVector2Array()
	var vs := get_viewport().get_visible_rect().size
	for sp: Vector2 in [Vector2.ZERO, Vector2(vs.x, 0), vs, Vector2(0, vs.y)]:
		var gp := selection.ground_point(sp)
		if gp == Vector3.INF:
			gp = rig.get_focus()
		var mp := _to_map(gp)
		corners.append(Vector2(clampf(mp.x, r.position.x, r.end.x), clampf(mp.y, r.position.y, r.end.y)))
	corners.append(corners[0])
	draw_polyline(corners, Color(1, 1, 1, 0.85), 1.2)

	# Alert ping.
	var age := Time.get_ticks_msec() / 1000.0 - selection.alert_time
	if selection.alert_pos != Vector3.INF and age < 4.0:
		var ap := _to_map(selection.alert_pos)
		for ring in 2:
			var ph := fmod(age * 1.2 + ring * 0.5, 1.0)
			draw_arc(ap, 4.0 + ph * 18.0, 0.0, TAU, 24, Color(UI.WARN, 1.0 - ph), 1.5)

	# Corner brackets.
	var b := 10.0
	for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var sx := 1.0 if corner.x == r.position.x else -1.0
		var sy := 1.0 if corner.y == r.position.y else -1.0
		draw_line(corner, corner + Vector2(b * sx, 0), UI.ACCENT, 2.0)
		draw_line(corner, corner + Vector2(0, b * sy), UI.ACCENT, 2.0)


func _gui_input(event: InputEvent) -> void:
	var r := _map_rect()
	var mouse := event as InputEventMouse
	if mouse == null or not r.has_point(mouse.position):
		return
	var w := (mouse.position - r.position) / r.size * float(Battlefield.MAP_SIZE)
	var world := Vector3(w.x, 0, w.y)
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		# Right click on the minimap orders the selection there (C&C, SC2).
		world.y = battlefield.terrain.height_at(world)
		selection.order_to_point(world, false, mb.shift_pressed)
		accept_event()
		return
	var press := mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	var drag := event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if press or drag:
		rig.focus_on(world)
		accept_event()
