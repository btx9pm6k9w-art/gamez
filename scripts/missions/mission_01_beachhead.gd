extends "res://scripts/missions/mission.gd"
## Mission 1, "Beachhead". The Coalition lands at the pier on the Strait of
## Hormuz coast. Take the oasis village, secure the oil field to pay for
## reinforcements, then find and destroy the drone launchers in the hills
## that struck the tankers. Teaches selection, attack-move, capture, the
## sidebar and the commander strikes.

const VILLAGE := Vector3(100, 0, 100)
const VILLAGE_RADIUS := 20.0
const HOLD_TIME := 8.0
const TIME_LIMIT := 15.0 * 60.0

var _hold := 0.0
var _counter_sent := false


func briefing() -> Dictionary:
	return {
		"title": "MISSION 1: BEACHHEAD",
		"subtitle": "Operation Fracture Line",
		"place": "Strait of Hormuz, Musandam coast",
		"time": "14 March 2028, 17:40 local",
		"situation": [
			"At dawn, drones launched from these hills struck two tankers in the strait. Shipping has stopped and the Gulf is watching.",
			"Your task force has landed at the old fishing pier. IRGC troops hold the oasis village inland, and the oil field to the east is unguarded.",
			"Take the village, secure the oil derricks to fund reinforcements, then find the launch site and silence it. Expect counter-attacks from the mountains and fast attack craft along the coast.",
		],
		"tips": [
			"Drag to select, right click to move. A then click attack-moves.",
			"Stand next to a derrick with no enemy nearby to capture it.",
			"Spend credits in the sidebar on the right. Right click a unit there to cancel.",
			"Mix your army: rifles beat infantry, Javelins and tanks beat armour, laser trucks stop drones.",
			"F and G call the commander's strikes. Space jumps to the last alert.",
		],
	}


func _setup() -> void:
	_spawn_forces()
	_declare_objectives()


func _declare_objectives() -> void:
	add_objective("village", "Take the oasis village and hold it")
	add_objective("oil", "Secure 2 of the 3 oil derricks east of the pier")
	add_objective("launchers", "Destroy the Shahed drone launchers in the hills", true, false)
	add_objective("boats", "Bonus: keep both patrol boats afloat", false)
	objective("boats")["done_on_win"] = true
	add_objective("fast", "Bonus: finish within 15 minutes", false)
	objective("fast")["done_on_win"] = true


func _spawn_forces() -> void:
	var c := Battlefield.COALITION
	var i := Battlefield.IRAN
	var face_ne := deg_to_rad(-45.0) # toward the Iranian hills
	var n_tanks := 4 if difficulty < 2 else 3
	for k in n_tanks:
		battlefield.spawn_unit("abrams", c, Vector3(62 + k * 5.0, 0, 150), face_ne)
	for k in 8:
		battlefield.spawn_unit("ranger", c, Vector3(60 + (k % 4) * 2.5, 0, 157 + (k / 4) * 2.5), face_ne)
	for k in 2:
		battlefield.spawn_unit("javelin", c, Vector3(70 + k * 2.5, 0, 158), face_ne)
	for k in 2:
		battlefield.spawn_unit("k9", c, Vector3(76 + k * 3.0, 0, 154), face_ne)
	for k in 2:
		battlefield.spawn_unit("laser_ad", c, Vector3(58 + k * 10.0, 0, 166), face_ne)
	for k in 2:
		battlefield.spawn_unit("patrol_boat", c, Vector3(30, 0, 164 + k * 12.0), deg_to_rad(90.0))

	var face_sw := deg_to_rad(135.0)
	var garrison := 6 + difficulty * 2
	for k in garrison:
		var a := TAU * k / float(garrison)
		battlefield.spawn_unit("irgc_rpg" if k % 3 == 0 else "irgc", i, VILLAGE + Vector3(cos(a) * 6.0, 0, sin(a) * 6.0), face_sw)
	battlefield.spawn_unit("karrar", i, Vector3(108, 0, 92), face_sw)
	if difficulty >= 1:
		battlefield.spawn_unit("karrar", i, Vector3(92, 0, 108), face_sw)
	# Mountain launch site: launchers behind a tank screen.
	for k in 3:
		battlefield.spawn_unit("shahed_launcher", i, Vector3(146 + k * 6.0, 0, 50), face_sw)
	for k in 1 + difficulty:
		battlefield.spawn_unit("karrar", i, Vector3(140 + k * 8.0, 0, 62), face_sw)
	for k in 2 + difficulty:
		battlefield.spawn_unit("irgc", i, Vector3(140 + k * 3.0, 0, 66), face_sw)
	# Fast attack craft in the lee of the island.
	for k in 2 + mini(difficulty, 1):
		battlefield.spawn_unit("fast_boat", i, Vector3(8 + k * 6.0, 0, 44), deg_to_rad(180.0))


func _evaluate(dt: float) -> void:
	# Village: clear every enemy soldier near it, then hold it for a moment.
	if is_active("village"):
		var enemies := count_near(Battlefield.IRAN, VILLAGE, VILLAGE_RADIUS)
		var ours := count_near(Battlefield.COALITION, VILLAGE, VILLAGE_RADIUS * 0.7)
		if enemies > 0:
			_hold = 0.0
			set_progress("village", "%d defenders left" % enemies)
		elif ours == 0:
			_hold = 0.0
			set_progress("village", "Move troops into the village")
		else:
			_hold += dt
			set_progress("village", "Holding %d of %d s" % [mini(int(_hold), int(HOLD_TIME)), int(HOLD_TIME)])
			if _hold >= HOLD_TIME:
				complete("village")
				_after_village()

	# Oil: two derricks held at the same moment.
	if is_active("oil"):
		var held := economy.owned_derricks()
		var alive := 0
		for d in economy.derricks:
			if d["prop"]["alive"]:
				alive += 1
		set_progress("oil", "%d of 3 held, +%d credits/s" % [held, int(economy.income_per_second())])
		if held >= 2:
			complete("oil")
		elif alive < 2:
			fail("oil")

	# Launchers: revealed by the village intel, or after a few minutes anyway.
	if objective("launchers")["state"] == State.HIDDEN and elapsed > 240.0:
		reveal("launchers")
	if is_active("launchers"):
		var left := count_units(Battlefield.IRAN, "shahed_launcher")
		set_progress("launchers", "%d left, in the hills to the north-east" % left)
		if left == 0:
			complete("launchers")

	if is_active("fast"):
		var remaining := TIME_LIMIT - elapsed
		set_progress("fast", "%d:%02d left" % [int(remaining) / 60, int(remaining) % 60])
		if remaining <= 0.0:
			fail("fast")

	# Defeat: no ground forces and no money to buy more.
	if count_units(Battlefield.COALITION) == 0 and economy.credits < 150.0:
		var building := false
		for cat: String in economy.queues:
			if not economy.queues[cat].is_empty() and cat != "naval":
				building = true
		if not building:
			end(false, "All ground forces lost.")


func _after_village() -> void:
	reveal("launchers")
	hud.show_message("Village secured", HUD.ACCENT, 6.0, "Intel: the launch site is in the hills to the north-east.")
	if not _counter_sent:
		_counter_sent = true
		ai.counter_attack(VILLAGE, 3 + difficulty * 2)
		UnitVoice.alert("counter_attack", 0.0)


func _on_unit_killed(u: Unit) -> void:
	super(u)
	if u.team == Battlefield.COALITION and u.unit_id == "patrol_boat" and not u.has_meta("reinforcement"):
		fail("boats")
