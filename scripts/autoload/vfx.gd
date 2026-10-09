extends Node
## Visual effects. Explosions are built in layers the way film and AAA game
## VFX are: light flash, boiling fireball, flame licks, fire-lit smoke,
## streak sparks, debris trailing smoke, a ground-hugging dust skirt, a dirt
## plume, shockwave refraction and heat haze, then lingering fires, embers and
## a volumetric smoke pall. Water hits throw a spray column instead. Also
## muzzle flashes, tracers, laser beams, missile trails and scorch decals.
##
## Everything is generated in code from shaders, noise and primitive meshes,
## so the repo carries no texture files. Every layer scales with the graphics
## preset (see _q() and the "Visual effects" section of the design doc).

signal shake_requested(strength: float, origin: Vector3)
signal flash_requested(strength: float, origin: Vector3)

enum Surface { GROUND, AIR, WATER }

const MAX_DECALS := 96
const MAX_LINGERING := 20

var _noise: NoiseTexture2D
var _noise_normal: NoiseTexture2D
var _noise_3d: NoiseTexture3D
var _soft_dot: GradientTexture2D
var _ring_tex: GradientTexture2D
var _scorch_tex: GradientTexture2D
var _flare_tex: GradientTexture2D

var _smoke_mat: ShaderMaterial
var _dust_mat: ShaderMaterial
var _fire_mat: ShaderMaterial
var _fireball_mat: ShaderMaterial
var _distort_mat: ShaderMaterial
var _spark_mat: StandardMaterial3D
var _ember_mat: StandardMaterial3D

var _fire_quad: QuadMesh
var _smoke_quad: QuadMesh
var _dust_quad: QuadMesh
var _spark_quad: QuadMesh
var _ember_quad: QuadMesh
var _debris_mesh: BoxMesh
var _clod_mesh: BoxMesh
var _ring_mesh: QuadMesh
var _distort_quad: QuadMesh
var _tracer_mesh: BoxMesh
var _muzzle_mesh: ArrayMesh
var _fireball_meshes: Array[SphereMesh] = []

var _procs := {} # cache: "kind_size" -> ParticleProcessMaterial
var _decals: Array[Decal] = []
var _lingering: Array[Node3D] = []


func _ready() -> void:
	_build_textures()
	_build_materials()
	_build_meshes()


# --- Quality ---------------------------------------------------------------

## Graphics preset 0..3 (Low, Medium, High, Ultra).
func _q() -> int:
	return GameSettings.preset


func _budget(n: int) -> int:
	return maxi(1, int(n * GameSettings.particle_budget))


# --- Resources -------------------------------------------------------------

func _build_textures() -> void:
	var fnl := FastNoiseLite.new()
	fnl.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fnl.frequency = 0.012
	fnl.fractal_octaves = 5
	fnl.fractal_lacunarity = 2.1
	_noise = NoiseTexture2D.new()
	_noise.width = 256
	_noise.height = 256
	_noise.seamless = true
	_noise.noise = fnl
	_noise_normal = NoiseTexture2D.new()
	_noise_normal.width = 256
	_noise_normal.height = 256
	_noise_normal.seamless = true
	_noise_normal.as_normal_map = true
	_noise_normal.bump_strength = 6.0
	_noise_normal.noise = fnl
	var cells := FastNoiseLite.new()
	cells.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cells.frequency = 0.09
	cells.fractal_octaves = 3
	_noise_3d = NoiseTexture3D.new()
	_noise_3d.width = 48
	_noise_3d.height = 48
	_noise_3d.depth = 48
	_noise_3d.seamless = true
	_noise_3d.noise = cells

	_soft_dot = _radial([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)], [0.0, 0.35, 1.0])
	_ring_tex = _radial([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 0.7, 0.86, 1.0])
	_scorch_tex = _radial([Color(0.02, 0.018, 0.015, 0.95), Color(0.04, 0.035, 0.03, 0.7), Color(0.05, 0.045, 0.04, 0)], [0.0, 0.45, 1.0])
	_flare_tex = _radial([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.08), Color(1, 1, 1, 0)], [0.0, 0.12, 0.45, 1.0])


func _build_materials() -> void:
	_smoke_mat = ShaderMaterial.new()
	_smoke_mat.shader = load("res://shaders/vfx/particle_smoke.gdshader")
	_smoke_mat.set_shader_parameter("noise_tex", _noise)
	_smoke_mat.set_shader_parameter("emission_strength", 4.0)

	_dust_mat = _smoke_mat.duplicate() as ShaderMaterial
	_dust_mat.set_shader_parameter("emission_strength", 0.0)
	_dust_mat.set_shader_parameter("erosion", 0.75)
	_dust_mat.set_shader_parameter("soft_distance", 2.5)

	_fire_mat = ShaderMaterial.new()
	_fire_mat.shader = load("res://shaders/vfx/particle_fire.gdshader")
	_fire_mat.set_shader_parameter("noise_tex", _noise)

	_fireball_mat = ShaderMaterial.new()
	_fireball_mat.shader = load("res://shaders/vfx/fireball.gdshader")

	_distort_mat = ShaderMaterial.new()
	_distort_mat.shader = load("res://shaders/vfx/distortion.gdshader")
	_distort_mat.set_shader_parameter("noise_normal", _noise_normal)
	_distort_mat.render_priority = -10 # under the smoke and fire, over the scene

	# Sparks are stretched along their velocity, so no billboarding here.
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_spark_mat.vertex_color_use_as_albedo = true
	_spark_mat.albedo_texture = _soft_dot
	_spark_mat.albedo_color = Color(8.0, 5.0, 2.6, 1.0)
	_spark_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_ember_mat = _spark_mat.duplicate() as StandardMaterial3D
	_ember_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_ember_mat.albedo_color = Color(6.0, 2.4, 0.8, 1.0)


func _build_meshes() -> void:
	_fire_quad = _quad(_fire_mat)
	_smoke_quad = _quad(_smoke_mat)
	_dust_quad = _quad(_dust_mat)
	_spark_quad = QuadMesh.new()
	_spark_quad.size = Vector2(0.07, 0.9)
	_spark_quad.material = _spark_mat
	_ember_quad = QuadMesh.new()
	_ember_quad.size = Vector2(0.12, 0.12)
	_ember_quad.material = _ember_mat

	_debris_mesh = BoxMesh.new()
	_debris_mesh.size = Vector3(0.24, 0.14, 0.32)
	var debris_mat := StandardMaterial3D.new()
	debris_mat.albedo_color = Color(0.16, 0.15, 0.14)
	debris_mat.roughness = 0.85
	debris_mat.metallic = 0.3
	_debris_mesh.material = debris_mat
	_clod_mesh = BoxMesh.new()
	_clod_mesh.size = Vector3(0.22, 0.2, 0.22)
	var clod_mat := StandardMaterial3D.new()
	clod_mat.albedo_color = Color(0.42, 0.34, 0.24)
	clod_mat.roughness = 1.0
	_clod_mesh.material = clod_mat

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

	_distort_quad = _quad(_distort_mat)
	_tracer_mesh = BoxMesh.new()
	_tracer_mesh.size = Vector3(0.06, 0.06, 1.0)

	# Fireball spheres: more segments on higher presets for smoother boiling.
	for seg in [[16, 8], [24, 12], [40, 20], [64, 32]]:
		var s := SphereMesh.new()
		s.radial_segments = seg[0]
		s.rings = seg[1]
		s.material = _fireball_mat
		_fireball_meshes.append(s)

	# Muzzle flash: three crossed quads along -Z with a hot flare texture.
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flash_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	flash_mat.albedo_texture = _flare_tex
	flash_mat.albedo_color = Color(9.0, 5.5, 2.4, 1.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a := PI * k / 3.0
		var side := Vector3(cos(a), sin(a), 0.0) * 0.5
		var near := Vector3.ZERO
		var far := Vector3(0, 0, -2.0)
		var quad := [near - side, near + side, far + side, far - side]
		var uvs := [Vector2(0, 0.5), Vector2(1, 0.5), Vector2(1, 1), Vector2(0, 1)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[idx])
			st.add_vertex(quad[idx])
	st.set_material(flash_mat)
	_muzzle_mesh = st.commit()


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


func _ramp(colors: Array, offsets: Array) -> GradientTexture1D:
	var t := GradientTexture1D.new()
	t.gradient = Gradient.new()
	t.gradient.colors = PackedColorArray(colors)
	t.gradient.offsets = PackedFloat32Array(offsets)
	return t


func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p: Vector2 in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


func _quad(mat: Material) -> QuadMesh:
	var q := QuadMesh.new()
	q.material = mat
	return q


# --- Particle recipes ------------------------------------------------------

## Cached particle process material for an effect kind at a given size.
func _proc(kind: String, size := 1.0) -> ParticleProcessMaterial:
	var key := "%s_%.1f" % [kind, size]
	if not _procs.has(key):
		_procs[key] = _recipe(kind, size)
	return _procs[key]


func _recipe(kind: String, s: float) -> ParticleProcessMaterial:
	var r := sqrt(s)
	var smoke_ramp := _ramp([Color(0.06, 0.055, 0.05, 0), Color(0.07, 0.065, 0.06, 0.95), Color(0.2, 0.19, 0.18, 0.8), Color(0.36, 0.35, 0.34, 0)], [0.0, 0.05, 0.45, 1.0])
	var dust_ramp := _ramp([Color(0.62, 0.52, 0.4, 0), Color(0.6, 0.5, 0.38, 0.7), Color(0.66, 0.58, 0.47, 0.45), Color(0.7, 0.62, 0.52, 0)], [0.0, 0.08, 0.5, 1.0])
	var p := {}
	match kind:
		"fire":
			p = {emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, emission_sphere_radius = 0.45 * s,
				direction = Vector3.UP, spread = 180.0, initial_velocity_min = 2.0 * r, initial_velocity_max = 6.5 * r,
				gravity = Vector3(0, 4.0, 0), damping_min = 4.0, damping_max = 8.0,
				scale_min = 1.0 * s, scale_max = 2.2 * s, scale_curve = _curve([Vector2(0, 0.4), Vector2(0.15, 1.0), Vector2(1, 0.7)]),
				angle_min = -180.0, angle_max = 180.0, angular_velocity_min = -40.0, angular_velocity_max = 40.0}
		"smoke":
			p = {emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, emission_sphere_radius = 0.7 * s,
				direction = Vector3.UP, spread = 70.0, initial_velocity_min = 1.5 * r, initial_velocity_max = 5.0 * r,
				gravity = Vector3(0.5, 1.6, 0.2), damping_min = 1.2, damping_max = 2.2,
				scale_min = 1.4 * s, scale_max = 2.8 * s, scale_curve = _curve([Vector2(0, 0.35), Vector2(0.3, 1.0), Vector2(1, 1.9)]),
				color_ramp = smoke_ramp, angle_min = -180.0, angle_max = 180.0, angular_velocity_min = -15.0, angular_velocity_max = 15.0,
				turbulence_enabled = true, turbulence_noise_strength = 1.2, turbulence_noise_scale = 6.0,
				turbulence_influence_min = 0.03, turbulence_influence_max = 0.08}
		"column":
			p = {emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, emission_sphere_radius = 0.6 * s,
				direction = Vector3.UP, spread = 10.0, initial_velocity_min = 5.0 * r, initial_velocity_max = 9.0 * r,
				gravity = Vector3(0.7, 0.4, 0.25), damping_min = 0.8, damping_max = 1.4,
				scale_min = 1.8 * s, scale_max = 3.2 * s, scale_curve = _curve([Vector2(0, 0.4), Vector2(1, 2.2)]),
				color_ramp = smoke_ramp, angle_min = -180.0, angle_max = 180.0, angular_velocity_min = -10.0, angular_velocity_max = 10.0}
		"dust":
			p = {emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING, emission_ring_axis = Vector3.UP,
				emission_ring_radius = 0.5 * s, emission_ring_inner_radius = 0.0, emission_ring_height = 0.2,
				direction = Vector3.UP, spread = 5.0, initial_velocity_min = 0.3, initial_velocity_max = 1.2,
				radial_velocity_min = 7.0 * r, radial_velocity_max = 13.0 * r,
				gravity = Vector3(0.3, -0.2, 0.1), damping_min = 3.5, damping_max = 5.5,
				scale_min = 1.2 * s, scale_max = 2.2 * s, scale_curve = _curve([Vector2(0, 0.4), Vector2(1, 1.7)]),
				color_ramp = dust_ramp, angle_min = -180.0, angle_max = 180.0}
		"dirt_plume":
			p = {emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, emission_sphere_radius = 0.4 * s,
				direction = Vector3.UP, spread = 20.0, initial_velocity_min = 6.0 * r, initial_velocity_max = 13.0 * r,
				gravity = Vector3(0, -5.0, 0), damping_min = 1.2, damping_max = 2.0,
				scale_min = 0.9 * s, scale_max = 1.8 * s, scale_curve = _curve([Vector2(0, 0.5), Vector2(1, 1.6)]),
				color_ramp = _ramp([Color(0.3, 0.24, 0.17, 0), Color(0.32, 0.25, 0.18, 0.9), Color(0.5, 0.42, 0.32, 0)], [0.0, 0.06, 1.0]),
				angle_min = -180.0, angle_max = 180.0}
		"clods":
			p = {direction = Vector3.UP, spread = 38.0, initial_velocity_min = 7.0 * r, initial_velocity_max = 15.0 * r,
				gravity = Vector3(0, -15.0, 0), angular_velocity_min = -400.0, angular_velocity_max = 400.0,
				particle_flag_rotate_y = true, scale_min = 0.5, scale_max = 1.6 + 0.2 * s,
				collision_mode = ParticleProcessMaterial.COLLISION_RIGID, collision_bounce = 0.1, collision_friction = 0.9}
		"sparks":
			p = {direction = Vector3.UP, spread = 80.0, initial_velocity_min = 10.0 * r, initial_velocity_max = 26.0 * r,
				gravity = Vector3(0, -14.0, 0), scale_min = 0.5, scale_max = 1.2,
				color_ramp = _ramp([Color(1, 0.95, 0.75, 1), Color(1, 0.55, 0.15, 1), Color(0.6, 0.1, 0.0, 0)], [0.0, 0.45, 1.0]),
				collision_mode = ParticleProcessMaterial.COLLISION_RIGID, collision_bounce = 0.35, collision_friction = 0.3}
		"laser_sparks":
			p = {direction = Vector3.UP, spread = 70.0, initial_velocity_min = 4.0, initial_velocity_max = 12.0,
				gravity = Vector3(0, -12.0, 0), scale_min = 0.3, scale_max = 0.7,
				color_ramp = _ramp([Color(0.8, 1, 1, 1), Color(1, 0.7, 0.3, 1), Color(0.6, 0.1, 0.0, 0)], [0.0, 0.35, 1.0]),
				collision_mode = ParticleProcessMaterial.COLLISION_RIGID, collision_bounce = 0.3, collision_friction = 0.3}
		"debris":
			p = {direction = Vector3.UP, spread = 55.0, initial_velocity_min = 7.0 * r, initial_velocity_max = 16.0 * r,
				gravity = Vector3(0, -13.0, 0), angular_velocity_min = -360.0, angular_velocity_max = 360.0,
				particle_flag_rotate_y = true, scale_min = 0.6, scale_max = 1.5 + 0.25 * s,
				collision_mode = ParticleProcessMaterial.COLLISION_RIGID, collision_bounce = 0.2, collision_friction = 0.8,
				sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_CONSTANT, sub_emitter_frequency = 18.0}
		"debris_trail":
			p = {direction = Vector3.UP, spread = 30.0, initial_velocity_min = 0.0, initial_velocity_max = 0.6,
				gravity = Vector3(0.3, 1.2, 0.1), damping_min = 1.0, damping_max = 2.0,
				scale_min = 0.35 * r, scale_max = 0.7 * r, scale_curve = _curve([Vector2(0, 0.4), Vector2(1, 2.0)]),
				color_ramp = smoke_ramp, angle_min = -180.0, angle_max = 180.0}
		"embers":
			p = {emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, emission_sphere_radius = 0.8 * s,
				direction = Vector3.UP, spread = 60.0, initial_velocity_min = 1.0, initial_velocity_max = 4.0 * r,
				gravity = Vector3(0.4, 2.2, 0.1), scale_min = 0.4, scale_max = 1.0,
				color_ramp = _ramp([Color(1, 0.8, 0.4, 1), Color(1, 0.35, 0.05, 0.9), Color(0.5, 0.05, 0.0, 0)], [0.0, 0.5, 1.0]),
				turbulence_enabled = true, turbulence_noise_strength = 3.0, turbulence_noise_scale = 3.0,
				turbulence_influence_min = 0.2, turbulence_influence_max = 0.4}
		"spray":
			p = {emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, emission_sphere_radius = 0.4 * s,
				direction = Vector3.UP, spread = 14.0, initial_velocity_min = 9.0 * r, initial_velocity_max = 18.0 * r,
				gravity = Vector3(0, -12.0, 0), damping_min = 0.3, damping_max = 0.8,
				scale_min = 0.8 * s, scale_max = 1.6 * s, scale_curve = _curve([Vector2(0, 0.5), Vector2(1, 1.8)]),
				color_ramp = _ramp([Color(0.92, 0.95, 0.97, 0), Color(0.9, 0.94, 0.96, 0.9), Color(0.85, 0.9, 0.93, 0)], [0.0, 0.05, 1.0]),
				angle_min = -180.0, angle_max = 180.0}
		"mist":
			p = {emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING, emission_ring_axis = Vector3.UP,
				emission_ring_radius = 0.6 * s, emission_ring_inner_radius = 0.0, emission_ring_height = 0.1,
				direction = Vector3.UP, spread = 5.0, initial_velocity_min = 0.5, initial_velocity_max = 1.5,
				radial_velocity_min = 5.0 * r, radial_velocity_max = 9.0 * r, damping_min = 3.0, damping_max = 4.0,
				scale_min = 1.2 * s, scale_max = 2.0 * s, scale_curve = _curve([Vector2(0, 0.5), Vector2(1, 1.8)]),
				color_ramp = _ramp([Color(0.9, 0.94, 0.96, 0), Color(0.88, 0.92, 0.95, 0.6), Color(0.9, 0.93, 0.95, 0)], [0.0, 0.1, 1.0]),
				angle_min = -180.0, angle_max = 180.0}
		"burn_fire":
			p = {emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, emission_sphere_radius = 0.5 * s,
				direction = Vector3.UP, spread = 20.0, initial_velocity_min = 0.8, initial_velocity_max = 2.4 * r,
				gravity = Vector3(0, 3.5, 0), scale_min = 0.8 * s, scale_max = 1.6 * s,
				scale_curve = _curve([Vector2(0, 0.6), Vector2(0.3, 1.0), Vector2(1, 0.3)]),
				angle_min = -180.0, angle_max = 180.0, angular_velocity_min = -30.0, angular_velocity_max = 30.0}
		"burn_smoke":
			p = {emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, emission_sphere_radius = 0.6 * s,
				direction = Vector3.UP, spread = 12.0, initial_velocity_min = 2.0, initial_velocity_max = 3.5 * r,
				gravity = Vector3(0.9, 0.8, 0.3), damping_min = 0.4, damping_max = 0.8,
				scale_min = 1.4 * s, scale_max = 2.6 * s, scale_curve = _curve([Vector2(0, 0.35), Vector2(1, 2.4)]),
				color_ramp = smoke_ramp, angle_min = -180.0, angle_max = 180.0, angular_velocity_min = -8.0, angular_velocity_max = 8.0,
				turbulence_enabled = true, turbulence_noise_strength = 1.0, turbulence_noise_scale = 8.0,
				turbulence_influence_min = 0.02, turbulence_influence_max = 0.06}
		"muzzle_fire":
			p = {direction = Vector3.FORWARD, spread = 18.0, initial_velocity_min = 2.0, initial_velocity_max = 7.0 * s,
				damping_min = 10.0, damping_max = 16.0, scale_min = 0.35 * s, scale_max = 0.8 * s,
				angle_min = -180.0, angle_max = 180.0}
		"muzzle_smoke":
			p = {direction = Vector3.FORWARD, spread = 40.0, initial_velocity_min = 2.0, initial_velocity_max = 6.0 * s,
				gravity = Vector3(0.3, 0.8, 0.1), damping_min = 3.0, damping_max = 5.0,
				scale_min = 0.5 * s, scale_max = 1.1 * s, scale_curve = _curve([Vector2(0, 0.4), Vector2(1, 2.2)]),
				color_ramp = _ramp([Color(0.55, 0.52, 0.48, 0), Color(0.5, 0.48, 0.45, 0.6), Color(0.6, 0.58, 0.55, 0)], [0.0, 0.05, 1.0]),
				angle_min = -180.0, angle_max = 180.0}
		"trail":
			p = {direction = Vector3.UP, spread = 10.0, initial_velocity_min = 0.2, initial_velocity_max = 0.8,
				gravity = Vector3(0.3, 0.6, 0), scale_min = 0.5 * s, scale_max = 0.9 * s,
				scale_curve = _curve([Vector2(0, 0.3), Vector2(1, 2.4)]),
				color_ramp = _ramp([Color(1, 0.85, 0.6, 0.9), Color(0.62, 0.6, 0.58, 0.55), Color(0.72, 0.72, 0.72, 0)], [0.0, 0.06, 1.0]),
				angle_min = -180.0, angle_max = 180.0}
		"contrail":
			p = {direction = Vector3.UP, spread = 5.0, initial_velocity_min = 0.0, initial_velocity_max = 0.3,
				scale_min = 0.25 * s, scale_max = 0.4 * s, scale_curve = _curve([Vector2(0, 0.4), Vector2(1, 2.0)]),
				color_ramp = _ramp([Color(1, 1, 1, 0), Color(0.95, 0.96, 0.98, 0.5), Color(0.95, 0.96, 0.98, 0)], [0.0, 0.05, 1.0])}
		"wake":
			p = {emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX, emission_box_extents = Vector3(0.6 * s, 0.05, 0.3),
				direction = Vector3.UP, spread = 70.0, initial_velocity_min = 0.4, initial_velocity_max = 1.6 * s,
				gravity = Vector3(0, -0.6, 0), damping_min = 1.0, damping_max = 2.0,
				scale_min = 0.6 * s, scale_max = 1.2 * s, scale_curve = _curve([Vector2(0, 0.4), Vector2(1, 2.6)]),
				color_ramp = _ramp([Color(0.95, 0.97, 0.98, 0), Color(0.92, 0.95, 0.97, 0.75), Color(0.9, 0.94, 0.96, 0)], [0.0, 0.05, 1.0]),
				angle_min = -180.0, angle_max = 180.0}
		"thruster":
			p = {direction = Vector3.BACK, spread = 6.0, initial_velocity_min = 4.0, initial_velocity_max = 8.0,
				damping_min = 6.0, damping_max = 9.0, scale_min = 0.3 * s, scale_max = 0.55 * s}
	var m := ParticleProcessMaterial.new()
	for k: String in p:
		m.set(k, p[k])
	return m


## One-shot particle burst at pos. Returns the emitter so callers can tweak it.
func _emit(kind: String, size: float, mesh: Mesh, pos: Vector3, amount: int, lifetime: float, explosiveness := 0.95, parent: Node = null) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.process_material = _proc(kind, size)
	p.draw_pass_1 = mesh
	p.amount = _budget(amount)
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = explosiveness
	p.randomness = 0.5
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ext := 12.0 + 8.0 * size
	p.visibility_aabb = AABB(Vector3(-ext, -6, -ext), Vector3(ext * 2.0, ext * 3.0, ext * 2.0))
	if mesh == _spark_quad:
		p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	(parent if parent else self).add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(lifetime * 1.6 + 0.5).timeout.connect(p.queue_free)
	return p


## Looping emitter (fires, trails). The caller owns its lifetime.
func _loop(kind: String, size: float, mesh: Mesh, amount: int, lifetime: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.process_material = _proc(kind, size)
	p.draw_pass_1 = mesh
	p.amount = _budget(amount)
	p.lifetime = lifetime
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 70, 80))
	return p


func _flash(pos: Vector3, energy: float, radius: float, duration: float, color := Color(1.0, 0.62, 0.3)) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = radius
	l.omni_attenuation = 1.4
	l.light_volumetric_fog_energy = 3.0 # lights up the surrounding smoke and haze
	l.shadow_enabled = radius > 14.0 and _q() >= GameSettings.Preset.HIGH
	add_child(l)
	l.global_position = pos + Vector3.UP * 1.5
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_callback(l.queue_free)
	return l


# --- Explosions ------------------------------------------------------------

## A full explosion. size ~1 for a tank shell, ~2.5 for a drone, ~3.5 for an
## aircraft bomb, ~6 for the precision strike.
func explosion(pos: Vector3, size: float, surface := Surface.GROUND) -> void:
	if surface == Surface.WATER:
		_water_explosion(pos, size)
		return
	var q := _q()
	var ground := surface == Surface.GROUND

	_flash(pos, 8.0 + size * 5.0, 7.0 + size * 7.0, 0.4 + size * 0.12)
	_fireball(pos + Vector3.UP * (0.4 * size if ground else 0.0), size)
	_emit("fire", size, _fire_quad, pos + Vector3.UP * 0.5, int(20 * size), 0.8 + 0.18 * size)
	_emit("smoke", size, _smoke_quad, pos + Vector3.UP * 0.8, int(14 * size), 5.0 + size, 0.85)
	_emit("sparks", size, _spark_quad, pos + Vector3.UP * 0.3, int(36 * size), 1.6)
	_debris(pos + Vector3.UP * 0.4, size, _debris_mesh)

	if ground:
		_emit("dust", size, _dust_quad, pos + Vector3.UP * 0.2, int(22 * size), 3.0 + size * 0.5, 1.0)
		if size >= 1.4:
			_emit("dirt_plume", size, _dust_quad, pos, int(10 * size), 2.2 + size * 0.2, 0.9)
			_emit("clods", size, _clod_mesh, pos + Vector3.UP * 0.3, int(10 * size), 2.6)
		if size >= 3.0:
			_emit("column", size, _smoke_quad, pos + Vector3.UP * size, int(16 * size), 7.0 + size, 0.25)
		_ground_flash(pos, size)

	if q >= GameSettings.Preset.MEDIUM:
		_distortion(pos + Vector3.UP * size, size * 5.0, 0.45 + size * 0.05, 1.0, true)
		_distortion(pos + Vector3.UP * (size * 1.2), size * 2.6, 1.6 + size * 0.3, 1.2, false)
		if size >= 2.0:
			_emit("embers", size, _ember_quad, pos + Vector3.UP * size * 0.6, int(30 * size), 4.5, 0.6)
	if q >= GameSettings.Preset.HIGH and ground and size >= 2.4:
		for i in mini(int(size * 0.7), 4):
			var off := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * size * 0.9
			_lingering_fire(pos + off, randf_range(8.0, 16.0), randf_range(0.5, 0.9) * sqrt(size) * 0.7)
	if q >= GameSettings.Preset.HIGH and size >= 3.0:
		_smoke_pall(pos, size)

	Audio.play_3d("explosion_big" if size >= 2.0 else "explosion_small", pos, 2.0 + size * 2.0, 1.15 - minf(size, 6.0) * 0.06, 6)
	Audio.bump_intensity(0.04 * size)
	shake_requested.emit(0.25 * size, pos)
	if size >= 3.0:
		flash_requested.emit(clampf(size / 6.0, 0.3, 1.0), pos)


## The boiling core: one to three displaced spheres that swell in a fraction
## of a second, rise, cool to soot and tear apart. Big blasts form a mushroom.
func _fireball(pos: Vector3, size: float) -> void:
	var mesh: SphereMesh = _fireball_meshes[_q()]
	var lobes := 1 if size < 2.0 else (2 if size < 4.0 else 3)
	for i in lobes:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_instance_shader_parameter("seed", randf() * 10.0)
		mi.set_instance_shader_parameter("progress", 0.0)
		add_child(mi)
		var off := Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 0.4), randf_range(-0.5, 0.5)) * size * (0.0 if i == 0 else 1.0)
		mi.global_position = pos + off
		mi.scale = Vector3.ONE * 0.3 * size
		var peak := size * randf_range(1.2, 1.6) * (1.0 if i == 0 else 0.75)
		var life := 1.0 + size * 0.22
		var rise := size * (1.6 if size >= 5.0 else 0.8)
		var tw := create_tween().set_parallel()
		tw.tween_property(mi, "scale", Vector3.ONE * peak, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tw.tween_property(mi, "scale", Vector3(1.25, 1.05, 1.25) * peak * 1.3, life).set_delay(0.25).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "global_position:y", mi.global_position.y + rise, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("progress", v), 0.0, 1.0, life).set_delay(0.05 * i)
		tw.chain().tween_callback(mi.queue_free)
	if size >= 5.0:
		# Mushroom stem: a column of fire-lit smoke drawn up under the cap.
		_emit("column", size * 0.5, _smoke_quad, pos, int(12 * size), 4.0 + size * 0.4, 0.4)


func _debris(pos: Vector3, size: float, mesh: Mesh) -> void:
	var main := _emit("debris", size, mesh, pos, int(12 * size), 2.8)
	if _q() >= GameSettings.Preset.HIGH:
		# Every chunk drags a smoke trail through the air.
		var trail := _loop("debris_trail", size, _smoke_quad, int(70 * size), 1.4)
		add_child(trail)
		trail.global_position = pos
		main.sub_emitter = main.get_path_to(trail)
		get_tree().create_timer(5.0).timeout.connect(trail.queue_free)


## Bright ground flash ring under a blast plus the scorch-coloured skirt.
func _ground_flash(pos: Vector3, size: float) -> void:
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


## Screen-space refraction: ring = expanding shockwave, otherwise heat haze.
func _distortion(pos: Vector3, radius: float, duration: float, strength: float, ring: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _distort_quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("ring", 1.0 if ring else 0.0)
	mi.set_instance_shader_parameter("strength", strength)
	mi.set_instance_shader_parameter("progress", 0.0)
	add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * radius * 2.0
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("progress", v), 0.0, 1.0, duration) \
		.set_ease(Tween.EASE_OUT if ring else Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(mi.queue_free)


func _water_explosion(pos: Vector3, size: float) -> void:
	var surface := Vector3(pos.x, maxf(pos.y, 0.0), pos.z)
	_flash(surface + Vector3.DOWN, 4.0 + size * 2.0, 5.0 + size * 4.0, 0.3, Color(1.0, 0.75, 0.5))
	_emit("spray", size, _dust_quad, surface, int(26 * size), 2.2 + size * 0.3, 0.9)
	_emit("mist", size, _dust_quad, surface + Vector3.UP * 0.2, int(18 * size), 3.5, 1.0)
	_emit("sparks", size * 0.5, _spark_quad, surface, int(8 * size), 0.6)
	if _q() >= GameSettings.Preset.MEDIUM:
		_distortion(surface + Vector3.UP * size, size * 4.0, 0.4, 0.6, true)
	Audio.play_3d("explosion_small", surface, size * 1.5, 0.8, 6)
	Audio.bump_intensity(0.03 * size)
	shake_requested.emit(0.15 * size, surface)


## Small fire left burning in a crater, with heat haze and flickering light.
func _lingering_fire(pos: Vector3, duration: float, size: float) -> void:
	if _lingering.size() >= MAX_LINGERING:
		return
	burning(pos, duration, size, false)


## Volumetric smoke pall: a FogVolume that drifts downwind, grows and thins,
## so the sun and explosion lights actually scatter through it.
func _smoke_pall(pos: Vector3, size: float) -> void:
	var fv := FogVolume.new()
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	fv.size = Vector3(4.0, 5.0, 4.0) * size
	var fm := FogMaterial.new()
	fm.density = 0.0
	fm.albedo = Color(0.32, 0.3, 0.28)
	fm.density_texture = _noise_3d
	fm.edge_fade = 0.6
	fv.material = fm
	add_child(fv)
	fv.global_position = pos + Vector3.UP * size * 1.8
	var tw := create_tween()
	tw.tween_property(fm, "density", 0.5, 1.5).set_delay(0.4)
	tw.tween_property(fm, "density", 0.0, 20.0).set_ease(Tween.EASE_IN)
	var drift := create_tween().set_parallel()
	drift.tween_property(fv, "global_position", fv.global_position + Vector3(9.0, size * 2.0, 3.0), 22.0)
	drift.tween_property(fv, "size", fv.size * 2.2, 22.0)
	drift.chain().tween_callback(fv.queue_free)


# --- Weapons ---------------------------------------------------------------

## Muzzle flash. dir is the barrel direction (zero = omni-directional puff).
func muzzle_flash(pos: Vector3, size := 1.0, dir := Vector3.ZERO) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	if dir.length_squared() > 0.01:
		var d := dir.normalized()
		root.look_at(pos + d, Vector3.UP if absf(d.y) < 0.98 else Vector3.RIGHT)
		var star := MeshInstance3D.new()
		star.mesh = _muzzle_mesh
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		star.scale = Vector3(1.0, 1.0, 0.8) * size * randf_range(0.85, 1.2)
		star.rotation.z = randf() * TAU
		root.add_child(star)
		var tw := create_tween()
		tw.tween_property(star, "scale", star.scale * Vector3(1.3, 1.3, 1.5), 0.06)
		tw.parallel().tween_property(star, "transparency", 1.0, 0.07)
	_emit("muzzle_fire", size, _fire_quad, pos, int(8 * size) + 3, 0.16, 1.0, root)
	if size >= 1.0:
		_emit("muzzle_smoke", size, _dust_quad, pos, int(6 * size) + 2, 2.2, 0.9, root)
		if _q() >= GameSettings.Preset.MEDIUM:
			_distortion(pos, size * 1.6, 0.25, 0.8, true)
	get_tree().create_timer(2.6).timeout.connect(root.queue_free)
	_flash(pos, 4.0 * size, 6.0 * size, 0.1, Color(1.0, 0.75, 0.45))
	if size >= 1.5:
		Audio.play_3d("cannon", pos, 2.0)
		shake_requested.emit(0.05, pos)
	elif size >= 0.9:
		Audio.play_3d("launch", pos, -2.0)
	else:
		Audio.play_3d("rifle", pos, -8.0, 1.0, 10)
	Audio.bump_intensity(0.01)


func impact(pos: Vector3) -> void:
	_emit("sparks", 0.4, _spark_quad, pos, 10, 0.6)
	_emit("dust", 0.3, _dust_quad, pos, 4, 1.2)


## Small explosive round: a spark burst and dust puff on land or metal, a
## white splash on water.
func small_hit(pos: Vector3, solid: bool) -> void:
	if solid:
		_emit("sparks", 0.5, _spark_quad, pos, 12, 0.7)
		_emit("dust", 0.4, _dust_quad, pos, 4, 1.4)
		_flash(pos, 2.0, 3.0, 0.08)
	else:
		_emit("spray", 0.35, _dust_quad, Vector3(pos.x, 0.0, pos.z), 8, 1.2, 0.9)


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


## Laser air-defence beam: white-hot core inside a cyan glow that flickers,
## a flare at the emitter, molten sparks and heat shimmer at the target.
func laser(from: Vector3, to: Vector3) -> void:
	tracer(from, to, Color(6.0, 9.0, 10.0), 0.05, 0.28)
	tracer(from, to, Color(0.3, 2.2, 3.2), 0.28, 0.32)
	tracer(from, to, Color(0.1, 0.6, 1.0), 0.7, 0.2)
	_flash(from, 3.0, 4.0, 0.25, Color(0.5, 0.9, 1.0))
	_flash(to, 6.0, 7.0, 0.3, Color(0.6, 0.9, 1.0))
	_emit("laser_sparks", 1.0, _spark_quad, to, 18, 0.9)
	if _q() >= GameSettings.Preset.MEDIUM:
		_distortion(to, 1.8, 0.6, 0.8, false)
	Audio.play_3d("laser", from, -4.0, 1.0, 4)


## Looping exhaust for a missile or drone: hot flame and light at the nozzle,
## smoke trail behind. Parent it under the moving body; set emitting.
func make_trail(size := 1.0) -> GPUParticles3D:
	var p := _loop("trail", size, _dust_quad, 64, 2.2)
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-80, -30, -80), Vector3(160, 100, 160))
	var flame := _loop("thruster", size, _fire_quad, 16, 0.12)
	flame.local_coords = true
	p.add_child(flame)
	flame.emitting = true
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.6, 0.3)
	glow.light_energy = 2.5 * size
	glow.omni_range = 6.0 * size
	p.add_child(glow)
	return p


## Foaming wake behind a boat. Set amount_ratio from the boat's speed.
func make_wake(size := 1.0) -> GPUParticles3D:
	var p := _loop("wake", size, _dust_quad, 80, 3.2)
	p.local_coords = false
	return p


## Thin white vapour trail for aircraft wingtips.
func make_contrail(size := 1.0) -> GPUParticles3D:
	var p := _loop("contrail", size, _dust_quad, 90, 2.5)
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-200, -40, -200), Vector3(400, 120, 400))
	return p


## Afterburner flame for jets.
func make_afterburner(size := 1.0) -> GPUParticles3D:
	var p := _loop("thruster", size, _fire_quad, 24, 0.15)
	p.local_coords = true
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.55, 0.25)
	glow.light_energy = 4.0 * size
	glow.omni_range = 10.0 * size
	p.add_child(glow)
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


## Persistent fire with a smoke column, embers, heat haze and a flickering
## light, used for wrecks, fuel tanks, collapsed buildings and craters.
## Stops emitting after duration seconds.
func burning(pos: Vector3, duration: float, size := 1.0, column := true) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	_lingering.append(root)
	var q := _q()
	var emitters: Array[GPUParticles3D] = []
	emitters.append(_loop("burn_fire", size, _fire_quad, 36, 0.9))
	if column:
		emitters.append(_loop("burn_smoke", size, _smoke_quad, 44, 8.0))
	else:
		emitters.append(_loop("burn_smoke", size * 0.6, _smoke_quad, 16, 4.0))
	if q >= GameSettings.Preset.MEDIUM:
		emitters.append(_loop("embers", size * 0.6, _ember_quad, 14, 3.5))
	for e in emitters:
		root.add_child(e)
		e.emitting = true
	var haze: MeshInstance3D = null
	if q >= GameSettings.Preset.MEDIUM:
		haze = MeshInstance3D.new()
		haze.mesh = _distort_quad
		haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		haze.set_instance_shader_parameter("ring", 0.0)
		haze.set_instance_shader_parameter("strength", 0.7)
		haze.set_instance_shader_parameter("progress", 0.0)
		haze.position = Vector3.UP * 2.2 * size
		haze.scale = Vector3.ONE * 3.5 * size
		root.add_child(haze)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.25)
	light.light_energy = 2.5 * size
	light.omni_range = 7.0 * size
	light.light_volumetric_fog_energy = 2.0
	light.position = Vector3.UP * 0.8
	root.add_child(light)
	var flicker := light.create_tween().set_loops(maxi(int(duration / 0.26), 1))
	flicker.tween_property(light, "light_energy", 1.5 * size, randf_range(0.08, 0.14))
	flicker.tween_property(light, "light_energy", 2.9 * size, randf_range(0.1, 0.16))
	var crackle := Audio.attach_loop(root, "fire", -10.0 + size * 2.0)
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		for e in emitters:
			e.emitting = false
		if crackle:
			crackle.queue_free()
		var fade := root.create_tween().set_parallel()
		fade.tween_property(light, "light_energy", 0.0, 2.0)
		if haze:
			fade.tween_method(func(v: float) -> void: haze.set_instance_shader_parameter("progress", v), 0.0, 1.0, 2.0)
		get_tree().create_timer(8.5).timeout.connect(func() -> void:
			_lingering.erase(root)
			root.queue_free()))
