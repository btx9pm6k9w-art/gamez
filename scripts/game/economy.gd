extends Node
## Oil economy and reinforcements, C&C style.
##
## Oil derricks (the oil field's pumpjacks) are captured by standing next to
## them with no enemy nearby, and pay a steady income while held. Credits buy
## reinforcements from the sidebar: each production line (infantry, vehicle,
## naval) builds one unit at a time from its queue, and finished units arrive
## at the landing zone and head for the line's rally point. Cost is paid up
## front and refunded on cancel.
##
## Base mode (missions with base building): the Forward Operating Base builds
## structures one at a time; a finished one waits as "ready" until the player
## places it. Barracks and the vehicle depot open the infantry and vehicle
## lines, and new units roll out of them instead of landing at the pier.
## Structures supply or draw power; on low power production runs at half
## speed and defences hold fire. Refineries add income.

const UnitVoice := preload("res://scripts/audio/unit_voice.gd")

signal credits_changed(credits: float)
signal derrick_changed(index: int, holder: int)
signal unit_delivered(unit: Unit)
signal structure_finished(id: String)
signal structures_changed

const START_CREDITS := 1500.0
const INCOME_PER_DERRICK := 6.0 # credits per second
const CAPTURE_RADIUS := 9.0
const CAPTURE_TIME := 5.0
const MAX_QUEUE := 6
const CATEGORIES := ["infantry", "vehicle", "naval"]
## How far past an existing structure's edge a new one may be placed.
const BUILD_RANGE := 14.0
## Each refinery adds this share to derrick income.
const REFINERY_BONUS := 0.25

var battlefield: Battlefield
var credits := START_CREDITS
## Each derrick: {"prop": Dictionary, "owner": -1 (neutral) / 0 / 1, "capture": -1..1}
var derricks: Array[Dictionary] = []
## Per category: Array of unit ids waiting, front one in production.
var queues := {"infantry": [], "vehicle": [], "naval": []}
var progress := {"infantry": 0.0, "vehicle": 0.0, "naval": 0.0}
var landing_zone := Vector3(62, 0, 168)
var harbour_spawn := Vector3(30, 0, 172)
var rally := {"infantry": Vector3(70, 0, 152), "vehicle": Vector3(70, 0, 152), "naval": Vector3(36, 0, 160)}

var _tick := 0.0

var base_mode := false
## Naval line in base mode (missions with a harbour set this).
var naval_in_base := false
var structures: Array[Structure] = []
var structure_queue := "" # being built
var structure_progress := 0.0
var structure_ready := "" # built, waiting to be placed
var _was_low_power := false


func setup(bf: Battlefield) -> void:
	battlefield = bf
	for prop in bf.props:
		if prop["kind"] == "pumpjack":
			derricks.append({"prop": prop, "owner": -1, "capture": 0.0})


func income_per_second() -> float:
	var n := 0
	for d in derricks:
		if d["owner"] == Battlefield.COALITION and d["prop"]["alive"]:
			n += 1
	var refineries := count_structures("refinery")
	return n * INCOME_PER_DERRICK * (1.0 + REFINERY_BONUS * refineries) \
		+ refineries * float(BuildingDefs.get_def("refinery")["income"])


func owned_derricks(team := Battlefield.COALITION) -> int:
	var n := 0
	for d in derricks:
		if d["owner"] == team and d["prop"]["alive"]:
			n += 1
	return n


func derrick_position(i: int) -> Vector3:
	# Untyped: a destroyed derrick's node is freed, and a freed instance cannot be
	# assigned to a typed variable (that logged an error every minimap redraw).
	var node = derricks[i]["prop"]["node"]
	return (node as Node3D).global_position if is_instance_valid(node) else Vector3.INF


func queued(id: String) -> int:
	return queues[UnitDefs.get_def(id)["category"]].count(id)


## 0..1 progress of id if it is the unit currently in production.
func progress_of(id: String) -> float:
	var cat: String = UnitDefs.get_def(id)["category"]
	var q: Array = queues[cat]
	if q.is_empty() or q[0] != id:
		return 0.0
	return progress[cat] / float(UnitDefs.get_def(id)["build_time"])


## Pays for something outside the build queues (commander powers).
func spend(amount: float) -> bool:
	if credits < amount:
		return false
	credits -= amount
	credits_changed.emit(credits)
	return true


func build(id: String) -> bool:
	if BuildingDefs.has(id):
		return build_structure(id)
	var def := UnitDefs.get_def(id)
	if not line_open(def["category"]):
		Audio.play_ui("ui_error")
		return false
	var q: Array = queues[def["category"]]
	if q.size() >= MAX_QUEUE:
		Audio.play_ui("ui_error")
		return false
	if credits < float(def["cost"]):
		Audio.play_ui("ui_error")
		UnitVoice.alert("insufficient", 3.0)
		return false
	credits -= float(def["cost"])
	credits_changed.emit(credits)
	q.append(id)
	Audio.play_ui("ui_confirm")
	UnitVoice.alert("building", 1.5)
	return true


## Cancel the last queued id (the one in production goes last), refunding it.
func cancel(id: String) -> void:
	if BuildingDefs.has(id):
		cancel_structure(id)
		return
	var def := UnitDefs.get_def(id)
	var cat: String = def["category"]
	var q: Array = queues[cat]
	var i := q.rfind(id)
	if i < 0:
		return
	q.remove_at(i)
	if i == 0:
		progress[cat] = 0.0
	credits += float(def["cost"])
	credits_changed.emit(credits)
	Audio.play_ui("ui_select")


func set_rally(category: String, p: Vector3) -> void:
	rally[category] = p
	VFX.ground_ring(p, Color(0.4, 1.4, 3.0, 1), 2.0, 0.8)


func _process(delta: float) -> void:
	if battlefield == null:
		return
	var income := income_per_second()
	if income > 0.0:
		credits += income * delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.25
		_update_derricks(0.25)
		credits_changed.emit(credits)
	var rate := 0.5 if low_power() else 1.0
	if base_mode:
		_update_structures(delta * rate)
	for cat: String in CATEGORIES:
		var q: Array = queues[cat]
		if q.is_empty() or not line_open(cat):
			continue
		progress[cat] += delta * rate
		if progress[cat] >= float(UnitDefs.get_def(q[0])["build_time"]):
			progress[cat] = 0.0
			_deliver(q.pop_front(), cat)


func _deliver(id: String, cat: String) -> void:
	var spawn := harbour_spawn if cat == "naval" else landing_zone
	var producer := producer_for(cat)
	if producer != null:
		# Out of the factory door (the model's +Z side).
		spawn = producer.global_position + producer.global_basis.z * (float(producer.def["radius"]) + 2.5)
	spawn += Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
	var u := battlefield.spawn_unit(id, Battlefield.COALITION, spawn, deg_to_rad(-45.0))
	VFX.ground_ring(spawn, Color(0.5, 3, 1.2, 1), 2.5, 0.8)
	u.set_meta("reinforcement", true)
	u.order_move(rally[cat] + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))
	UnitVoice.alert("reinforcements", 6.0)
	unit_delivered.emit(u)


## Capture by presence: coalition troops alone push the bar up, Iranian
## troops alone push it down, contested derricks hold still.
func _update_derricks(dt: float) -> void:
	for i in derricks.size():
		var d := derricks[i]
		if not d["prop"]["alive"]:
			if d["owner"] != -1:
				d["owner"] = -1
				derrick_changed.emit(i, -1)
			continue
		var p := derrick_position(i)
		var near := [0, 0]
		for t in 2:
			for u: Unit in battlefield.units[t]:
				if is_instance_valid(u) and not u.is_air and not u.is_naval and u.global_position.distance_to(p) < CAPTURE_RADIUS:
					near[t] += 1
		var dir := 0.0
		if near[0] > 0 and near[1] == 0:
			dir = 1.0
		elif near[1] > 0 and near[0] == 0:
			dir = -1.0
		if dir == 0.0:
			continue
		d["capture"] = clampf(d["capture"] + dir * dt / CAPTURE_TIME, -1.0, 1.0)
		var holder: int = d["owner"]
		if d["capture"] >= 1.0:
			holder = Battlefield.COALITION
		elif d["capture"] <= -1.0:
			holder = Battlefield.IRAN
		elif (holder == Battlefield.COALITION and d["capture"] < 0.0) or (holder == Battlefield.IRAN and d["capture"] > 0.0):
			holder = -1
		if holder != d["owner"]:
			var was: int = d["owner"]
			d["owner"] = holder
			derrick_changed.emit(i, holder)
			if holder == Battlefield.COALITION:
				UnitVoice.alert("derrick", 2.0)
			elif was == Battlefield.COALITION:
				UnitVoice.alert("derrick_lost", 4.0)


# --- Base building ---------------------------------------------------------

func count_structures(id: String, team := Battlefield.COALITION) -> int:
	var n := 0
	for st in structures:
		if is_instance_valid(st) and st.is_alive() and st.team == team and st.unit_id == id:
			n += 1
	return n


func power_supply() -> int:
	var n := 0
	for st in structures:
		if is_instance_valid(st) and st.is_alive() and st.team == Battlefield.COALITION and int(st.def["power"]) > 0:
			n += int(st.def["power"])
	return n


func power_drain() -> int:
	var n := 0
	for st in structures:
		if is_instance_valid(st) and st.is_alive() and st.team == Battlefield.COALITION and int(st.def["power"]) < 0:
			n -= int(st.def["power"])
	return n


func low_power() -> bool:
	return base_mode and power_drain() > power_supply()


## Can this production line build right now? Always outside base mode.
func line_open(cat: String) -> bool:
	if not base_mode:
		return true
	if cat == "naval":
		return naval_in_base
	return producer_for(cat) != null


func producer_for(cat: String) -> Structure:
	if not base_mode:
		return null
	for st in structures:
		if is_instance_valid(st) and st.is_alive() and st.team == Battlefield.COALITION and st.def.get("produces", "") == cat:
			return st
	return null


## The first missing prerequisite for a structure, or "" when it can be built.
func missing_requirement(id: String) -> String:
	for req: String in BuildingDefs.get_def(id)["requires"]:
		if count_structures(req) == 0:
			return req
	return ""


func build_structure(id: String) -> bool:
	if not base_mode or structure_queue != "" or structure_ready != "" or missing_requirement(id) != "":
		Audio.play_ui("ui_error")
		return false
	var cost := float(BuildingDefs.get_def(id)["cost"])
	if credits < cost:
		Audio.play_ui("ui_error")
		UnitVoice.alert("insufficient", 3.0)
		return false
	credits -= cost
	credits_changed.emit(credits)
	structure_queue = id
	structure_progress = 0.0
	Audio.play_ui("ui_confirm")
	UnitVoice.alert("building", 1.5)
	return true


func cancel_structure(id: String) -> void:
	if structure_queue != id and structure_ready != id:
		return
	structure_queue = ""
	structure_ready = ""
	structure_progress = 0.0
	credits += float(BuildingDefs.get_def(id)["cost"])
	credits_changed.emit(credits)
	Audio.play_ui("ui_select")


## 0..1 build progress of a structure (1 when it is ready to place).
func structure_progress_of(id: String) -> float:
	if structure_ready == id:
		return 1.0
	if structure_queue != id:
		return 0.0
	return structure_progress / float(BuildingDefs.get_def(id)["build_time"])


func _update_structures(delta: float) -> void:
	if structure_queue != "" and structure_ready == "":
		structure_progress += delta
		if structure_progress >= float(BuildingDefs.get_def(structure_queue)["build_time"]):
			structure_ready = structure_queue
			structure_queue = ""
			structure_progress = 0.0
			UnitVoice.alert("structure_ready", 0.0)
			structure_finished.emit(structure_ready)
	var low := low_power()
	if low != _was_low_power:
		_was_low_power = low
		if low:
			UnitVoice.alert("low_power", 0.0)
		for st in structures:
			if is_instance_valid(st) and st.team == Battlefield.COALITION:
				st.powered = not low


## Why a structure cannot stand at p, or "" when it can.
func placement_problem(id: String, p: Vector3) -> String:
	var r: float = BuildingDefs.get_def(id)["radius"]
	var terrain: Terrain = battlefield.terrain
	var lo := INF
	var hi := -INF
	for k in 9:
		var q := p if k == 8 else p + Vector3(cos(TAU * k / 8.0), 0, sin(TAU * k / 8.0)) * r
		if not terrain.is_land(q):
			return "Needs dry land"
		var h := terrain.height_at(q)
		lo = minf(lo, h)
		hi = maxf(hi, h)
	if hi - lo > 2.2:
		return "Ground too steep"
	var near_base := false
	for st in structures:
		if not is_instance_valid(st) or not st.is_alive():
			continue
		var gap := Vector2(st.global_position.x - p.x, st.global_position.z - p.z).length() - float(st.def["radius"]) - r
		if gap < 1.0:
			return "Blocked by a structure"
		if gap <= BUILD_RANGE and st.team == Battlefield.COALITION:
			near_base = true
	if not near_base:
		return "Too far from the base"
	for prop in battlefield.props:
		var node = prop["node"]
		if not prop["alive"] or not is_instance_valid(node) or node is Structure:
			continue
		var c: Vector3 = (node as Node3D).global_position
		if Vector2(c.x - p.x, c.z - p.z).length() < r + float(prop["radius"]) * 0.8:
			return "Blocked"
	for t in 2:
		for u: Unit in battlefield.units[t]:
			if is_instance_valid(u) and not u.is_structure and not u.is_air and u.global_position.distance_to(p) < r + 0.5:
				return "Units in the way"
	return ""


## Put the ready structure down at p (the sidebar's placement mode calls this).
func place_ready(p: Vector3, yaw := 0.0) -> Structure:
	if structure_ready == "" or placement_problem(structure_ready, p) != "":
		Audio.play_ui("ui_error")
		return null
	var id := structure_ready
	structure_ready = ""
	Audio.play_ui("ui_confirm")
	return spawn_structure(id, Battlefield.COALITION, p, yaw, true)


## Create a structure for either side (missions use this for starting bases).
func spawn_structure(id: String, team: int, p: Vector3, yaw := 0.0, rise := false) -> Structure:
	var st := Structure.new()
	st.setup(id, team, battlefield)
	st.name = "%s_%d" % [id, st.get_instance_id()]
	st.rotation.y = yaw
	battlefield.add_child(st)
	p.y = battlefield.terrain.height_at(p)
	st.global_position = p
	battlefield.units[team].append(st)
	st.died.connect(battlefield._on_unit_died)
	st.destroyed.connect(func(_s: Structure) -> void:
		structures.erase(_s)
		if _s.team == Battlefield.COALITION:
			UnitVoice.alert("structure_lost", 4.0)
		_was_low_power = not low_power() # force a power refresh next tick
		structures_changed.emit())
	structures.append(st)
	st.powered = team != Battlefield.COALITION or not low_power()
	st.settle(rise)
	battlefield.unit_spawned.emit(st)
	_was_low_power = not low_power()
	structures_changed.emit()
	return st
