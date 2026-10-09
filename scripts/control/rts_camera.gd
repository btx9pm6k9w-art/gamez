class_name RTSCamera
extends Node3D
## Isometric-style RTS camera: pan (arrow keys, screen edge, middle drag,
## trackpad), smooth zoom (wheel, pinch), 45-degree rotation steps, screen
## shake and a subtle depth of field that tightens as you zoom in.
##
## Edge scrolling follows the classic RTS rules (C&C, Red Alert, StarCraft,
## OpenRA): the cursor is confined to the window so it can be pushed against
## the edge, the scroll zone is a thin band measured in screen pixels, and the
## speed ramps up the deeper the cursor sits in the band and the longer it is
## held there. See docs/DESIGN.md, "Controls and camera".

signal setting_changed(text: String)

const MIN_DIST := 16.0
const MAX_DIST := 95.0

var camera: Camera3D
var map_size := 192.0
var edge_pan := true
## Keep the cursor inside the window so it can push against the screen edge.
var lock_mouse := true
## Edge band as a fraction of the window's shorter side (min 10 screen pixels).
var edge_margin := 0.012
## Player scroll speed multiplier, changed with - and = in game.
var scroll_speed := 1.0
## Main menu backdrop: the camera slowly circles and ignores player input.
var cinematic := false:
	set(v):
		cinematic = v
		_apply_mouse_lock()

var _dist := 55.0
var _dist_target := 55.0
var _yaw := deg_to_rad(-30.0)
var _yaw_target := deg_to_rad(-30.0)
var _focus := Vector3.ZERO
var _trauma := 0.0
var _dragging := false
var _attrs: CameraAttributesPractical
var _pan_vel := Vector2.ZERO
var _edge_time := 0.0
var _focused := true


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 38.0
	camera.near = 0.5
	camera.far = 1500.0
	camera.doppler_tracking = Camera3D.DOPPLER_TRACKING_IDLE_STEP # jets pitch-drop as they pass
	_attrs = CameraAttributesPractical.new()
	_attrs.dof_blur_far_enabled = true
	_attrs.dof_blur_amount = 0.06
	camera.attributes = _attrs
	add_child(camera)
	camera.make_current()
	_focus = position
	VFX.shake_requested.connect(_on_shake)
	_apply_mouse_lock()


func focus_on(p: Vector3) -> void:
	_focus = Vector3(p.x, 0.0, p.z)


func get_focus() -> Vector3:
	return _focus


func _on_shake(strength: float, origin: Vector3) -> void:
	var d := origin.distance_to(camera.global_position)
	_trauma = minf(_trauma + strength * clampf(60.0 / d, 0.0, 1.5), 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if cinematic:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_dist_target = clampf(_dist_target * 0.88, MIN_DIST, MAX_DIST)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_dist_target = clampf(_dist_target * 1.12, MIN_DIST, MAX_DIST)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_pan(Vector2(-mm.relative.x, -mm.relative.y) * _dist * 0.0022)
	elif event is InputEventMagnifyGesture:
		# Trackpad pinch on the MacBook.
		var g := event as InputEventMagnifyGesture
		_dist_target = clampf(_dist_target / g.factor, MIN_DIST, MAX_DIST)
	elif event is InputEventPanGesture:
		# Two-finger trackpad scroll pans the map.
		var pg := event as InputEventPanGesture
		_pan(pg.delta * _dist * 0.02)
	elif event.is_action_pressed("cam_scroll_faster"):
		_set_scroll_speed(scroll_speed + 0.25)
	elif event.is_action_pressed("cam_scroll_slower"):
		_set_scroll_speed(scroll_speed - 0.25)
	elif event.is_action_pressed("cam_lock_mouse"):
		lock_mouse = not lock_mouse
		_apply_mouse_lock()
		setting_changed.emit("Mouse locked to window" if lock_mouse else "Mouse free (edge scrolling only inside the window)")
	elif event.is_action_pressed("cam_reset"):
		_yaw_target = deg_to_rad(-30.0)
		_dist_target = 55.0
	elif event.is_action_pressed("cam_rotate_left"):
		_yaw_target += deg_to_rad(45.0)
	elif event.is_action_pressed("cam_rotate_right"):
		_yaw_target -= deg_to_rad(45.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true
		_apply_mouse_lock()


func _apply_mouse_lock() -> void:
	if not is_inside_tree():
		return
	if lock_mouse and _focused and not cinematic:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _set_scroll_speed(v: float) -> void:
	scroll_speed = clampf(v, 0.25, 3.0)
	setting_changed.emit("Scroll speed %d%%" % roundi(scroll_speed * 100.0))


## Edge-scroll direction and strength (0..1 per axis) from the cursor's
## position in screen pixels. Works with HiDPI and the HUD's content scale
## because it never uses viewport coordinates. When the mouse is not locked,
## a cursor that has slipped just past the window edge (onto the menu bar or
## the Dock) still counts, so a maximised window scrolls like a fullscreen one.
func _edge_vector() -> Vector2:
	var win := get_window()
	var rel := Vector2(DisplayServer.mouse_get_position() - win.position)
	var size := Vector2(win.size)
	var band := maxf(10.0, minf(size.x, size.y) * edge_margin)
	var slack := band * 6.0
	if rel.x < -slack or rel.y < -slack or rel.x > size.x + slack or rel.y > size.y + slack:
		return Vector2.ZERO
	var v := Vector2.ZERO
	if rel.x < band:
		v.x = -clampf(1.0 - rel.x / band, 0.0, 1.0)
	elif rel.x > size.x - band:
		v.x = clampf(1.0 - (size.x - rel.x) / band, 0.0, 1.0)
	if rel.y < band:
		v.y = -clampf(1.0 - rel.y / band, 0.0, 1.0)
	elif rel.y > size.y - band:
		v.y = clampf(1.0 - (size.y - rel.y) / band, 0.0, 1.0)
	return v


func _pan(screen_delta: Vector2) -> void:
	var right := Vector3(cos(_yaw), 0, -sin(_yaw))
	var forward := Vector3(-sin(_yaw), 0, -cos(_yaw))
	_focus += right * screen_delta.x - forward * screen_delta.y


func _process(delta: float) -> void:
	if cinematic:
		_yaw_target += delta * 0.04
		_yaw = _yaw_target
		_dist_target = 62.0
	var move := Vector2.ZERO
	if not cinematic:
		move.x = Input.get_axis("cam_left", "cam_right")
		move.y = Input.get_axis("cam_forward", "cam_back")
	if not cinematic and edge_pan and _focused and DisplayServer.window_is_focused() and not _dragging:
		var e := _edge_vector()
		if e != Vector2.ZERO:
			_edge_time += delta
			# Half speed on first touch, full speed after half a second, and
			# deeper into the band is faster (OpenRA and SC2 both ramp).
			var ramp := lerpf(0.45, 1.0, clampf(_edge_time / 0.5, 0.0, 1.0))
			var depth := Vector2(signf(e.x) * lerpf(0.6, 1.0, absf(e.x)), signf(e.y) * lerpf(0.6, 1.0, absf(e.y)))
			move = (move + depth * ramp).limit_length(1.0)
		else:
			_edge_time = 0.0
	if move.length() > 1.0:
		move = move.normalized()
	# Smooth start and stop so the view glides instead of jerking.
	var target_vel := move * (20.0 + _dist * 0.9) * scroll_speed
	_pan_vel = _pan_vel.lerp(target_vel, clampf(delta * 10.0, 0.0, 1.0))
	if _pan_vel.length_squared() > 0.0004:
		_pan(_pan_vel * delta)

	_focus.x = clampf(_focus.x, 0.0, map_size)
	_focus.z = clampf(_focus.z, 0.0, map_size)
	_dist = lerpf(_dist, _dist_target, clampf(delta * 8.0, 0.0, 1.0))
	_yaw = lerp_angle(_yaw, _yaw_target, clampf(delta * 8.0, 0.0, 1.0))

	# Closer means flatter and more cinematic; far means top-down tactical.
	var t := inverse_lerp(MIN_DIST, MAX_DIST, _dist)
	var pitch := deg_to_rad(lerpf(38.0, 62.0, t))
	var ground_y := 2.0
	var bf := get_parent() as Battlefield
	if bf and bf.terrain:
		ground_y = maxf(bf.terrain.height_at(_focus), 0.0)
	position = position.lerp(Vector3(_focus.x, ground_y, _focus.z), clampf(delta * 12.0, 0.0, 1.0))
	rotation = Vector3(0, _yaw, 0)
	var offset := Vector3(0, sin(pitch), cos(pitch)) * _dist
	var shake := Vector3.ZERO
	if _trauma > 0.0:
		var a := _trauma * _trauma
		shake = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * a * 0.8
		_trauma = maxf(_trauma - delta * 1.6, 0.0)
	camera.position = offset + shake
	camera.rotation = Vector3(-pitch, 0, 0)

	# Depth of field: background beyond the focus point softens, mostly when zoomed in.
	_attrs.dof_blur_far_distance = _dist * 1.25
	_attrs.dof_blur_far_transition = _dist * 0.9
	# Depth of field is a cinematic extra: Ultra only, gameplay presets stay sharp.
	_attrs.dof_blur_amount = lerpf(0.08, 0.0, t) if GameSettings.preset >= GameSettings.Preset.ULTRA else 0.0
