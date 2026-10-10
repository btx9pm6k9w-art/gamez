extends Node
## Scripted coalition player for balance and pacing checks: buys units, sends
## a squad to the oil derricks, takes the village with the main force, then
## pushes on the launch site while keeping a guard at the pier. Prints AUTO
## lines and quits when the mission ends.
##   godot --path . -- --autoplay [--autoplay-speed=5] [--autoplay-difficulty=1]

const STEP := 5.0 # game seconds between decisions
const LOG_EVERY := 15.0
const MAX_GAME_TIME := 1080.0

var main: Node
var speed := 5.0
var _t := 0.0
var _log_t := 0.0
var _phase := "village"
var _guard: Array[Unit] = []
var _derrick_team: Array[Unit] = []
var _won := false
var _ended := false
var _village_t := -1.0
var _reinf_logged := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autoplay-speed="):
			speed = float(arg.trim_prefix("--autoplay-speed="))
	_run.call_deferred()


func _ground(team: int) -> Array[Unit]:
	var out: Array[Unit] = []
	for u: Unit in main.battlefield.units[team]:
		if is_instance_valid(u) and u.is_alive() and not u.is_air and not u.is_naval:
			out.append(u)
	return out


func _idle(u: Unit) -> bool:
	return u.state == Unit.State.IDLE and u.waypoints.is_empty()


func _shop() -> void:
	var eco = main.economy
	# Infantry first (cheap, captures derricks), then armour when income allows.
	var want := [["ranger", 4], ["javelin", 2], ["abrams", 3], ["laser_ad", 1], ["javelin", 4], ["ranger", 8]]
	for entry in want:
		var id: String = entry[0]
		var have: int = _count(id) + int(eco.queued(id))
		if have < int(entry[1]) and eco.credits >= float(UnitDefs.get_def(id)["cost"]):
			eco.build(id)
			return


func _count(id: String) -> int:
	var n := 0
	for u in _ground(Battlefield.COALITION):
		if u.unit_id == id:
			n += 1
	return n


func _assign() -> void:
	var own := _ground(Battlefield.COALITION)
	_guard = _guard.filter(func(u) -> bool: return is_instance_valid(u) and u.is_alive())
	_derrick_team = _derrick_team.filter(func(u) -> bool: return is_instance_valid(u) and u.is_alive())
	for u in own:
		if u.unit_id == "ranger" and not _guard.has(u) and not _derrick_team.has(u):
			if _guard.size() < 2:
				_guard.append(u)
			elif _derrick_team.size() < 3:
				_derrick_team.append(u)


func _command() -> void:
	var mission = main.mission
	var eco = main.economy
	var pier := Vector3(62, 0, 164)
	for u in _guard:
		if u.global_position.distance_to(pier) > 14.0 and _idle(u):
			u.order_move(pier + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)), true)
	var held := int(eco.owned_derricks())
	var targets: Array[Vector3] = []
	for i in eco.derricks.size():
		var p: Vector3 = eco.derrick_position(i)
		if p != Vector3.INF and int(eco.derricks[i]["owner"]) != 0:
			targets.append(p)
	for k in _derrick_team.size():
		var u := _derrick_team[k]
		if _idle(u) and not targets.is_empty():
			var p := targets[k % targets.size()]
			u.order_move(p + Vector3(2.5, 0, 0), false)
	var village_done: bool = not mission.is_active("village") and mission.objective("village")["state"] != mission.State.HIDDEN
	if village_done and _phase == "village":
		_phase = "launchers"
		_village_t = _t
		print("AUTO t=%.0f village taken, pushing on the launch site" % _t)
	var goal: Vector3 = Vector3(100, 0, 100) if _phase == "village" else mission.LAUNCH_SITE
	if _village_t >= 0.0 and not _reinf_logged and _t >= _village_t + 25.0:
		_reinf_logged = true
		var rally: Vector3 = eco.rally["infantry"]
		var rows := []
		for u in _ground(Battlefield.COALITION):
			if u.has_meta("reinforcement"):
				rows.append("%s %.0f m from rally%s" % [u.unit_id, u.global_position.distance_to(rally), " (idle)" if _idle(u) else " (moving)"])
		print("AUTO t=%.0f reinforcements 25 s after landing: %s" % [_t, "; ".join(rows) if not rows.is_empty() else "none found"])
	for u in _ground(Battlefield.COALITION):
		if _guard.has(u) or _derrick_team.has(u):
			continue
		if u.has_meta("reinforcement") and (_village_t < 0.0 or _t < _village_t + 25.0):
			continue
		if _idle(u) or not u.has_meta("auto_goal") or u.get_meta("auto_goal") != _phase:
			u.set_meta("auto_goal", _phase)
			u.order_move(goal + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), true)
	if held < 2 and _t > 200.0 and targets.is_empty():
		pass


func _status() -> void:
	var m = main.mission
	var eco = main.economy
	var own := _ground(Battlefield.COALITION)
	var foes := _ground(Battlefield.IRAN)
	var kinds := {}
	for u in own:
		kinds[u.unit_id] = int(kinds.get(u.unit_id, 0)) + 1
	var states := []
	for o in m.objectives:
		states.append("%s=%s" % [o["id"], ["hidden", "active", "done", "failed"][int(o["state"])] if int(o["state"]) < 4 else str(o["state"])])
	var pier := Vector3(62, 0, 164)
	print("AUTO t=%.0f own=%d %s foes=%d credits=%d derricks=%d waves=%d pier(enemy=%d ours=%d threat=%.0fs) kills=%d losses=%d | %s" % [
		_t, own.size(), JSON.stringify(kinds), foes.size(), int(eco.credits), eco.owned_derricks(), main.ai.waves_sent,
		m.count_near(Battlefield.IRAN, pier, m.PIER_RADIUS), m.count_near(Battlefield.COALITION, pier, m.PIER_RADIUS),
		m._pier_threat, m.kills, m.losses, " ".join(states)])


func _run() -> void:
	main.rig.edge_pan = false
	GameSettings.fps_cap = 0
	Engine.max_fps = 0
	await get_tree().create_timer(2.0).timeout
	Engine.time_scale = speed
	var mission = main.mission
	mission.mission_ended.connect(func(won: bool, summary: String) -> void:
		_ended = true # a member: lambdas capture local variables by value
		_won = won
		print("AUTO RESULT %s at %.0f game s (%d:%02d). %s" % ["WIN" if won else "LOSS", mission.elapsed, int(mission.elapsed) / 60, int(mission.elapsed) % 60, summary.replace("\n", " | ")]))
	mission.objective_completed.connect(func(text: String) -> void: print("AUTO t=%.0f objective done: %s" % [mission.elapsed, text]))
	mission.objective_added.connect(func(text: String) -> void: print("AUTO t=%.0f objective revealed: %s" % [mission.elapsed, text]))
	while not _ended and _t < MAX_GAME_TIME:
		await get_tree().create_timer(STEP).timeout
		_t += STEP
		_assign()
		_shop()
		_command()
		_log_t += STEP
		if _log_t >= LOG_EVERY:
			_log_t = 0.0
			_status()
	if not _ended:
		print("AUTO RESULT TIMEOUT at %.0f game s with no end state" % _t)
		_status()
	Engine.time_scale = 1.0
	get_tree().quit()
