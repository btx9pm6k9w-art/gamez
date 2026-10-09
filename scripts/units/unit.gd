class_name Unit
extends Node3D
## A ground or air unit: movement on the navigation mesh with local
## avoidance, auto-targeting, turret aim, weapons and death effects.

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
var state := State.IDLE
var target: Unit
var move_goal := Vector3.ZERO
var ground_target := Vector3.INF # for drones
var selected := false: set = _set_selected
var last_hit_time := -100.0

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


func setup(id: String, p_team: int, bf: Node) -> void:
	unit_id = id
	def = UnitDefs.get_def(id)
	team = p_team
	faction = def["faction"]
	battlefield = bf
	max_hp = def["hp"]
	hp = max_hp
	is_air = def.get("air", false)
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

func order_move(pos: Vector3, attack_move := false) -> void:
	if is_air:
		return
	move_goal = pos
	target = null
	state = State.ATTACK_MOVE if attack_move else State.MOVE
	agent.target_position = pos


func order_attack(t: Unit) -> void:
	if t == null or t.team == team or not _can_target(t):
		return
	target = t
	state = State.ATTACK
	_repath_timer = 0.0


func order_stop() -> void:
	state = State.IDLE
	target = null
	if agent:
		agent.target_position = global_position


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

	if target != null and (not is_instance_valid(target) or not target.is_alive()):
		target = null
		if state == State.ATTACK:
			state = State.IDLE
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
				state = State.IDLE
			else:
				_desired = _steer_to(agent.get_next_path_position())
		State.ATTACK:
			_engage(delta)
		State.IDLE:
			if target != null:
				_aim_and_fire(delta)
	if state == State.IDLE and target == null and turret:
		turret.rotation.y = lerp_angle(turret.rotation.y, 0.0, delta)

	agent.velocity = _desired


func _steer_to(p: Vector3) -> Vector3:
	var to := p - global_position
	to.y = 0.0
	if to.length() < 0.05:
		return Vector3.ZERO
	var slope: float = battlefield.terrain.slope_at(global_position)
	var speed: float = float(def["speed"]) * clampf(1.0 - slope * 1.6, 0.35, 1.0)
	return to.normalized() * speed


func _engage(delta: float) -> void:
	var dist := global_position.distance_to(target.global_position)
	if dist > float(def["range"]) * 0.95:
		_repath_timer -= delta
		if _repath_timer <= 0.0:
			_repath_timer = 0.5
			agent.target_position = target.global_position
		if not agent.is_navigation_finished():
			_desired = _steer_to(agent.get_next_path_position())
	if dist <= float(def["range"]):
		_aim_and_fire(delta)


func _on_velocity_computed(safe: Vector3) -> void:
	_velocity = safe


func _process(delta: float) -> void:
	if not _alive or is_air:
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
	if target != null and global_position.distance_to(target.global_position) <= float(def["range"]) * 1.1:
		return
	var radius: float = def["range"]
	if state == State.ATTACK_MOVE:
		radius = maxf(radius, def["vision"])
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
			VFX.muzzle_flash(from, 1.6)
			if turret:
				var tw := create_tween()
				tw.tween_property(turret, "position:z", turret.position.z + 0.25, 0.05)
				tw.tween_property(turret, "position:z", turret.position.z, 0.4)
			var miss := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * (1.5 if target.state != State.IDLE else 0.5)
			Projectile.launch(get_parent(), from, aim + miss, 110.0, 0.02,
				Callable(battlefield, "blast").bind(float(def["damage"]), float(def["splash"]), float(def["crater"]), team, 0.9))
		"rifle":
			VFX.muzzle_flash(from, 0.35)
			var hit := randf() < 0.8
			var end := aim + (Vector3.ZERO if hit else Vector3(randf_range(-1.5, 1.5), randf_range(-0.5, 1.0), randf_range(-1.5, 1.5)))
			VFX.tracer(from, end)
			if hit:
				target.take_damage(def["damage"], team)
				VFX.impact(end)
		"laser":
			VFX.laser(from, aim)
			target.take_damage(def["damage"], team)
		"drone_launch":
			VFX.muzzle_flash(from, 1.0)
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


func take_damage(amount: float, from_team: int) -> void:
	if not _alive or from_team == team:
		return
	hp -= amount
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
	if is_air:
		VFX.explosion(global_position, 0.8)
		if _trail:
			_detach_trail()
		queue_free()
		return
	if agent:
		agent.avoidance_enabled = false
	var heavy: bool = def["radius"] > 1.0
	if heavy:
		VFX.explosion(global_position + Vector3.UP, 2.2)
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
