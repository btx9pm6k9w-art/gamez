extends Node
## Oil economy and reinforcements, C&C style.
##
## Oil derricks (the oil field's pumpjacks) are captured by standing next to
## them with no enemy nearby, and pay a steady income while held. Credits buy
## reinforcements from the sidebar: each production line (infantry, vehicle,
## naval) builds one unit at a time from its queue, and finished units arrive
## at the landing zone and head for the line's rally point. Cost is paid up
## front and refunded on cancel.

const UnitVoice := preload("res://scripts/audio/unit_voice.gd")

signal credits_changed(credits: float)
signal derrick_changed(index: int, holder: int)
signal unit_delivered(unit: Unit)

const START_CREDITS := 1500.0
const INCOME_PER_DERRICK := 8.0 # credits per second
const CAPTURE_RADIUS := 9.0
const CAPTURE_TIME := 5.0
const MAX_QUEUE := 6
const CATEGORIES := ["infantry", "vehicle", "naval"]

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
	return n * INCOME_PER_DERRICK


func owned_derricks(team := Battlefield.COALITION) -> int:
	var n := 0
	for d in derricks:
		if d["owner"] == team and d["prop"]["alive"]:
			n += 1
	return n


func derrick_position(i: int) -> Vector3:
	var node: Node3D = derricks[i]["prop"]["node"]
	return node.global_position if is_instance_valid(node) else Vector3.INF


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
	var def := UnitDefs.get_def(id)
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
	for cat: String in CATEGORIES:
		var q: Array = queues[cat]
		if q.is_empty():
			continue
		progress[cat] += delta
		if progress[cat] >= float(UnitDefs.get_def(q[0])["build_time"]):
			progress[cat] = 0.0
			_deliver(q.pop_front(), cat)


func _deliver(id: String, cat: String) -> void:
	var spawn := harbour_spawn if cat == "naval" else landing_zone
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
