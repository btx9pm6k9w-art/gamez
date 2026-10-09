extends Node3D
## Prototype skirmish "Beachhead": Coalition forces on the Strait of Hormuz
## coast hold off Iranian defenders, drone launchers and three attack waves.

const SEED := 2028

var battlefield: Battlefield
var rig: RTSCamera
var selection: SelectionManager
var ai: SimpleAI
var hud: HUD
var _game_over := false


func _ready() -> void:
	battlefield = Battlefield.new()
	battlefield.name = "Battlefield"
	add_child(battlefield)
	battlefield.build(SEED)

	rig = RTSCamera.new()
	rig.name = "CameraRig"
	rig.map_size = Battlefield.MAP_SIZE
	battlefield.add_child(rig)
	rig.focus_on(Vector3(72, 0, 150))

	selection = SelectionManager.new()
	selection.battlefield = battlefield
	selection.rig = rig
	add_child(selection)

	ai = SimpleAI.new()
	ai.battlefield = battlefield
	add_child(ai)

	hud = HUD.new()
	add_child(hud)
	hud.setup(battlefield, selection, rig, ai)

	_spawn_forces()
	battlefield.unit_killed.connect(_on_unit_killed)
	hud.show_message("Operation Fracture Line: take the village, survive the waves", HUD.ACCENT, 6.0)


func _spawn_forces() -> void:
	var c := Battlefield.COALITION
	var i := Battlefield.IRAN
	var face_ne := deg_to_rad(-45.0) # toward the Iranian hills
	for k in 4:
		battlefield.spawn_unit("abrams", c, Vector3(62 + k * 5.0, 0, 150), face_ne)
	for k in 8:
		battlefield.spawn_unit("ranger", c, Vector3(60 + (k % 4) * 2.5, 0, 157 + (k / 4) * 2.5), face_ne)
	for k in 2:
		battlefield.spawn_unit("k9", c, Vector3(76 + k * 3.0, 0, 154), face_ne)
	for k in 2:
		battlefield.spawn_unit("laser_ad", c, Vector3(58 + k * 10.0, 0, 166), face_ne)
	# Patrol boats alongside the pier.
	for k in 2:
		battlefield.spawn_unit("patrol_boat", c, Vector3(30, 0, 164 + k * 12.0), deg_to_rad(90.0))

	var face_sw := deg_to_rad(135.0)
	# Village garrison.
	for k in 8:
		var a := TAU * k / 8.0
		battlefield.spawn_unit("irgc", i, Vector3(100 + cos(a) * 6.0, 0, 100 + sin(a) * 6.0), face_sw)
	battlefield.spawn_unit("karrar", i, Vector3(108, 0, 92), face_sw)
	battlefield.spawn_unit("karrar", i, Vector3(92, 0, 108), face_sw)
	# Mountain base: launchers behind a tank screen.
	for k in 3:
		battlefield.spawn_unit("shahed_launcher", i, Vector3(146 + k * 6.0, 0, 50), face_sw)
	for k in 2:
		battlefield.spawn_unit("karrar", i, Vector3(140 + k * 8.0, 0, 62), face_sw)
	for k in 4:
		battlefield.spawn_unit("irgc", i, Vector3(140 + k * 3.0, 0, 66), face_sw)
	# Fast attack craft lurking in the lee of the island.
	for k in 3:
		battlefield.spawn_unit("fast_boat", i, Vector3(8 + k * 6.0, 0, 44), deg_to_rad(180.0))


func _on_unit_killed(_u: Unit) -> void:
	if _game_over:
		return
	var own := 0
	for u: Unit in battlefield.units[Battlefield.COALITION]:
		if not u.is_air:
			own += 1
	var enemy := 0
	for u: Unit in battlefield.units[Battlefield.IRAN]:
		if not u.is_air:
			enemy += 1
	if own == 0:
		_game_over = true
		hud.show_message("Beachhead lost. Press F6 to restart.", HUD.WARN, 9999.0)
	elif enemy == 0 and ai.waves_remaining() == 0:
		_game_over = true
		hud.show_message("Victory. The coast is secure. Press F6 to play again.", HUD.ACCENT, 9999.0)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and k.physical_keycode == KEY_F6:
		get_tree().reload_current_scene()
