class_name SimpleAI
extends Node
## Iranian forces for the prototype (AI tier 2 "reactive"): defenders hold
## positions and counter-attack when hit, reinforcement waves arrive from the
## mountain base, drone launchers keep up harassment, and from the second
## wave a swarm of fast attack craft races down the coast at the harbour.
## Difficulty (0 easy, 1 normal, 2 hard) scales wave size and spacing. The AI
## also counter-attacks places the player has just taken (missions call
## counter_attack) and sends squads to retake oil derricks the player holds.

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
const FIRST_WAVE_DELAY := 70.0
const WAVE_INTERVAL := 75.0

var battlefield: Battlefield
## Economy node (scripts/game/economy.gd) when the mission has one; untyped so
## this script does not need to preload it.
var economy: Node
var difficulty := 1
var spawn_point := Vector3(150, 0, 44)
var waves_sent := 0
## Where the latest wave came from, for the HUD.
var last_wave_from := "the mountains"

var _wave_timer := FIRST_WAVE_DELAY
var _think_timer := 1.0
var _raid_timer := 45.0


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
		_think()


func _send_wave() -> void:
	var wave: Array = WAVES[waves_sent].duplicate()
	if difficulty == 0:
		wave.resize(maxi(wave.size() - 2, 2))
	elif difficulty == 2:
		wave.append_array(["karrar", "irgc", "irgc"])
	waves_sent += 1
	# Waves rotate between entry points; on Elite each wave splits in two
	# and hits from two sides at once.
	var entries := _land_entries()
	var first: Array = entries[(waves_sent - 1) % entries.size()]
	var second: Array = entries[waves_sent % entries.size()] if difficulty == 2 and entries.size() > 1 else first
	last_wave_from = first[1] if second == first else "%s and %s" % [first[1], second[1]]
	wave_incoming.emit(waves_sent, WAVES.size())
	var target := _player_center()
	for i in wave.size():
		var entry: Vector3 = first[0] if i % 2 == 0 else second[0]
		var p := entry + Vector3((i % 4) * 4.0 - 6.0, 0, (i / 4) * 5.0)
		var u := battlefield.spawn_unit(wave[i], Battlefield.IRAN, p, PI * 0.75)
		u.set_meta("wave", true)
		u.order_move(target, true)
	for i in BOAT_SWARM[waves_sent - 1] + (1 if difficulty == 2 else 0):
		var p := SEA_SPAWN + Vector3(i * 5.0, 0, -i * 2.0)
		var b := battlefield.spawn_unit("fast_boat", Battlefield.IRAN, p, PI)
		b.set_meta("wave", true)
		b.order_move(HARBOUR + Vector3(randf_range(-4, 4), 0, randf_range(-6, 6)), true)


func _land_entries() -> Array:
	var out := []
	for e: Array in ENTRIES:
		if battlefield.terrain.is_land(e[0]):
			out.append(e)
	if out.is_empty():
		out.append([spawn_point, "the mountains"])
	return out


## Send a strike group from the mountains at a place the player just took.
func counter_attack(target: Vector3, size: int) -> void:
	var kinds := ["karrar", "irgc", "irgc_rpg", "irgc"]
	for i in size:
		var p := spawn_point + Vector3((i % 4) * 4.0 - 6.0, 0, (i / 4) * 5.0)
		var u := battlefield.spawn_unit(kinds[i % kinds.size()], Battlefield.IRAN, p, PI * 0.75)
		u.set_meta("wave", true)
		u.order_move(target + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)), true)


## Pull a few idle defenders together and send them to the nearest derrick
## the player holds.
func _raid_derrick() -> void:
	if economy == null:
		return
	var best := Vector3.INF
	for i in economy.derricks.size():
		if economy.derricks[i]["owner"] == Battlefield.COALITION:
			var p: Vector3 = economy.derrick_position(i)
			if p != Vector3.INF and (best == Vector3.INF or p.distance_to(spawn_point) < best.distance_to(spawn_point)):
				best = p
	if best == Vector3.INF:
		return
	var squad := 0
	for u: Unit in battlefield.units[Battlefield.IRAN]:
		if squad >= 2 + difficulty:
			break
		if not is_instance_valid(u) or u.is_air or u.is_naval or u.unit_id == "shahed_launcher":
			continue
		if u.state == Unit.State.IDLE and u.target == null:
			if u.has_meta("wave"):
				u.remove_meta("wave")
			u.order_move(best + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), true)
			squad += 1


func _player_center() -> Vector3:
	var own: Array = battlefield.units[Battlefield.COALITION]
	var sum := Vector3.ZERO
	var n := 0
	for u: Unit in own:
		if is_instance_valid(u) and not u.is_air and not u.is_naval:
			sum += u.global_position
			n += 1
	return sum / n if n > 0 else Vector3(64, 0, 160)


## Defenders that were hit recently counter-attack their attacker's area;
## idle wave units keep pushing toward the player's army.
func _think() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var center := _player_center()
	for u: Unit in battlefield.units[Battlefield.IRAN]:
		if not is_instance_valid(u) or u.is_air or u.unit_id == "shahed_launcher":
			continue
		if u.state != Unit.State.IDLE or u.target != null:
			continue
		if u.is_naval:
			if now - u.last_hit_time < 3.0 or u.has_meta("wave"):
				u.order_move(HARBOUR + Vector3(randf_range(-6, 6), 0, randf_range(-8, 8)), true)
			continue
		if now - u.last_hit_time < 3.0 or u.has_meta("wave"):
			u.order_move(center + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), true)
