class_name RTSCamera
extends Node3D
## Isometric-style RTS camera: pan (keys, screen edge, middle drag, trackpad),
## smooth zoom (wheel, pinch), 45-degree rotation steps, screen shake and a
## subtle depth of field that tightens as you zoom in.

const MIN_DIST := 16.0
const MAX_DIST := 95.0

var camera: Camera3D
var map_size := 192.0
var edge_pan := true

var _dist := 55.0
var _dist_target := 55.0
var _yaw := deg_to_rad(-30.0)
var _yaw_target := deg_to_rad(-30.0)
var _focus := Vector3.ZERO
var _trauma := 0.0
var _dragging := false
var _attrs: CameraAttributesPractical


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


func focus_on(p: Vector3) -> void:
	_focus = Vector3(p.x, 0.0, p.z)


func get_focus() -> Vector3:
	return _focus


func _on_shake(strength: float, origin: Vector3) -> void:
	var d := origin.distance_to(camera.global_position)
	_trauma = minf(_trauma + strength * clampf(60.0 / d, 0.0, 1.5), 1.0)


func _unhandled_input(event: InputEvent) -> void:
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
	elif event.is_action_pressed("cam_rotate_left"):
		_yaw_target += deg_to_rad(45.0)
	elif event.is_action_pressed("cam_rotate_right"):
		_yaw_target -= deg_to_rad(45.0)


func _pan(screen_delta: Vector2) -> void:
	var right := Vector3(cos(_yaw), 0, -sin(_yaw))
	var forward := Vector3(-sin(_yaw), 0, -cos(_yaw))
	_focus += right * screen_delta.x - forward * screen_delta.y


func _process(delta: float) -> void:
	var move := Vector2.ZERO
	move.x = Input.get_axis("cam_left", "cam_right")
	move.y = Input.get_axis("cam_forward", "cam_back")
	if edge_pan and DisplayServer.window_is_focused():
		var vp := get_viewport()
		var m := vp.get_mouse_position()
		var s := vp.get_visible_rect().size
		var margin := 6.0
		if m.x >= 0 and m.y >= 0 and m.x <= s.x and m.y <= s.y:
			if m.x < margin:
				move.x = -1
			elif m.x > s.x - margin:
				move.x = 1
			if m.y < margin:
				move.y = -1
			elif m.y > s.y - margin:
				move.y = 1
	if move != Vector2.ZERO:
		_pan(move.normalized() * delta * (20.0 + _dist * 0.9))

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
	_attrs.dof_blur_amount = lerpf(0.08, 0.0, t) if GameSettings.preset >= GameSettings.Preset.HIGH else 0.0
