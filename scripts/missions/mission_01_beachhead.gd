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
## The landing area at the pier. Lose it and the mission is lost.
const PIER := Vector3(62, 0, 164)
const PIER_RADIUS := 18.0
const PIER_LOSS_TIME := 30.0
const LAUNCH_SITE := Vector3(152, 0, 52)
## After the village falls the player holds it until the reinforcements land;
## the clock pauses while the enemy outnumbers us there.
const HOLD_VILLAGE_TIME := 120.0
## Launch site revealed anyway after this long, if scouting and the hold
## have not revealed it.
const LAUNCHERS_FALLBACK := 420.0

var _hold := 0.0
var _counter_sent := false
var _pier_threat := 0.0
var _hold_left := HOLD_VILLAGE_TIME
var _second_push := false
## Radio beats already played (ids).
var _said := {}


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
			"F and G call the commander's strikes: they cost credits and hit your own troops too.",
			"The K9 robot dogs see furthest. Scout ahead before you commit the tanks.",
			"Hold the village after you take it: the ships land reinforcements once it is safe.",
		],
	}


func _setup() -> void:
	_spawn_forces()
	_declare_objectives()


func _declare_objectives() -> void:
	add_objective("village", "Take the oasis village and hold it")
	add_objective("hold", "Hold the village until the reinforcements land", true, false)
	add_objective("pier", "Keep the pier: do not let the enemy hold it")
	objective("pier")["done_on_win"] = true
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
	var garrison := 9 + difficulty * 3
	for k in garrison:
		var a := TAU * k / float(garrison)
		battlefield.spawn_unit("irgc_rpg" if k % 3 == 0 else "irgc", i, VILLAGE + Vector3(cos(a) * 6.0, 0, sin(a) * 6.0), face_sw)
	battlefield.spawn_unit("karrar", i, Vector3(108, 0, 92), face_sw)
	if difficulty >= 1:
		battlefield.spawn_unit("karrar", i, Vector3(92, 0, 108), face_sw)
	# Mountain launch site: launchers behind a tank screen.
	for k in 3:
		battlefield.spawn_unit("shahed_launcher", i, Vector3(146 + k * 6.0, 0, 50), face_sw)
	for k in 2 + difficulty:
		battlefield.spawn_unit("karrar", i, Vector3(136 + k * 8.0, 0, 62), face_sw)
	for k in 4 + difficulty * 2:
		battlefield.spawn_unit("irgc_rpg" if k % 2 == 0 else "irgc", i, Vector3(138 + (k % 4) * 3.0, 0, 66 + (k / 4) * 3.0), face_sw)
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

	if is_active("hold"):
		_evaluate_hold(dt)

	# Launchers: revealed when the village is held, by scouting, or late anyway.
	if objective("launchers")["state"] == State.HIDDEN and elapsed > LAUNCHERS_FALLBACK:
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

	_evaluate_pier(dt)
	_scouting()
	_radio()

	# Defeat: no ground forces and no money to buy more.
	if count_units(Battlefield.COALITION) == 0 and economy.credits < 150.0:
		var building := false
		for cat: String in economy.queues:
			if not economy.queues[cat].is_empty() and cat != "naval":
				building = true
		if not building:
			end(false, "All ground forces lost.")


## The pier is lost when enemy troops stand on it with none of ours for
## PIER_LOSS_TIME seconds; the countdown shows on the objective.
func _evaluate_pier(dt: float) -> void:
	if not is_active("pier"):
		return
	var enemies := count_near(Battlefield.IRAN, PIER, PIER_RADIUS)
	var ours := count_near(Battlefield.COALITION, PIER, PIER_RADIUS)
	if enemies > 0 and ours == 0:
		if _pier_threat == 0.0:
			hud.show_message("The pier is under attack", HUD.WARN, 4.0, "Send troops back or we lose the landing")
			UnitVoice.alert("under_attack", 0.0)
			_ping(PIER)
		_pier_threat += dt
		set_progress("pier", "Enemy on the pier: %d s" % maxi(int(PIER_LOSS_TIME - _pier_threat), 0))
		if _pier_threat >= PIER_LOSS_TIME:
			fail("pier")
	else:
		_pier_threat = maxf(_pier_threat - dt * 2.0, 0.0)
		set_progress("pier", "Enemy at the pier" if enemies > 0 else "")


## Seeing a launcher with any unit reveals the launch-site objective early.
func _scouting() -> void:
	if objective("launchers")["state"] != State.HIDDEN or battlefield.vision == null:
		return
	for u: Unit in battlefield.units[Battlefield.IRAN]:
		if is_instance_valid(u) and u.unit_id == "shahed_launcher" and battlefield.vision.is_visible_at(u.global_position):
			hud.show_message("Launch site spotted", HUD.ACCENT, 5.0, "Good eyes. The drone launchers are in the hills to the north-east")
			reveal("launchers")
			_ping(u.global_position)
			return


## Short radio lines that teach and pace the mission, each played once.
func _radio() -> void:
	_say("scout", elapsed > 20.0, "HQ: K9 dogs see furthest. Send one ahead toward the village.")
	_say("oil", elapsed > 75.0 and economy.owned_derricks() == 0, "HQ: no income yet. The oil derricks are east of the pier.")
	_say("strike", elapsed > 150.0 and economy.credits >= 600.0, "HQ: credits banked. F calls a precision strike on a dug-in position.")
	_say("ad", elapsed > 200.0 and is_active("launchers"), "HQ: keep the laser trucks with the army; they shoot down the drones.")


func _say(id: String, when: bool, text: String) -> void:
	if when and not _said.has(id):
		_said[id] = true
		hud.notify(text)
		Audio.play_ui("alert")


## Mark a place on the tactical map; Space jumps the camera there.
func _ping(p: Vector3) -> void:
	var sel: SelectionManager = hud.selection
	if sel != null:
		sel.alert_pos = p
		sel.alert_time = Time.get_ticks_msec() / 1000.0


## Second act: the enemy wants the village back. The landing craft needs
## HOLD_VILLAGE_TIME seconds; the clock stops while they outnumber us there.
func _evaluate_hold(dt: float) -> void:
	var enemies := count_near(Battlefield.IRAN, VILLAGE, VILLAGE_RADIUS)
	var ours := count_near(Battlefield.COALITION, VILLAGE, VILLAGE_RADIUS)
	if ours == 0 or enemies > ours:
		set_progress("hold", "Contested: %d s to go, clock stopped" % int(ceil(_hold_left)))
	else:
		_hold_left -= dt
		set_progress("hold", "Reinforcements in %d s" % int(ceil(maxf(_hold_left, 0.0))))
	if not _second_push and _hold_left < HOLD_VILLAGE_TIME * 0.5:
		_second_push = true
		ai.counter_attack(VILLAGE, 2 + difficulty * 2)
		hud.notify("HQ: second enemy group moving on the village.", HUD.WARN)
	if _hold_left <= 0.0:
		complete("hold")
		_after_hold()


func _after_village() -> void:
	reveal("hold")
	hud.show_message("Village secured", HUD.ACCENT, 6.0, "Hold it. A landing craft with reinforcements is on its way.")
	if not _counter_sent:
		_counter_sent = true
		ai.counter_attack(VILLAGE, 3 + difficulty * 2)
		UnitVoice.alert("counter_attack", 0.0)


func _after_hold() -> void:
	reveal("launchers")
	hud.show_message("Reinforcements landing", HUD.ACCENT, 6.0, "Intel from the village marks the drone launch site in the hills to the north-east.")
	if battlefield.vision != null:
		battlefield.vision.reveal(LAUNCH_SITE, 20.0)
	_ping(LAUNCH_SITE)
	_land_reinforcements()


## The road through the village is open: a landing craft brings a fresh
## company to the pier, smaller on Elite.
func _land_reinforcements() -> void:
	var c := Battlefield.COALITION
	var kinds := ["abrams", "ranger", "ranger", "ranger", "javelin"]
	if difficulty == 0:
		kinds.append_array(["abrams", "ranger"])
	elif difficulty == 2:
		kinds.erase("abrams")
	var rally: Vector3 = economy.rally["infantry"]
	for k in kinds.size():
		var u := battlefield.spawn_unit(kinds[k], c, economy.landing_zone + Vector3((k % 3) * 3.0, 0, (k / 3) * 3.0), deg_to_rad(-45.0))
		u.set_meta("reinforcement", true)
		u.order_move(rally + Vector3((k % 3) * 2.5, 0, (k / 3) * 2.5))
	UnitVoice.alert("reinforcements", 0.0)
	hud.notify("Reinforcements: %d units at the pier" % kinds.size(), Color(0.4, 1.0, 0.55))


func _on_unit_killed(u: Unit) -> void:
	super(u)
	if u.team == Battlefield.COALITION and u.unit_id == "patrol_boat" and not u.has_meta("reinforcement"):
		fail("boats")
