class_name Unit
extends Node3D
## A ground, air or naval unit: movement on the navigation mesh with local
## avoidance (boats steer around the coast on their own), auto-targeting,
## turret aim, weapons and death effects.

signal died(unit: Unit)

enum State { IDLE, MOVE, ATTACK, ATTACK_MOVE }

var unit_id := ""
var def := {}
var team := 0
var faction := ""
var battlefield: Node # Battlefield; untyped to avoid a cyclic class reference
var hp := 100.0
var max_hp := 100.0
var is_air := false
var is_naval := false
var state := State.IDLE
var target: Unit
var move_goal := Vector3.ZERO
var ground_target := Vector3.INF # for drones
var selected := false: set = _set_selected
var last_hit_time := -100.0
## Shift-queued waypoints: each entry is [position, attack_move].
var waypoints: Array = []
## Patrol: the two ends the unit attack-moves between.
var patrol := false
var _patrol_a := Vector3.ZERO
var _patrol_b := Vector3.ZERO
## Hold position: fire at anything in range but never move to chase.
var hold := false
## Where an idle unit was standing before it went after an attacker.
var _guard_post := Vector3.INF

var model: Node3D
var turret: Node3D
var muzzle: Node3D
var legs: Node3D
var agent: NavigationAgent3D

var _ring: MeshInstance3D
var _velocity := Vector3.ZERO
var _desired := Vector3.ZERO
var _cooldown := 0.0
var _scan_timer := 0.0
var _repath_timer := 0.0
var _anim_t := 0.0
var _yaw := 0.0
var _alive := true
var _trail: GPUParticles3D
var _engine: AudioStreamPlayer3D
var _engine_retry := 0.0
var _wake: GPUParticles3D
var _bob_phase := randf() * TAU
var _roll := 0.0


func setup(id: String, p_team: int, bf: Node) -> void:
	unit_id = id
	def = UnitDefs.get_def(id)
	team = p_team
	faction = def["faction"]
	battlefield = bf
	max_hp = def["hp"]
	hp = max_hp
	is_air = def.get("air", false)
	is_naval = def.get("naval", false)
	_cooldown = randf() * float(def["cooldown"])
	_scan_timer = randf() * 0.3


func _ready() -> void:
	add_to_group("units")
	add_to_group("team_%d" % team)
	model = UnitModels.build(def["model"], faction)
	add_child(model)
	turret = model.find_child("Turret", true, false) as Node3D
	muzzle = model.find_child("Muzzle", true, false) as Node3D
	legs = model.find_child("Legs", true, false) as Node3D
	_yaw = rotation.y
	rotation = Vector3.ZERO

	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	var r: float = def["radius"]
	torus.inner_radius = r * 1.15
	torus.outer_radius = r * 1.15 + 0.12
	torus.rings = 32
	torus.ring_segments = 4
	_ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(0.4, 2.0, 0.8) if team == 0 else Color(2.0, 0.4, 0.3)
	_ring.material_override = rm
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position.y = 0.15
	_ring.visible = false
	add_child(_ring)

	if is_air:
		_trail = VFX.make_trail()
		add_child(_trail)
		var engine := model.find_child("Engine", true, false) as Node3D
		if engine:
			_trail.position = engine.position
		_trail.emitting = true
	elif is_naval:
		_wake = VFX.make_wake(r * 0.6)
		var stern := model.find_child("Wake", true, false) as Node3D
		if stern:
			_wake.position = stern.position
		add_child(_wake)
		_wake.emitting = true
	else:
		agent = NavigationAgent3D.new()
		agent.radius = r
		agent.height = 2.0
		agent.max_speed = def["speed"]
		agent.path_desired_distance = 1.2
		agent.target_desired_distance = maxf(1.0, r)
		agent.avoidance_enabled = true
		agent.neighbor_distance = 12.0
		agent.max_neighbors = 12
		agent.time_horizon_agents = 1.2
		agent.velocity_computed.connect(_on_velocity_computed)
		add_child(agent)


func _set_selected(v: bool) -> void:
	selected = v
	if _ring:
		_ring.visible = v


func display_name() -> String:
	return def["display"]


func aim_point() -> Vector3:
	return global_position + Vector3.UP * (0.4 if is_air else (1.4 if def["radius"] > 1.0 else 1.1))


func is_alive() -> bool:
	return _alive


# --- Orders ---------------------------------------------------------------

func order_move(pos: Vector3, attack_move := false, queue := false) -> void:
	if is_air:
		return
	if queue and (state != State.IDLE or not waypoints.is_empty()):
		waypoints.append([pos, attack_move])
		return
	waypoints.clear()
	patrol = false
	hold = false
	_guard_post = Vector3.INF
	_go(pos, attack_move)


func _go(pos: Vector3, attack_move: bool) -> void:
	move_goal = pos
	target = null
	state = State.ATTACK_MOVE if attack_move else State.MOVE
	if agent:
		agent.target_position = pos


## Patrol between here and pos, attacking anything met on the way.
func order_patrol(pos: Vector3) -> void:
	if is_air:
		return
	order_move(pos, true)
	patrol = true
	_patrol_a = global_position
	_patrol_b = pos


func order_attack(t: Unit, queue := false) -> void:
	if t == null or t.team == team or not _can_target(t):
		return
	if not queue:
		waypoints.clear()
		patrol = false
	hold = false
	_guard_post = Vector3.INF
	target = t
	state = State.ATTACK
	_repath_timer = 0.0


func order_stop() -> void:
	state = State.IDLE
	target = null
	waypoints.clear()
	patrol = false
	hold = false
	_guard_post = Vector3.INF
	if agent:
		agent.target_position = global_position


func order_hold() -> void:
	order_stop()
	hold = true


## Called when a move leg ends: take the next queued waypoint, turn round on
## patrol, walk back to the guard post, or go idle.
func _next_leg() -> void:
	if not waypoints.is_empty():
		var w: Array = waypoints.pop_front()
		_go(w[0], w[1])
	elif patrol:
		var back := _patrol_a if move_goal.distance_to(_patrol_b) < 1.0 else _patrol_b
		_go(back, true)
	else:
		state = State.IDLE
		_guard_post = Vector3.INF


## Drones fly to a point and detonate.
func order_strike(pos: Vector3) -> void:
	ground_target = pos
	state = State.MOVE


# --- Simulation -----------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _alive:
		return
	_cooldown -= delta
	_scan_timer -= delta
	if is_air:
		_process_drone(delta)
		return
	if is_naval:
		_process_boat(delta)
		return

	if target != null and (not is_instance_valid(target) or not target.is_alive()):
		target = null
		if state == State.ATTACK:
			if waypoints.is_empty() and not patrol:
				state = State.IDLE
			else:
				_next_leg()
		elif state == State.ATTACK_MOVE:
			agent.target_position = move_goal

	if _scan_timer <= 0.0:
		_scan_timer = 0.3
		_auto_target()

	_desired = Vector3.ZERO
	match state:
		State.MOVE, State.ATTACK_MOVE:
			if target != null and state == State.ATTACK_MOVE:
				_engage(delta)
			elif agent.is_navigation_finished():
				_next_leg()
			else:
				_desired = _steer_to(agent.get_next_path_position())
		State.ATTACK:
			_engage(delta)
		State.IDLE:
			if target != null:
				if not hold and global_position.distance_to(target.global_position) > range_to(target):
					# Classic guard behaviour: go after an enemy that is in sight
					# but out of range, then walk back to where we stood.
					var t := target
					_guard_post = global_position
					_go(_guard_post, true)
					target = t
				else:
					_aim_and_fire(delta)
	if state == State.IDLE and target == null and turret:
		turret.rotation.y = lerp_angle(turret.rotation.y, 0.0, delta)

	agent.velocity = _desired


func _steer_to(p: Vector3) -> Vector3:
	var to := p - global_position
	to.y = 0.0
	if to.length() < 0.05:
		return Vector3.ZERO
	var terrain: Terrain = battlefield.terrain
	var slope := terrain.slope_at(global_position)
	var speed: float = float(def["speed"]) * clampf(1.0 - slope * 1.6, 0.35, 1.0) * terrain.ground_speed_factor(global_position)
	return to.normalized() * speed


# --- Boats ----------------------------------------------------------------

## Boats steer straight for their goal and feel ahead for the coastline,
## swinging left or right until the way is clear. In combat they keep moving
## and circle the target, like real fast-attack craft.
func _process_boat(delta: float) -> void:
	if target != null and (not is_instance_valid(target) or not target.is_alive()):
		target = null
		if state == State.ATTACK:
			_next_leg()
	if _scan_timer <= 0.0:
		_scan_timer = 0.3
		_auto_target()
	var goal := Vector3.INF
	match state:
		State.MOVE:
			goal = move_goal
		State.ATTACK_MOVE:
			goal = move_goal if target == null else _orbit_point()
		State.ATTACK:
			goal = _orbit_point()
	if target != null and global_position.distance_to(target.global_position) <= float(def["range"]):
		_aim_and_fire(delta)
	var want := Vector3.ZERO
	if goal != Vector3.INF:
		var to := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z)
		if to.length() < 3.0 and (state == State.MOVE or (state == State.ATTACK_MOVE and target == null)):
			_next_leg()
		elif to.length() > 0.5:
			want = _clear_heading(to.normalized()) * float(def["speed"])
	# Keep clear of other boats.
	for t in 2:
		for other: Unit in battlefield.units[t]:
			if other == self or not other.is_naval or not is_instance_valid(other):
				continue
			var d := global_position - other.global_position
			d.y = 0.0
			var min_d: float = def["radius"] + other.def["radius"] + 1.0
			if d.length() < min_d and d.length() > 0.01:
				want += d.normalized() * (min_d - d.length()) * 3.0
	var accel := 4.0 if want.length() > _velocity.length() else 2.5
	_velocity = _velocity.move_toward(want, accel * delta)


func _orbit_point() -> Vector3:
	if target == null:
		return global_position
	var to := target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var r: float = float(def["range"]) * 0.75
	if dist > r * 1.3:
		return target.global_position
	var side := Vector3(-to.z, 0, to.x).normalized() * (1.0 if get_instance_id() % 2 == 0 else -1.0)
	return global_position + side * 12.0 - to.normalized() * (r - dist)


func _clear_heading(dir: Vector3) -> Vector3:
	var terrain: Terrain = battlefield.terrain
	var look := 4.0 + _velocity.length() * 0.8 + float(def["radius"])
	for a in [0.0, 0.4, -0.4, 0.8, -0.8, 1.3, -1.3, 2.0, -2.0, PI]:
		var d := dir.rotated(Vector3.UP, a)
		var probe := global_position + d * look
		var mid := global_position + d * look * 0.5
		if not terrain.is_land(probe) and not terrain.is_land(mid) and probe == terrain.clamp_to_map(probe, 3.0):
			return d
	return -dir


func _process_boat_visual(delta: float) -> void:
	var terrain: Terrain = battlefield.terrain
	var v := _velocity
	var speed := v.length()
	var next := global_position + v * delta
	if terrain.is_land(next) or next != terrain.clamp_to_map(next, 2.0):
		_velocity *= -0.2
	else:
		global_position = next
	var turn := 0.0
	if speed > 0.5:
		var desired_yaw := atan2(-v.x, -v.z)
		turn = angle_difference(_yaw, desired_yaw)
		_yaw = lerp_angle(_yaw, desired_yaw, clampf(delta * 2.2, 0.0, 1.0))
	var k := speed / float(def["speed"])
	_roll = lerpf(_roll, clampf(-turn * 0.5, -0.25, 0.25) * k, clampf(delta * 3.0, 0.0, 1.0))
	var t := Time.get_ticks_msec() / 1000.0
	var pitch := k * 0.08 + sin(t * 1.9 + _bob_phase) * 0.025
	global_position.y = Terrain.WATER_LEVEL + sin(t * 1.4 + _bob_phase) * 0.12 + k * 0.15
	basis = Basis.from_euler(Vector3(pitch, _yaw, _roll + sin(t * 1.1 + _bob_phase) * 0.03))
	if _wake:
		_wake.amount_ratio = clampf(k * 1.2, 0.05, 1.0)


## Weapon range, extended by up to 25% when firing down from high ground.
func range_to(t: Unit) -> float:
	var up := global_position.y - t.global_position.y
	return float(def["range"]) * (1.0 + clampf(up * 0.03, 0.0, 0.25))


func _engage(delta: float) -> void:
	var dist := global_position.distance_to(target.global_position)
	var reach := range_to(target)
	if dist > reach * 0.95:
		_repath_timer -= delta
		if _repath_timer <= 0.0:
			_repath_timer = 0.5
			agent.target_position = target.global_position
		if not agent.is_navigation_finished():
			_desired = _steer_to(agent.get_next_path_position())
	if dist <= reach:
		_aim_and_fire(delta)


func _on_velocity_computed(safe: Vector3) -> void:
	_velocity = safe


func _update_engine_sound(delta: float, speed: float) -> void:
	if _engine == null:
		_engine_retry -= delta
		var wants: bool = is_air or is_naval or def["model"] == "tank" or def["model"].ends_with("truck")
		if wants and _engine_retry <= 0.0:
			_engine_retry = 1.0
			_engine = Audio.attach_loop(self, "drone_engine" if is_air else "engine", 0.0 if is_air else -12.0)
		return
	if not is_air:
		var k := clampf(speed / float(def["speed"]), 0.0, 1.0)
		_engine.volume_db = lerpf(-22.0, -9.0, k)
		_engine.pitch_scale = lerpf(0.85, 1.25, k)


func _process(delta: float) -> void:
	if not _alive:
		return
	_update_engine_sound(delta, _velocity.length())
	if is_air:
		return
	if is_naval:
		_process_boat_visual(delta)
		return
	var v := _velocity
	v.y = 0.0
	var moving := v.length() > 0.2
	if moving:
		global_position += v * delta
		var desired_yaw := atan2(-v.x, -v.z)
		_yaw = lerp_angle(_yaw, desired_yaw, clampf(delta * (3.0 if def["radius"] > 1.0 else 8.0), 0.0, 1.0))
	global_position = battlefield.terrain.clamp_to_map(global_position)
	global_position.y = battlefield.terrain.height_at(global_position)
	# Vehicles pitch and roll with the ground; infantry stay upright.
	var up := Vector3.UP
	if def["radius"] > 1.0:
		up = basis.y.slerp(battlefield.terrain.normal_at(global_position), clampf(delta * 6.0, 0.0, 1.0))
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var right := fwd.cross(up).normalized()
	fwd = up.cross(right).normalized()
	basis = Basis(right, up, -fwd)
	_animate(delta, moving, v.length())


func _animate(delta: float, moving: bool, speed: float) -> void:
	if legs == null:
		return
	_anim_t += delta * (speed * 2.2 if moving else 0.0)
	var i := 0
	for leg: Node3D in legs.get_children():
		var phase := _anim_t + (PI if i % 2 == 1 else 0.0) + (PI * 0.5 if i >= 2 else 0.0)
		leg.rotation.x = sin(phase) * (0.6 if moving else 0.0)
		i += 1


func _can_target(t: Unit) -> bool:
	match def["targets"]:
		"air":
			return t.is_air
		"ground":
			return not t.is_air
	return true


func _auto_target() -> void:
	if state == State.ATTACK:
		return
	if _guard_post != Vector3.INF and global_position.distance_to(_guard_post) > float(def["vision"]):
		# Leash: a guarding unit gives up the chase and walks back.
		# A plain move ignores targets until it is back at its post.
		_go(_guard_post, false)
		return
	if target != null and global_position.distance_to(target.global_position) <= float(def["range"]) * 1.1:
		return
	var radius: float = def["range"]
	if state == State.ATTACK_MOVE:
		radius = maxf(radius, def["vision"])
	elif state == State.IDLE and not hold and not is_naval:
		radius = maxf(radius, float(def["vision"]) * 0.8)
	elif state == State.MOVE:
		target = null
		return
	target = battlefield.find_target(self, radius)


func _aim_and_fire(delta: float) -> void:
	if target == null:
		return
	var to := target.global_position - global_position
	var aimed := true
	if turret:
		var local := to_local(target.global_position)
		var want := atan2(-local.x, -local.z)
		var speed: float = def.get("turret_speed", 3.0)
		turret.rotation.y = rotate_toward(turret.rotation.y, want, speed * delta)
		aimed = absf(angle_difference(turret.rotation.y, want)) < 0.08
	elif state == State.IDLE or _desired == Vector3.ZERO:
		_yaw = lerp_angle(_yaw, atan2(-to.x, -to.z), clampf(delta * 6.0, 0.0, 1.0))
		aimed = absf(angle_difference(_yaw, atan2(-to.x, -to.z))) < 0.2
	if aimed and _cooldown <= 0.0:
		_cooldown = def["cooldown"]
		_fire()


func _fire() -> void:
	var from := muzzle.global_position if muzzle else aim_point()
	var aim := target.aim_point()
	match def["weapon"]:
		"cannon":
			VFX.muzzle_flash(from, 1.6, aim - from)
			if turret:
				var tw := create_tween()
				tw.tween_property(turret, "position:z", turret.position.z + 0.25, 0.05)
				tw.tween_property(turret, "position:z", turret.position.z, 0.4)
			var miss := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * (1.5 if target.state != State.IDLE else 0.5)
			Projectile.launch(get_parent(), from, aim + miss, 110.0, 0.02,
				Callable(battlefield, "blast").bind(float(def["damage"]), float(def["splash"]), float(def["crater"]), team, 0.9, "cannon"))
		"rifle":
			VFX.muzzle_flash(from, 0.35, aim - from)
			var hit := randf() < 0.8
			var end := aim + (Vector3.ZERO if hit else Vector3(randf_range(-1.5, 1.5), randf_range(-0.5, 1.0), randf_range(-1.5, 1.5)))
			VFX.tracer(from, end)
			if hit:
				target.take_damage(def["damage"], team, "rifle")
				VFX.impact(end)
		"laser":
			VFX.laser(from, aim)
			target.take_damage(def["damage"], team, "laser")
		"atgm":
			# Shoulder-fired anti-tank missile: slow, lofted, smoky.
			VFX.muzzle_flash(from, 0.7, aim - from)
			var m := Projectile.launch(get_parent(), from, aim, 42.0, 0.09,
				Callable(battlefield, "blast").bind(float(def["damage"]), float(def["splash"]), float(def["crater"]), team, 0.7, "atgm"))
			m.add_child(VFX.make_trail(0.45))
		"autocannon":
			# Three-round burst of small explosive shells.
			for k in 3:
				var spread := Vector3(randf_range(-1, 1), randf_range(-0.3, 0.6), randf_range(-1, 1)) * (0.4 + k * 0.4)
				var hit_point := aim + spread
				get_tree().create_timer(k * 0.06).timeout.connect(func() -> void:
					if not _alive:
						return
					var f := muzzle.global_position if muzzle else aim_point()
					VFX.muzzle_flash(f, 0.5, hit_point - f)
					VFX.tracer(f, hit_point, Color(5.0, 3.0, 1.2), 0.09, 0.08)
					VFX.small_hit(hit_point, battlefield.terrain.is_land(hit_point) or hit_point.y > 0.8)
					battlefield.blast(hit_point, float(def["damage"]), float(def["splash"]), 0.0, team, 0.0, "autocannon"))
		"drone_launch":
			VFX.muzzle_flash(from, 1.0, Vector3.UP)
			var drone: Unit = battlefield.spawn_unit("shahed", team, from)
			drone.order_strike(target.global_position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))


func _process_drone(delta: float) -> void:
	if ground_target == Vector3.INF:
		return
	var cruise := 16.0
	var flat := Vector3(ground_target.x, 0, ground_target.z) - Vector3(global_position.x, 0, global_position.z)
	var dist := flat.length()
	var ground_h: float = battlefield.terrain.height_at(global_position)
	var goal_y: float = ground_target.y + 0.3 if dist < 22.0 else ground_h + cruise
	var dir := Vector3(flat.x, 0, flat.z).normalized()
	var vel := dir * float(def["speed"])
	vel.y = clampf((goal_y - global_position.y) * 2.0, -14.0, 8.0)
	global_position += vel * delta
	if vel.length() > 0.5 and absf(vel.normalized().y) < 0.97:
		look_at(global_position + vel, Vector3.UP)
	if dist < 2.0 or global_position.y <= ground_h + 0.2:
		battlefield.blast(global_position, def["damage"], def["splash"], def["crater"], team, 2.4)
		_alive = false
		died.emit(self)
		if _trail:
			_detach_trail()
		queue_free()


func take_damage(amount: float, from_team: int, weapon := "") -> void:
	if not _alive or from_team == team:
		return
	hp -= amount * UnitDefs.modifier(weapon, def.get("armor", ""))
	last_hit_time = Time.get_ticks_msec() / 1000.0
	if hp <= 0.0:
		_die()


func _detach_trail() -> void:
	var t := _trail
	var gp := t.global_position
	remove_child(t)
	VFX.add_child(t)
	t.global_position = gp
	t.emitting = false
	get_tree().create_timer(t.lifetime + 0.2).timeout.connect(t.queue_free)


func _die() -> void:
	_alive = false
	selected = false
	died.emit(self)
	if is_naval:
		VFX.explosion(global_position + Vector3.UP, 2.0 if def["radius"] > 2.0 else 1.4, VFX.Surface.AIR)
		VFX.burning(global_position + Vector3.UP * 0.5, 10.0, 0.9, false)
		if _wake:
			_wake.emitting = false
		var sink := create_tween()
		sink.tween_property(self, "global_position:y", -3.5, 6.0).set_ease(Tween.EASE_IN)
		sink.parallel().tween_property(self, "rotation:x", -0.5, 6.0)
		sink.tween_callback(queue_free)
		set_physics_process(false)
		set_process(false)
		return
	if is_air:
		VFX.explosion(global_position, 1.2, VFX.Surface.AIR)
		if _trail:
			_detach_trail()
		queue_free()
		return
	if agent:
		agent.avoidance_enabled = false
	var heavy: bool = def["radius"] > 1.0
	if heavy:
		VFX.explosion(global_position + Vector3.UP, 2.2)
		# Ammunition cooks off a moment later.
		var p := global_position + Vector3.UP * 1.5
		get_tree().create_timer(randf_range(0.5, 0.9)).timeout.connect(func() -> void: VFX.explosion(p, 1.3, VFX.Surface.AIR))
		battlefield.leave_wreck(model, global_transform)
		queue_free()
	else:
		# Infantry and robots fall over and fade.
		VFX.impact(aim_point())
		var tw := create_tween()
		tw.tween_property(model, "rotation:x", -PI * 0.5, 0.35).set_ease(Tween.EASE_IN)
		tw.tween_interval(2.0)
		tw.tween_property(model, "position:y", -1.0, 1.5)
		tw.tween_callback(queue_free)
		set_process(false)
		set_physics_process(false)
