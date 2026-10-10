extends Node3D
## C&C placement mode for a finished structure: a see-through copy follows the
## mouse on a 1 m grid, green where it can stand and red (with the reason)
## where it cannot. Left click places, right click or Esc puts it back on the
## sidebar as ready. Doors face south (+Z), toward the camera.

const BuildingModels := preload("res://scripts/buildings/building_models.gd")

var economy: Node # scripts/game/economy.gd
var selection: SelectionManager
var active := false
var id := ""
var yaw := 0.0
var problem := ""

var _ghost: Node3D
var _ring: MeshInstance3D
var _label: Label3D
var _ok_mat: StandardMaterial3D
var _bad_mat: StandardMaterial3D


func _ready() -> void:
	_ok_mat = _ghost_mat(Color(0.3, 1.0, 0.5, 0.45))
	_bad_mat = _ghost_mat(Color(1.0, 0.3, 0.25, 0.45))
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0012
	_label.font_size = 30
	_label.outline_size = 10
	_label.modulate = Color(1.0, 0.55, 0.45)
	_label.visible = false
	add_child(_label)


func _ghost_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func arm(structure_id: String) -> void:
	cancel()
	id = structure_id
	active = true
	_ghost = BuildingModels.build(BuildingDefs.get_def(id)["model"], "coalition")
	add_child(_ghost)
	for mi in _ghost.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	var r: float = BuildingDefs.get_def(id)["radius"]
	torus.inner_radius = r
	torus.outer_radius = r + 0.25
	torus.rings = 48
	torus.ring_segments = 4
	_ring.mesh = torus
	_ring.position.y = 0.5
	_ghost.add_child(_ring)
	_ghost.rotation.y = yaw
	Audio.play_ui("ui_select")


func cancel() -> void:
	active = false
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	_label.visible = false


func confirm() -> void:
	if not active:
		return
	_update_ghost()
	if problem != "":
		Audio.play_ui("ui_error")
		return
	var p := _ghost.global_position
	if economy.place_ready(p, yaw) != null:
		cancel()


func _process(_delta: float) -> void:
	if not active:
		return
	if economy.structure_ready != id:
		# Cancelled from the sidebar, or the base was lost.
		cancel()
		return
	_update_ghost()


func _update_ghost() -> void:
	var p := selection.ground_point(get_viewport().get_mouse_position())
	if p == Vector3.INF:
		problem = "Off the map"
		return
	p = Vector3(roundf(p.x), 0, roundf(p.z))
	p.y = selection.battlefield.terrain.height_at(p)
	_ghost.global_position = p
	problem = economy.placement_problem(id, p)
	var m := _ok_mat if problem == "" else _bad_mat
	for mi in _ghost.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m
	_label.visible = problem != ""
	_label.text = problem
	_label.global_position = p + Vector3.UP * 7.0
