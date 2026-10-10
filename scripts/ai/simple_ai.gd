class_name SimpleAI
extends Node
## Iranian forces (AI tier 2 "reactive"). The AI only knows what its own
## units have seen, plus who holds each oil derrick. It fights in groups that
## each have a role:
##   assault  gathers at a staging point out of sight, then attack-moves on the
##            player's last known position (or a derrick, or the beachhead).
##   flank    comes in from a second entry, waits at its own staging point and
##            joins in from the side once the assault is engaged.
##   raid     a small squad of defenders sent to retake a derrick.
##   defend   the garrison: holds posts, helps neighbours under fire, returns.
## A group that loses most of its strength falls back to its entry and its
## survivors join the next wave. Difficulty (0 easy, 1 normal, 2 hard) scales
## wave size, spacing and whether waves split into assault and flank. The
## mission can also order a counter-attack on a place the player just took.

signal wave_incoming(index: int, total: int)

const WAVES := [
	["karrar", "irgc", "irgc", "irgc_rpg"],
	["karrar", "karrar", "irgc", "irgc", "irgc_rpg", "irgc_rpg"],
	["karrar", "karrar", "karrar", "irgc", "irgc", "irgc", "irgc_rpg", "irgc_rpg"],
]
## Where waves can come from, with the name the HUD announces. Points that
## turn out to be off the land are skipped, so map edits cannot break waves.
const ENTRIES := [
	[Vector3(150, 0, 44), "the mountains to the north-east"],
	[Vector3(184, 0, 118), "the desert to the east"],
	[Vector3(112, 0, 8), "the ridge to the north"],
]
const BOAT_SWARM := [0, 3, 4] # fast boats added to each wave
const SEA_SPAWN := Vector3(12, 0, 4)
const HARBOUR := Vector3(32, 0, 168)
const BEACHHEAD := Vector3(62, 0, 160)
const FIRST_WAVE_DELAY := 70.0
const WAVE_INTERVAL := 75.0
## How long a sighting stays useful, in seconds.
const MEMORY := 30.0
## Staging distance short of the target, so groups arrive together.
const STAGE_DISTANCE := 42.0

var battlefield: Battlefield
## Economy node (scripts/game/economy.gd) when the mission has one; untyped so
## this script does not need to preload it.
var economy: Node
var difficulty := 1
var spawn_point := Vector3(150, 0, 44)
var waves_sent := 0
## Where the latest wave came from, for the HUD.
var last_wave_from := "the mountains"

## Each group: {"role", "units": Array[Unit], "phase": "stage"|"attack"|"retreat",
## "stage": Vector3, "target": Vector3, "home": Vector3, "timer": float,
## "start": int (size at creation), "partner": Dictionary (flank's assault)}
var groups: Array[Dictionary] = []
## Player units the AI has seen: instance id -> {"pos": Vector3, "time": float}
var _sightings := {}

var _wave_timer := FIRST_WAVE_DELAY
var _think_timer := 1.0
var _raid_timer := 45.0
var _leftovers: Array[Unit] = []


func waves_remaining() -> int:
	return WAVES.size() - waves_sent


func _process(delta: float) -> void:
	if battlefield == null:
		return
	_wave_timer -= delta
	if _wave_timer <= 0.0 and waves_sent < WAVES.size():
		_send_wave()
		_wave_timer = WAVE_INTERVAL * [1.35, 1.0, 0.8][difficulty]
	_raid_timer -= delta
	if _raid_timer <= 0.0:
		_raid_timer = [90.0, 60.0, 40.0][difficulty]
		_raid_derrick()
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = 1.0
		_spot()
		_run_groups(1.0)
		_garrison()


# --- Knowledge ------------------------------------------------------------

## Record every player unit inside the sight of any Iranian unit.
func _spot() -> void:
	var now := _now()
	var eyes: Array = battlefield.units[Battlefield.IRAN]
	for u: Unit in battlefield.units[Battlefield.COALITION]:
		if not is_instance_valid(u) or not u.is_alive():
			continue
		for e: Unit in eyes:
			if is_instance_valid(e) and e.is_alive() and e.global_position.distance_to(u.global_position) <= float(e.def["vision"]):
				_sightings[u.get_instance_id()] = {"pos": u.global_position, "time": now, "naval": u.is_naval}
				break
	for id in _sightings.keys():
		if now - float(_sightings[id]["time"]) > MEMORY * 2.0:
			_sightings.erase(id)


## Best place to attack from where: the freshest known land force near
## `from`, else a derrick the player holds, else the beachhead.
func _pick_target(from: Vector3) -> Vector3:
	var now := _now()
	var best := Vector3.INF
	var best_score := INF
	for id in _sightings:
		var s: Dictionary = _sightings[id]
		if s["naval"] or now - float(s["time"]) > MEMORY:
			continue
		var p: Vector3 = s["pos"]
		var score := p.distance_to(from) + (now - float(s["time"])) * 2.0
		if score < best_score:
			best_score = score
			best = p
	if best != Vector3.INF:
		return best
	var d := _player_derrick(from)
	return d if d != Vector3.INF else BEACHHEAD


func _player_derrick(from: Vector3) -> Vector3:
	if economy == null:
		return Vector3.INF
	var best := Vector3.INF
	for i in economy.derricks.size():
		if economy.derricks[i]["owner"] == Battlefield.COALITION:
			var p: Vector3 = economy.derrick_position(i)
			if p != Vector3.INF and (best == Vector3.INF or p.distance_to(from) < best.distance_to(from)):
				best = p
	return best


# --- Waves and groups -----------------------------------------------------

func _send_wave() -> void:
	var wave: Array = WAVES[waves_sent].duplicate()
	if difficulty == 0:
		wave.resize(maxi(wave.size() - 2, 2))
	elif difficulty == 2:
		wave.append_array(["karrar", "irgc", "irgc"])
	waves_sent += 1
	var entries := _land_entries()
	var main: Array = entries[(waves_sent - 1) % entries.size()]
	var side: Array = entries[waves_sent % entries.size()]
	# From Veteran up, a third of each wave flanks from another entry.
	var flank_count := 0 if difficulty == 0 or entries.size() < 2 or wave.size() < 4 else wave.size() / 3
	last_wave_from = main[1] if flank_count == 0 else "%s and %s" % [main[1], side[1]]
	wave_incoming.emit(waves_sent, WAVES.size())

	var assault_units: Array[Unit] = []
	var flank_units: Array[Unit] = []
	for i in wave.size():
		var to_flank := i >= wave.size() - flank_count
		var entry: Vector3 = side[0] if to_flank else main[0]
		var k := i if not to_flank else i - (wave.size() - flank_count)
		var p := entry + Vector3((k % 4) * 4.0 - 6.0, 0, (k / 4) * 5.0)
		var u := battlefield.spawn_unit(wave[i], Battlefield.IRAN, p, PI * 0.75)
		u.set_meta("wave", true)
		(flank_units if to_flank else assault_units).append(u)
	# Survivors of beaten groups regroup into the new assault.
	for u in _leftovers:
		if is_instance_valid(u) and u.is_alive():
			assault_units.append(u)
	_leftovers.clear()
	var assault := _make_group("assault", assault_units, main[0])
	if not flank_units.is_empty():
		var flank := _make_group("flank", flank_units, side[0])
		flank["partner"] = assault
	for i in BOAT_SWARM[waves_sent - 1] + (1 if difficulty == 2 else 0):
		var p := SEA_SPAWN + Vector3(i * 5.0, 0, -i * 2.0)
		var b := battlefield.spawn_unit("fast_boat", Battlefield.IRAN, p, PI)
		b.set_meta("wave", true)
		b.order_move(HARBOUR + Vector3(randf_range(-4, 4), 0, randf_range(-6, 6)), true)


func _make_group(role: String, units: Array[Unit], home: Vector3) -> Dictionary:
	var target := _pick_target(home)
	var g := {"role": role, "units": units, "phase": "stage", "home": home, "target": target,
		"stage": _stage_point(home, target, role == "flank"), "timer": 0.0, "start": units.size(), "partner": {}}
	groups.append(g)
	_order_group(g, g["stage"], false)
	return g


## A point short of the target on the way from home; flankers stage off to
## the side so they hit from a different angle.
func _stage_point(home: Vector3, target: Vector3, side: bool) -> Vector3:
	var dir := (target - home)
	dir.y = 0.0
	var dist := dir.length()
	if dist < 1.0:
		return target
	dir /= dist
	var p := target - dir * minf(STAGE_DISTANCE, dist * 0.6)
	if side:
		p += Vector3(-dir.z, 0, dir.x) * 28.0
	p = battlefield.terrain.clamp_to_map(p, 6.0)
	return p if battlefield.terrain.is_land(p) else target - dir * minf(STAGE_DISTANCE, dist * 0.6)


func _order_group(g: Dictionary, p: Vector3, attack: bool) -> void:
	var units: Array = g["units"]
	for i in units.size():
		var u: Unit = units[i]
		var off := Vector3((i % 4) * 3.5 - 5.0, 0, (i / 4) * 3.5 - 3.0)
		u.order_move(p + off, attack)


func _alive(g: Dictionary) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in g["units"]: # untyped: a freed unit cannot be assigned to a typed variable
		if is_instance_valid(u) and u.is_alive():
			out.append(u)
	g["units"] = out
	return out


func _center(units: Array[Unit]) -> Vector3:
	var sum := Vector3.ZERO
	for u in units:
		sum += u.global_position
	return sum / maxi(units.size(), 1)


func _engaged(units: Array[Unit]) -> bool:
	for u in units:
		if u.target != null or _now() - u.last_hit_time < 3.0:
			return true
	return false


func _run_groups(dt: float) -> void:
	for g in groups.duplicate():
		var units := _alive(g)
		if units.is_empty():
			groups.erase(g)
			continue
		g["timer"] = float(g["timer"]) + dt
		var c := _center(units)
		match g["phase"]:
			"stage":
				var arrived := 0
				for u in units:
					if u.global_position.distance_to(g["stage"]) < 12.0:
						arrived += 1
				var go := arrived >= ceili(units.size() * 0.7) or float(g["timer"]) > 35.0 or _engaged(units)
				if g["role"] == "flank":
					# Flankers wait for the assault to hit first.
					var partner: Dictionary = g["partner"]
					var partner_busy: bool = partner.is_empty() or partner["phase"] != "stage" or partner["units"].is_empty()
					go = (go and partner_busy) or float(g["timer"]) > 60.0 or _engaged(units)
				if go:
					g["phase"] = "attack"
					g["target"] = _pick_target(c)
					_order_group(g, g["target"], true)
			"attack":
				# Losing badly: fall back and join the next wave.
				# Groups smaller than three fight to the end.
				if int(g["start"]) >= 3 and units.size() <= int(g["start"]) * 0.35 and g["role"] != "raid":
					g["phase"] = "retreat"
					_order_group(g, g["home"], false)
					continue
				# Target reached and nothing in sight: look for the next one.
				var idle := 0
				for u in units:
					# Units that cannot squeeze onto the exact spot stay in their move
					# state for ever, so being close with nothing to shoot counts too.
					if u.target == null and (u.state == Unit.State.IDLE or u.global_position.distance_to(g["target"]) < 14.0):
						idle += 1
				if idle == units.size():
					# Whatever was seen here has gone: forget it so the group
					# moves on instead of re-ordering itself to the same spot.
					for id in _sightings.keys():
						if (_sightings[id]["pos"] as Vector3).distance_to(c) < 20.0:
							_sightings.erase(id)
					g["target"] = _pick_target(c)
					_order_group(g, g["target"], true)
			"retreat":
				if c.distance_to(g["home"]) < 15.0:
					groups.erase(g)
					for u in units:
						u.set_meta("wave", true)
						_leftovers.append(u)


## True when vehicles can drive from `from` to the beachhead. An entry on an
## isolated patch of navmesh would leave its wave standing where it spawned.
func _reaches_beachhead(from: Vector3) -> bool:
	var map := battlefield.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return true # navmesh not baked yet: do not rule anything out
	var a := Vector3(from.x, battlefield.terrain.height_at(from), from.z)
	var b := Vector3(BEACHHEAD.x, battlefield.terrain.height_at(BEACHHEAD), BEACHHEAD.z)
	var path := NavigationServer3D.map_get_path(map, a, b, true, Battlefield.NAV_LAYER_VEHICLE)
	return not path.is_empty() and Vector2(path[path.size() - 1].x - b.x, path[path.size() - 1].z - b.z).length() < 20.0


func _land_entries() -> Array:
	var out := []
	for e: Array in ENTRIES:
		if battlefield.terrain.is_land(e[0]) and _reaches_beachhead(e[0]):
			out.append(e)
	if out.is_empty():
		out.append([spawn_point, "the mountains"])
	return out


## Send a strike group from the mountains at a place the player just took.
func counter_attack(target: Vector3, size: int) -> void:
	var kinds := ["karrar", "irgc", "irgc_rpg", "irgc"]
	var units: Array[Unit] = []
	for i in size:
		var p := spawn_point + Vector3((i % 4) * 4.0 - 6.0, 0, (i / 4) * 5.0)
		var u := battlefield.spawn_unit(kinds[i % kinds.size()], Battlefield.IRAN, p, PI * 0.75)
		u.set_meta("wave", true)
		units.append(u)
	var g := {"role": "assault", "units": units, "phase": "stage", "home": spawn_point, "target": target,
		"stage": _stage_point(spawn_point, target, false), "timer": 0.0, "start": units.size(), "partner": {}}
	groups.append(g)
	_order_group(g, g["stage"], false)


## Pull a few idle defenders together and send them to retake the nearest
## derrick the player holds.
func _raid_derrick() -> void:
	var best := _player_derrick(spawn_point)
	if best == Vector3.INF:
		return
	var squad: Array[Unit] = []
	for u: Unit in battlefield.units[Battlefield.IRAN]:
		if squad.size() >= 2 + difficulty:
			break
		if not is_instance_valid(u) or u.is_air or u.is_naval or u.unit_id == "shahed_launcher" or _in_group(u):
			continue
		if u.state == Unit.State.IDLE and u.target == null:
			squad.append(u)
	if squad.size() < 2:
		return
	var g := {"role": "raid", "units": squad, "phase": "attack", "home": _center(squad), "target": best,
		"stage": best, "timer": 0.0, "start": squad.size(), "partner": {}}
	groups.append(g)
	_order_group(g, best, true)


func _in_group(u: Unit) -> bool:
	for g in groups:
		if u in g["units"]:
			return true
	return false


## Garrison: defenders not in a group help any neighbour hit in the last few
## seconds within 30 m (the AI hears the shooting), then hold where they are;
## boats from waves keep pressing the harbour.
func _garrison() -> void:
	var now := _now()
	var hit: Array[Unit] = []
	for u: Unit in battlefield.units[Battlefield.IRAN]:
		if is_instance_valid(u) and u.is_alive() and now - u.last_hit_time < 3.0:
			hit.append(u)
	for u: Unit in battlefield.units[Battlefield.IRAN]:
		if not is_instance_valid(u) or u.is_air or u.unit_id == "shahed_launcher":
			continue
		if u.state != Unit.State.IDLE or u.target != null or _in_group(u):
			continue
		if u.is_naval:
			if now - u.last_hit_time < 3.0 or u.has_meta("wave"):
				u.order_move(HARBOUR + Vector3(randf_range(-6, 6), 0, randf_range(-8, 8)), true)
			continue
		for h in hit:
			if h != u and h.global_position.distance_to(u.global_position) < 30.0:
				u.order_move(h.global_position + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)), true)
				break


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
