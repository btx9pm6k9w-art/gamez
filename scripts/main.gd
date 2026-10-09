extends Node3D
## Entry point. Builds the battlefield, camera, controls, AI, economy and HUD,
## then runs Mission 1 "Beachhead" after its briefing. The mission owns the
## starting forces, objectives, win and loss (scripts/missions/).

const Economy := preload("res://scripts/game/economy.gd")
const Mission01 := preload("res://scripts/missions/mission_01_beachhead.gd")
const Briefing := preload("res://scripts/ui/briefing.gd")
const Sidebar := preload("res://scripts/ui/sidebar.gd")
const MainMenu := preload("res://scripts/ui/main_menu.gd")

const SEED := 2028

var battlefield: Battlefield
var rig: RTSCamera
var selection: SelectionManager
var ai: SimpleAI
var hud: HUD
var economy: Economy
var mission: Node
var _overlay_layer: CanvasLayer
static var _showcase_opened := false
## The main menu shows on launch only; restarts (F6, Play again) go straight
## to the briefing.
static var _menu_seen := false


func _ready() -> void:
	if "--showcase" in OS.get_cmdline_user_args() and not _showcase_opened:
		_showcase_opened = true
		get_tree().change_scene_to_file.call_deferred("res://scenes/unit_showcase.tscn")
		return
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

	economy = Economy.new()
	economy.name = "Economy"
	add_child(economy)
	economy.setup(battlefield)
	ai.economy = economy
	selection.economy = economy

	hud = HUD.new()
	add_child(hud)
	hud.setup(battlefield, selection, rig, ai)

	var sidebar := Sidebar.new()
	hud.add_child(sidebar)
	sidebar.setup(economy, selection)
	sidebar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sidebar.offset_left = -sidebar.custom_minimum_size.x - 16
	sidebar.offset_right = -16
	sidebar.offset_top = 46
	sidebar.offset_bottom = 46 + sidebar.custom_minimum_size.y

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 5
	_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay_layer)

	mission = Mission01.new()
	mission.name = "Mission"
	add_child(mission)
	mission.mission_ended.connect(_on_mission_ended)
	if "--benchmark" in OS.get_cmdline_user_args():
		# Benchmarks skip the briefing so the scene is identical every run.
		_start_mission(1)
		add_child(Benchmark.new())
	else:
		# Nothing fights until the mission starts; the HUD waits too.
		for n: Node in [ai, economy, selection]:
			n.process_mode = Node.PROCESS_MODE_DISABLED
		hud.visible = false
		if _menu_seen:
			_show_briefing()
		else:
			_menu_seen = true
			rig.cinematic = true
			rig.focus_on(Vector3(96, 0, 120))
			var menu := MainMenu.new()
			_overlay_layer.add_child(menu)
			menu.campaign.connect(_show_briefing)
			menu.showcase.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/unit_showcase.tscn"))


func _show_briefing() -> void:
	rig.cinematic = false
	rig.focus_on(Vector3(72, 0, 150))
	var briefing := Briefing.new()
	_overlay_layer.add_child(briefing)
	briefing.begin.connect(_start_mission)
	briefing.show_briefing(mission.briefing(), mission.preview_objectives())


func _start_mission(difficulty: int) -> void:
	for n: Node in [ai, economy, selection]:
		n.process_mode = Node.PROCESS_MODE_INHERIT
	hud.visible = true
	mission.difficulty = difficulty
	ai.difficulty = difficulty
	mission.start(battlefield, economy, ai, hud)
	hud.set_mission(mission, economy)
	var info: Dictionary = mission.briefing()
	hud.show_message(String(info.get("title", "")), HUD.ACCENT, 4.0, String(info.get("place", "")))


func _on_mission_ended(won: bool, summary: String) -> void:
	var debrief := Briefing.new()
	_overlay_layer.add_child(debrief)
	debrief.show_debrief(won, summary, mission.objectives)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and k.physical_keycode == KEY_F6:
		get_tree().reload_current_scene()
	elif k and k.pressed and k.physical_keycode == KEY_F8:
		get_tree().change_scene_to_file("res://scenes/unit_showcase.tscn")
