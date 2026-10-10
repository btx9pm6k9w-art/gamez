extends "res://scripts/missions/mission.gd"
## Base-building test on the Mission 1 map (`-- --base-test`). Start with a
## Forward Operating Base and a squad by the pier, build power, a refinery,
## a barracks and a depot, then hold off the three enemy waves. It exercises
## base building until Mission 2 has its own map.

const FOB_POS := Vector3(76, 0, 160)

var fob: Structure


func briefing() -> Dictionary:
	return {
		"title": "BASE TEST",
		"subtitle": "Base building trial",
		"place": "Strait of Hormuz, Musandam coast",
		"time": "Test",
		"situation": [
			"Build a base by the pier and hold it against three waves.",
			"Open the Base tab on the sidebar. Click a structure to build it; when it shows READY, click it again and place it on the map near your base.",
			"Power Plants supply power. On low power production slows and defences stop firing.",
		],
	}


func _setup() -> void:
	economy.base_mode = true
	economy.credits = 4000.0
	economy.credits_changed.emit(economy.credits)
	var c := Battlefield.COALITION
	fob = economy.spawn_structure("fob", c, FOB_POS)
	for k in 6:
		battlefield.spawn_unit("ranger", c, Vector3(66 + (k % 3) * 2.5, 0, 152 + (k / 3) * 2.5), deg_to_rad(-45.0))
	battlefield.spawn_unit("abrams", c, Vector3(84, 0, 150), deg_to_rad(-45.0))
	battlefield.spawn_unit("laser_ad", c, Vector3(70, 0, 166), deg_to_rad(-45.0))
	_declare_objectives()


func _declare_objectives() -> void:
	add_objective("base", "Build a Power Plant, Refinery, Barracks and Vehicle Depot")
	add_objective("waves", "Hold off the three enemy waves")
	add_objective("fob", "Keep the Forward Operating Base standing")
	objective("fob")["done_on_win"] = true


func _evaluate(_dt: float) -> void:
	if is_active("base"):
		var need := ["power_plant", "refinery", "barracks", "vehicle_depot"]
		var have := 0
		for id: String in need:
			if economy.count_structures(id) > 0:
				have += 1
		set_progress("base", "%d of %d built" % [have, need.size()])
		if have == need.size():
			complete("base")
	if is_active("waves"):
		var attackers := 0
		for u: Unit in battlefield.units[Battlefield.IRAN]:
			if is_instance_valid(u) and u.is_alive() and u.has_meta("wave"):
				attackers += 1
		set_progress("waves", "%d of %d waves sent, %d attackers left" % [ai.waves_sent, ai.waves_sent + ai.waves_remaining(), attackers])
		if ai.waves_remaining() == 0 and attackers == 0:
			complete("waves")
	if is_active("fob") and (not is_instance_valid(fob) or not fob.is_alive()):
		fail("fob")
