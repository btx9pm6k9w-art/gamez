extends Node
## Procedural visual effects: explosions, muzzle flashes, tracers, lasers,
## missile trails and scorch decals. Everything is generated in code from
## gradients and primitive meshes, so the repo carries no texture files.

signal shake_requested(strength: float, origin: Vector3)

var _soft_dot: GradientTexture2D
var _ring_tex: GradientTexture2D
var _scorch_tex: GradientTexture2D

var _fire_process: ParticleProcessMaterial
var _smoke_process: ParticleProcessMaterial
var _spark_process: ParticleProcessMaterial
var _debris_process: ParticleProcessMaterial
var _trail_process: ParticleProcessMaterial

var _fire_mesh: QuadMesh
var _smoke_mesh: QuadMesh
var _spark_mesh: QuadMesh
var _debris_mesh: BoxMesh
var _trail_mesh: QuadMesh
var _ring_mesh: QuadMesh
var _tracer_mesh: BoxMesh

var _decals: Array[Decal] = []
const MAX_DECALS := 96


func _ready() -> void:
	_soft_dot = _radial([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)], [0.0, 0.35, 1.0])
	_ring_tex = _radial([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 0.7, 0.86, 1.0])
	_scorch_tex = _radial([Color(0.02, 0.018, 0.015, 0.95), Color(0.04, 0.035, 0.03, 0.7), Color(0.05, 0.045, 0.04, 0)], [0.0, 0.45, 1.0])

	# Fire: additive, unshaded, HDR bright so glow picks it up.
	_fire_process = ParticleProcessMaterial.new()
	_fire_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_fire_process.emission_sphere_radius = 0.6
	_fire_process.direction = Vector3.UP
	_fire_process.spread = 180.0
	_fire_process.initial_velocity_min = 3.0
	_fire_process.initial_velocity_max = 9.0
	_fire_process.gravity = Vector3(0, 3.0, 0)
	_fire_process.damping_min = 6.0
	_fire_process.damping_max = 10.0
	_fire_process.scale_min = 1.2
	_fire_process.scale_max = 2.6
	_fire_process.scale_curve = _curve_tex([Vector2(0, 0.3), Vector2(0.2, 1.0), Vector2(1, 0.6)])
	_fire_process.color_ramp = _gradient_tex(
		[Color(1, 0.95, 0.8, 1), Color(1, 0.6, 0.2, 1), Color(0.8, 0.2, 0.05, 0.8), Color(0.1, 0.05, 0.03, 0)],
		[0.0, 0.2, 0.55, 1.0])
	_fire_mesh = _quad(_fire_material())

	# Smoke: lit by the sun and GI, soft against the ground.
	_smoke_process = ParticleProcessMaterial.new()
	_smoke_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_smoke_process.emission_sphere_radius = 1.0
	_smoke_process.direction = Vector3.UP
	_smoke_process.spread = 60.0
	_smoke_process.initial_velocity_min = 1.0
	_smoke_process.initial_velocity_max = 4.0
	_smoke_process.gravity = Vector3(0.6, 1.4, 0.2)
	_smoke_process.damping_min = 1.0
	_smoke_process.damping_max = 2.0
	_smoke_process.angle_min = -180.0
	_smoke_process.angle_max = 180.0
	_smoke_process.angular_velocity_min = -20.0
	_smoke_process.angular_velocity_max = 20.0
	_smoke_process.scale_min = 2.0
	_smoke_process.scale_max = 4.0
	_smoke_process.scale_curve = _curve_tex([Vector2(0, 0.4), Vector2(1, 1.8)])
	_smoke_process.color_ramp = _gradient_tex(
		[Color(0.25, 0.22, 0.2, 0), Color(0.22, 0.2, 0.18, 0.8), Color(0.35, 0.33, 0.3, 0.45), Color(0.4, 0.38, 0.36, 0)],
		[0.0, 0.08, 0.5, 1.0])
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke_mat.vertex_color_use_as_albedo = true
	smoke_mat.albedo_texture = _soft_dot
	smoke_mat.proximity_fade_enabled = true
	smoke_mat.proximity_fade_distance = 1.5
	smoke_mat.roughness = 1.0
	smoke_mat.shadow_to_opacity = false
	_smoke_mesh = _quad(smoke_mat)

	# Sparks: tiny, very bright, fall with gravity.
	_spark_process = ParticleProcessMaterial.new()
	_spark_process.direction = Vector3.UP
	_spark_process.spread = 75.0
	_spark_process.initial_velocity_min = 8.0
	_spark_process.initial_velocity_max = 22.0
	_spark_process.gravity = Vector3(0, -14.0, 0)
	_spark_process.scale_min = 0.08
	_spark_process.scale_max = 0.18
	_spark_process.color_ramp = _gradient_tex([Color(1, 0.9, 0.6, 1), Color(1, 0.5, 0.1, 1), Color(0.6, 0.1, 0.0, 0)], [0.0, 0.5, 1.0])
	_spark_process.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	_spark_process.collision_bounce = 0.3
	_spark_process.collision_friction = 0.4
	_spark_mesh = _quad(_fire_material())

	# Debris chunks bounce on the terrain (heightfield collider in the battlefield).
	_debris_process = ParticleProcessMaterial.new()
	_debris_process.direction = Vector3.UP
	_debris_process.spread = 50.0
	_debris_process.initial_velocity_min = 6.0
	_debris_process.initial_velocity_max = 15.0
	_debris_process.gravity = Vector3(0, -12.0, 0)
	_debris_process.angular_velocity_min = -360.0
	_debris_process.angular_velocity_max = 360.0
	_debris_process.particle_flag_rotate_y = true
	_debris_process.scale_min = 0.5
	_debris_process.scale_max = 1.6
	_debris_process.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	_debris_process.collision_bounce = 0.2
	_debris_process.collision_friction = 0.8
	_debris_mesh = BoxMesh.new()
	_debris_mesh.size = Vector3(0.22, 0.16, 0.28)
	var debris_mat := StandardMaterial3D.new()
	debris_mat.albedo_color = Color(0.22, 0.2, 0.18)
	debris_mat.roughness = 0.9
	_debris_mesh.material = debris_mat

	# Missile and drone exhaust trail.
	_trail_process = ParticleProcessMaterial.new()
	_trail_process.direction = Vector3.UP
	_trail_process.spread = 10.0
	_trail_process.initial_velocity_min = 0.2
	_trail_process.initial_velocity_max = 0.8
	_trail_process.gravity = Vector3(0.3, 0.6, 0)
	_trail_process.scale_min = 0.5
	_trail_process.scale_max = 0.9
	_trail_process.scale_curve = _curve_tex([Vector2(0, 0.3), Vector2(1, 2.2)])
	_trail_process.color_ramp = _gradient_tex(
		[Color(1, 0.8, 0.5, 1), Color(0.6, 0.58, 0.55, 0.6), Color(0.7, 0.7, 0.7, 0)], [0.0, 0.08, 1.0])
	_trail_mesh = _quad(smoke_mat)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.albedo_texture = _ring_tex
	ring_mat.albedo_color = Color(2.0, 1.5, 1.0, 0.8)
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring_mesh = QuadMesh.new()
	_ring_mesh.orientation = PlaneMesh.FACE_Y
	_ring_mesh.material = ring_mat

	_tracer_mesh = BoxMesh.new()
	_tracer_mesh.size = Vector3(0.06, 0.06, 1.0)


func _radial(colors: Array, offsets: Array) -> GradientTexture2D:
	var t := GradientTexture2D.new()
	t.gradient = Gradient.new()
	t.gradient.colors = PackedColorArray(colors)
	t.gradient.offsets = PackedFloat32Array(offsets)
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


func _gradient_tex(colors: Array, offsets: Array) -> GradientTexture1D:
	var t := GradientTexture1D.new()
	t.gradient = Gradient.new()
	t.gradient.colors = PackedColorArray(colors)
	t.gradient.offsets = PackedFloat32Array(offsets)
	return t


func _curve_tex(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p: Vector2 in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


func _fire_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_dot
	m.albedo_color = Color(5.0, 3.2, 1.8, 1.0)
	return m


func _quad(mat: Material) -> QuadMesh:
	var q := QuadMesh.new()
	q.material = mat
	return q


func _budget(n: int) -> int:
	return maxi(1, int(n * GameSettings.particle_budget))


func _emit(process: ParticleProcessMaterial, mesh: Mesh, pos: Vector3, amount: int, lifetime: float, explosiveness := 0.95) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.process_material = process
	p.draw_pass_1 = mesh
	p.amount = _budget(amount)
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = explosiveness
	p.randomness = 0.5
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 50, 60))
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(lifetime + 0.5).timeout.connect(p.queue_free)
	return p


func _flash(pos: Vector3, energy: float, radius: float, duration: float, color := Color(1.0, 0.62, 0.3)) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = radius
	l.omni_attenuation = 1.4
	l.shadow_enabled = radius > 14.0 and GameSettings.preset >= GameSettings.Preset.HIGH
	add_child(l)
	l.global_position = pos + Vector3.UP * 1.5
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_callback(l.queue_free)


## A full explosion. size ~1 for a tank shell, ~3 for a missile, ~6 for a
## precision strike.
func explosion(pos: Vector3, size: float) -> void:
	var fire := _fire_process.duplicate() as ParticleProcessMaterial
	fire.emission_sphere_radius = 0.5 * size
	fire.initial_velocity_max = 7.0 * sqrt(size)
	fire.scale_min = 1.0 * size
	fire.scale_max = 2.2 * size
	_emit(fire, _fire_mesh, pos + Vector3.UP * 0.5, int(28 * size), 0.9 + 0.2 * size)

	var smoke := _smoke_process.duplicate() as ParticleProcessMaterial
	smoke.emission_sphere_radius = 0.8 * size
	smoke.scale_min = 1.6 * size
	smoke.scale_max = 3.2 * size
	_emit(smoke, _smoke_mesh, pos + Vector3.UP * 0.8, int(18 * size), 4.0 + size, 0.8)

	var sparks := _spark_process.duplicate() as ParticleProcessMaterial
	sparks.initial_velocity_max = 16.0 * sqrt(size)
	_emit(sparks, _spark_mesh, pos + Vector3.UP * 0.3, int(40 * size), 1.4)
	_emit(_debris_process, _debris_mesh, pos + Vector3.UP * 0.4, int(14 * size), 2.6)

	_shockwave(pos, size)
	_flash(pos, 6.0 + size * 4.0, 6.0 + size * 6.0, 0.35 + size * 0.1)
	shake_requested.emit(0.25 * size, pos)


func _shockwave(pos: Vector3, size: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos + Vector3.UP * 0.3
	mi.scale = Vector3.ONE * 0.5
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 9.0 * size, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(mi, "transparency", 1.0, 0.35)
	tw.tween_callback(mi.queue_free)


func muzzle_flash(pos: Vector3, size := 1.0) -> void:
	var fire := _fire_process.duplicate() as ParticleProcessMaterial
	fire.emission_sphere_radius = 0.1 * size
	fire.initial_velocity_min = 1.0
	fire.initial_velocity_max = 4.0 * size
	fire.scale_min = 0.4 * size
	fire.scale_max = 0.9 * size
	_emit(fire, _fire_mesh, pos, int(8 * size) + 2, 0.18)
	if size >= 1.0:
		var smoke := _smoke_process.duplicate() as ParticleProcessMaterial
		smoke.scale_min = 0.6 * size
		smoke.scale_max = 1.2 * size
		_emit(smoke, _smoke_mesh, pos, 6, 1.8, 0.9)
	_flash(pos, 3.0 * size, 5.0 * size, 0.12, Color(1.0, 0.75, 0.45))


func impact(pos: Vector3) -> void:
	_emit(_spark_process, _spark_mesh, pos, 10, 0.6)


## Bright streak for bullets and shells.
func tracer(from: Vector3, to: Vector3, color := Color(4.0, 2.6, 1.2), width := 0.06, duration := 0.07) -> void:
	var dist := from.distance_to(to)
	if dist < 0.1:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _tracer_mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.look_at_from_position((from + to) * 0.5, to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	mi.scale = Vector3(width / 0.06, width / 0.06, dist)
	var tw := create_tween()
	tw.tween_property(mi, "transparency", 1.0, duration)
	tw.tween_callback(mi.queue_free)


## Laser air-defence beam with a light at the emitter and a burst at the target.
func laser(from: Vector3, to: Vector3) -> void:
	tracer(from, to, Color(1.0, 6.0, 8.0), 0.12, 0.22)
	_flash(to, 4.0, 6.0, 0.2, Color(0.4, 0.9, 1.0))
	impact(to)


## Looping exhaust trail to parent under a moving missile or drone.
func make_trail() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.process_material = _trail_process
	p.draw_pass_1 = _trail_mesh
	p.amount = _budget(48)
	p.lifetime = 1.6
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-60, -20, -60), Vector3(120, 60, 120))
	return p


func scorch(pos: Vector3, radius: float) -> void:
	var d := Decal.new()
	d.texture_albedo = _scorch_tex
	d.size = Vector3(radius * 2.6, 6.0, radius * 2.6)
	d.cull_mask = 1
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	add_child(d)
	d.global_position = pos
	d.rotation.y = randf() * TAU
	_decals.append(d)
	if _decals.size() > MAX_DECALS:
		var old: Decal = _decals.pop_front()
		old.queue_free()


## Pulsing ground ring for move orders and strike warnings.
func ground_ring(pos: Vector3, color: Color, radius: float, duration: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_mesh
	var m := (_ring_mesh.material as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.albedo_color = color
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos + Vector3.UP * 0.25
	mi.scale = Vector3.ONE * radius * 2.0
	var tw := create_tween()
	tw.tween_property(mi, "transparency", 1.0, duration).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi


## Persistent fire with a smoke column, used for wrecks, fuel tanks and
## collapsed buildings. Stops emitting after duration seconds.
func burning(pos: Vector3, duration: float, size := 1.0) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	var fire := _fire_process.duplicate() as ParticleProcessMaterial
	fire.emission_sphere_radius = 0.5 * size
	fire.initial_velocity_min = 0.5
	fire.initial_velocity_max = 2.0
	fire.gravity = Vector3(0, 4.0, 0)
	fire.scale_min = 0.8 * size
	fire.scale_max = 1.6 * size
	var smoke := _smoke_process.duplicate() as ParticleProcessMaterial
	smoke.emission_sphere_radius = 0.6 * size
	smoke.spread = 15.0
	smoke.scale_min = 1.5 * size
	smoke.scale_max = 3.0 * size
	var emitters: Array[GPUParticles3D] = []
	for pair in [[fire, _fire_mesh, 40, 0.9], [smoke, _smoke_mesh, 50, 7.0]]:
		var p := GPUParticles3D.new()
		p.process_material = pair[0]
		p.draw_pass_1 = pair[1]
		p.amount = _budget(pair[2])
		p.lifetime = pair[3]
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.visibility_aabb = AABB(Vector3(-20, -5, -20), Vector3(40, 60, 40))
		root.add_child(p)
		p.emitting = true
		emitters.append(p)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.25)
	light.light_energy = 2.5 * size
	light.omni_range = 7.0 * size
	light.position = Vector3.UP * 0.8
	root.add_child(light)
	var flicker := light.create_tween().set_loops(int(duration / 0.3))
	flicker.tween_property(light, "light_energy", 1.6 * size, 0.15)
	flicker.tween_property(light, "light_energy", 2.8 * size, 0.15)
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		for e in emitters:
			e.emitting = false
		light.queue_free()
		get_tree().create_timer(7.5).timeout.connect(root.queue_free))
