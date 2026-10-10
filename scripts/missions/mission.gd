extends Node
## Base class for a mission: briefing text, a list of objectives, and the
## checks that complete or fail them. A mission subclass fills in briefing()
## and objectives in _setup(), and moves objectives along in _evaluate().
##
## Objective kinds used by the campaign (see docs/DESIGN.md, "Campaign"):
## capture (clear and hold a zone), destroy (a set of targets), defend (keep
## something alive or survive a timer), escort (a unit reaches a point) and
## secure (hold resource points). Primary objectives win the mission; bonus
## objectives only add to the debrief.

const UnitVoice := preload("res://scripts/audio/unit_voice.gd")
const Economy := preload("res://scripts/game/economy.gd")

signal objectives_changed
signal objective_completed(text: String)
signal objective_added(text: String)
signal mission_ended(won: bool, summary: String)

enum State { HIDDEN, ACTIVE, DONE, FAILED }

var battlefield: Battlefield
var economy: Economy
var ai: SimpleAI
var hud: HUD
var difficulty := 1 # 0 easy, 1 normal, 2 hard
var objectives: Array[Dictionary] = []
var elapsed := 0.0
var ended := false
var kills := 0
var losses := 0

var _eval_timer := 0.0


## {title, subtitle, place, time, situation: Array[String], difficulty_note}
func briefing() -> Dictionary:
	return {}


func start(bf: Battlefield, eco: Economy, p_ai: SimpleAI, p_hud: HUD) -> void:
	battlefield = bf
	economy = eco
	ai = p_ai
	hud = p_hud
	battlefield.unit_killed.connect(_on_unit_killed)
	_setup()
	objectives_changed.emit()


## Spawn forces and declare objectives; called once when play begins.
func _setup() -> void:
	_declare_objectives()


## add_objective() calls only, so the briefing can list them before play.
func _declare_objectives() -> void:
	pass


func preview_objectives() -> Array[Dictionary]:
	_declare_objectives()
	var out: Array[Dictionary] = []
	out.assign(objectives.duplicate(true))
	objectives.clear()
	return out


func _evaluate(_dt: float) -> void:
	pass


func add_objective(id: String, text: String, primary := true, visible := true) -> void:
	objectives.append({"id": id, "text": text, "primary": primary,
		"state": State.ACTIVE if visible else State.HIDDEN, "progress": ""})


func objective(id: String) -> Dictionary:
	for o in objectives:
		if o["id"] == id:
			return o
	return {}


func is_active(id: String) -> bool:
	return objective(id).get("state", State.HIDDEN) == State.ACTIVE


func reveal(id: String) -> void:
	var o := objective(id)
	if o.is_empty() or o["state"] != State.HIDDEN:
		return
	o["state"] = State.ACTIVE
	objective_added.emit(o["text"])
	UnitVoice.alert("objective_new", 0.0)
	objectives_changed.emit()


func complete(id: String) -> void:
	var o := objective(id)
	if o.is_empty() or o["state"] != State.ACTIVE:
		return
	o["state"] = State.DONE
	o["progress"] = ""
	objective_completed.emit(o["text"])
	UnitVoice.alert("objective", 0.0)
	Audio.play_ui("ui_confirm")
	objectives_changed.emit()


func fail(id: String) -> void:
	var o := objective(id)
	if o.is_empty() or o["state"] != State.ACTIVE:
		return
	o["state"] = State.FAILED
	UnitVoice.alert("objective_failed", 0.0)
	objectives_changed.emit()
	if o["primary"]:
		end(false, "Primary objective failed: %s" % o["text"])


func set_progress(id: String, text: String) -> void:
	var o := objective(id)
	if not o.is_empty() and o["progress"] != text:
		o["progress"] = text
		objectives_changed.emit()


func end(won: bool, reason := "") -> void:
	if ended:
		return
	ended = true
	var bonus_done := 0
	var bonus_total := 0
	for o in objectives:
		if not o["primary"]:
			bonus_total += 1
			if o["state"] == State.DONE or (won and o["state"] == State.ACTIVE and o.get("done_on_win", false)):
				if o["state"] == State.ACTIVE:
					o["state"] = State.DONE
				bonus_done += 1
	var mins := int(elapsed) / 60
	var secs := int(elapsed) % 60
	var summary := "%s\nTime %d:%02d   Enemies destroyed %d   Units lost %d   Bonus objectives %d of %d" % [
		reason, mins, secs, kills, losses, bonus_done, bonus_total]
	UnitVoice.alert("mission_won" if won else "mission_lost", 0.0)
	objectives_changed.emit()
	mission_ended.emit(won, summary)


func _process(delta: float) -> void:
	if battlefield == null or ended:
		return
	elapsed += delta
	_eval_timer -= delta
	if _eval_timer <= 0.0:
		_eval_timer = 0.25
		_evaluate(0.25)
		_check_primary()


func _check_primary() -> void:
	if ended:
		return
	for o in objectives:
		# "Keep X" objectives (done_on_win) count as met while they hold.
		if o["primary"] and o["state"] != State.DONE and not (o["state"] == State.ACTIVE and o.get("done_on_win", false)):
			return
	end(true, "All primary objectives complete.")


func _on_unit_killed(u: Unit) -> void:
	if u.team == Battlefield.COALITION:
		losses += 1
	else:
		kills += 1


# --- Helpers for subclasses ------------------------------------------------

## Helpers count troops only, never base structures.
func count_near(team: int, p: Vector3, radius: float, ground_only := true) -> int:
	var n := 0
	for u: Unit in battlefield.units[team]:
		if not is_instance_valid(u) or not u.is_alive():
			continue
		if u.is_structure or (ground_only and (u.is_air or u.is_naval)):
			continue
		if Vector2(u.global_position.x - p.x, u.global_position.z - p.z).length() < radius:
			n += 1
	return n


func count_units(team: int, id := "", ground_only := true) -> int:
	var n := 0
	for u: Unit in battlefield.units[team]:
		if not is_instance_valid(u) or not u.is_alive():
			continue
		if u.is_structure or (ground_only and (u.is_air or u.is_naval)):
			continue
		if id == "" or u.unit_id == id:
			n += 1
	return n
