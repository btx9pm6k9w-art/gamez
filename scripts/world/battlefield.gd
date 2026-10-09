class_name Battlefield
extends Node3D
## The playable map: lighting, sky, terrain, sea, props, navigation and the
## unit roster. Owns damage resolution (blast) and destruction.

signal unit_spawned(unit: Unit)
signal unit_killed(unit: Unit)
signal navigation_ready

const MAP_SIZE := 192
const COALITION := 0
const IRAN := 1

enum TimeOfDay { GOLDEN_HOUR, MIDDAY, NIGHT }

var terrain: Terrain
var environment: Environment
var sun: DirectionalLight3D
var time_of_day := TimeOfDay.GOLDEN_HOUR
var units: Array[Array] = [[], []]
var props: Array[Dictionary] = []

var _world_env: WorldEnvironment
var _physical_sky: PhysicalSkyMaterial
var _night_sky: ProceduralSkyMaterial
var _nav_region: NavigationRegion3D
var _nav_template: NavigationMesh
var _nav_baking := false
var _nav_pending := false
var _nav_ready_emitted := false
var _rebake_timer := -1.0
var _particle_collider: GPUParticlesCollisionHeightField3D
var _wrecks: Node3D
var _burned: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func build(seed_value: int) -> void:
	_rng.seed = seed_value
	_build_environment()
	_build_terrain(seed_value)
	_build_sea()
	_build_skirt()
	_build_props()
	_build_navigation()
	_particle_collider = GPUParticlesCollisionHeightField3D.new()
	_particle_collider.size = Vector3(MAP_SIZE, 60, MAP_SIZE)
	_particle_collider.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_1024
	_particle_collider.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	_particle_collider.position = Vector3(MAP_SIZE * 0.5, 20, MAP_SIZE * 0.5)
	add_child(_particle_collider)
	_wrecks = Node3D.new()
	_wrecks.name = "Wrecks"
	add_child(_wrecks)
	_burned = StandardMaterial3D.new()
	_burned.albedo_color = Color(0.06, 0.055, 0.05)
	_burned.roughness = 0.95
	_burned.metallic = 0.3
	set_time_of_day(TimeOfDay.GOLDEN_HOUR)
	GameSettings.register_world(environment, sun)


# --- Lighting and sky ----------------------------------------------------

func _build_environment() -> void:
	environment = Environment.new()
	_physical_sky = PhysicalSkyMaterial.new()
	_physical_sky.turbidity = 8.0
	_physical_sky.mie_coefficient = 0.008
	_physical_sky.mie_eccentricity = 0.85
	_physical_sky.ground_color = Color(0.42, 0.36, 0.28)
	_physical_sky.sun_disk_scale = 1.6
	_night_sky = ProceduralSkyMaterial.new()
	_night_sky.sky_top_color = Color(0.01, 0.015, 0.035)
	_night_sky.sky_horizon_color = Color(0.05, 0.06, 0.1)
	_night_sky.ground_bottom_color = Color(0.01, 0.01, 0.015)
	_night_sky.ground_horizon_color = Color(0.04, 0.045, 0.07)
	_night_sky.sun_angle_max = 2.0
	var sky := Sky.new()
	sky.sky_material = _physical_sky
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX

	environment.ssr_enabled = true
	environment.ssr_fade_in = 0.15
	environment.ssr_fade_out = 2.0
	environment.ssr_depth_tolerance = 0.3

	environment.ssao_enabled = true
	environment.ssao_radius = 1.4
	environment.ssao_intensity = 2.2
	environment.ssao_power = 1.6
	environment.ssao_detail = 0.6
	environment.ssao_light_affect = 0.15

	environment.ssil_enabled = true
	environment.ssil_radius = 6.0
	environment.ssil_intensity = 1.0

	environment.sdfgi_enabled = true
	environment.sdfgi_use_occlusion = true
	environment.sdfgi_read_sky_light = true
	environment.sdfgi_min_cell_size = 0.25
	environment.sdfgi_cascades = 6
	environment.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	environment.sdfgi_energy = 1.0
	environment.sdfgi_bounce_feedback = 0.5

	environment.glow_enabled = true
	environment.glow_intensity = 0.7
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.1
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for i in 7:
		environment.set_glow_level(i, [0.0, 1.0, 0.8, 1.0, 0.6, 0.3, 0.0][i])

	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_density = 0.0016
	environment.fog_aerial_perspective = 0.6
	environment.fog_sky_affect = 0.25
	environment.fog_height = 3.0
	environment.fog_height_density = 0.02

	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.012
	environment.volumetric_fog_anisotropy = 0.65
	environment.volumetric_fog_length = 180.0
	environment.volumetric_fog_detail_spread = 2.0
	environment.volumetric_fog_gi_inject = 0.6
	environment.volumetric_fog_ambient_inject = 0.05
	environment.volumetric_fog_sky_affect = 0.3
	environment.volumetric_fog_temporal_reprojection_enabled = true

	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 1.08

	_world_env = WorldEnvironment.new()
	_world_env.environment = environment
	add_child(_world_env)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.light_angular_distance = 0.6 # soft contact-hardening shadows
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 200.0
	sun.directional_shadow_blend_splits = true
	sun.light_volumetric_fog_energy = 1.4
	add_child(sun)


func set_time_of_day(t: int) -> void:
	time_of_day = t
	var night := t == TimeOfDay.NIGHT
	match t:
		TimeOfDay.GOLDEN_HOUR:
			sun.rotation_degrees = Vector3(-14.0, -62.0, 0.0)
			sun.light_color = Color(1.0, 0.76, 0.52)
			sun.light_energy = 1.7
			_physical_sky.energy_multiplier = 1.0
			environment.tonemap_exposure = 1.05
			environment.volumetric_fog_albedo = Color(0.95, 0.82, 0.68)
			environment.volumetric_fog_density = 0.014
			environment.fog_light_color = Color(0.85, 0.68, 0.5)
		TimeOfDay.MIDDAY:
			sun.rotation_degrees = Vector3(-62.0, -30.0, 0.0)
			sun.light_color = Color(1.0, 0.97, 0.92)
			sun.light_energy = 2.0
			_physical_sky.energy_multiplier = 1.0
			environment.tonemap_exposure = 0.85
			environment.volumetric_fog_albedo = Color(0.95, 0.92, 0.86)
			environment.volumetric_fog_density = 0.006
			environment.fog_light_color = Color(0.75, 0.78, 0.82)
		TimeOfDay.NIGHT:
			sun.rotation_degrees = Vector3(-38.0, 120.0, 0.0)
			sun.light_color = Color(0.55, 0.65, 1.0)
			sun.light_energy = 0.12
			environment.tonemap_exposure = 2.4
			environment.volumetric_fog_albedo = Color(0.6, 0.65, 0.8)
			environment.volumetric_fog_density = 0.02
			environment.fog_light_color = Color(0.08, 0.1, 0.16)
	environment.sky.sky_material = _night_sky if night else _physical_sky
	environment.ambient_light_energy = 0.4 if night else 1.0
	for light in get_tree().get_nodes_in_group("night_lights"):
		(light as Light3D).visible = night


func cycle_time_of_day() -> void:
	set_time_of_day((time_of_day + 1) % 3)


# --- Terrain, sea and skirt ----------------------------------------------

var _noise_cache := {}


func _noise_texture(seed_value: int, freq: float, normal_map: bool, size := 512) -> NoiseTexture2D:
	var key := "%d_%f_%s_%d" % [seed_value, freq, normal_map, size]
	if _noise_cache.has(key):
		return _noise_cache[key]
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	n.fractal_octaves = 5
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = n
	t.as_normal_map = normal_map
	t.bump_strength = 6.0
	_noise_cache[key] = t
	return t


func _terrain_material(scorch: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/terrain.gdshader")
	m.set_shader_parameter("detail_noise", _noise_texture(11, 0.02, false))
	m.set_shader_parameter("detail_normal", _noise_texture(12, 0.04, true))
	m.set_shader_parameter("use_vertex_scorch", scorch)
	return m


func _build_terrain(seed_value: int) -> void:
	terrain = Terrain.new()
	terrain.name = "Terrain"
	terrain.material = _terrain_material(true)
	add_child(terrain)
	terrain.generate(seed_value)
	terrain.deformed.connect(_on_terrain_deformed)


func _build_sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(700, 700)
	plane.subdivide_width = 96
	plane.subdivide_depth = 96
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water.gdshader")
	m.set_shader_parameter("wave_normal_a", _noise_texture(21, 0.03, true, 256))
	m.set_shader_parameter("wave_normal_b", _noise_texture(22, 0.06, true, 256))
	m.set_shader_parameter("foam_noise", _noise_texture(23, 0.05, false, 256))
	m.set_shader_parameter("terrain_height", terrain.height_texture)
	m.set_shader_parameter("map_size", float(MAP_SIZE))
	plane.material = m
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = plane
	sea.position = Vector3(0, Terrain.WATER_LEVEL, MAP_SIZE * 0.5)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)


## Flat land beyond the playable edge so the horizon never shows a cliff.
func _build_skirt() -> void:
	var m := _terrain_material(false)
	for r: Rect2 in [Rect2(40, -900, 1200, 900), Rect2(40, MAP_SIZE, 1200, 900), Rect2(MAP_SIZE, 0, 1100, MAP_SIZE)]:
		var plane := PlaneMesh.new()
		plane.size = r.size
		plane.material = m
		var mi := MeshInstance3D.new()
		mi.mesh = plane
		mi.position = Vector3(r.position.x + r.size.x * 0.5, 0.98, r.position.y + r.size.y * 0.5)
		add_child(mi)
	# Distant mountain silhouettes to the north, softened by fog.
	for i in 7:
		var rock := MeshInstance3D.new()
		rock.mesh = _rock_mesh(100 + i)
		rock.material_override = m
		rock.position = Vector3(30 + i * 45 + _rng.randf_range(-15, 15), -6, -90 - _rng.randf_range(0, 120))
		rock.scale = Vector3(_rng.randf_range(40, 70), _rng.randf_range(25, 50), _rng.randf_range(30, 50))
		add_child(rock)


# --- Props ---------------------------------------------------------------

func _rock_mesh(seed_value: int) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 14
	sphere.rings = 8
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = 2.2
	for i in verts.size():
		var v := verts[i]
		var k := 1.0 + n.get_noise_3dv(v * 1.0) * 0.45
		v *= k
		v.y = maxf(v.y, -0.15)
		verts[i] = v
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = null
	arrays[Mesh.ARRAY_TANGENT] = null
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.deindex() # faceted, chiselled look
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


func _palm_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.42, 0.34, 0.24)
	trunk_mat.roughness = 0.95
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.22, 0.34, 0.12)
	leaf_mat.roughness = 0.7
	leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaf_mat.backlight_enabled = true
	leaf_mat.backlight = Color(0.25, 0.35, 0.1)
	var st_trunk := SurfaceTool.new()
	st_trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_trunk.set_material(trunk_mat)
	var st_leaf := SurfaceTool.new()
	st_leaf.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_leaf.set_material(leaf_mat)
	var height := rng.randf_range(7.0, 10.0)
	var lean := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.6, 1.6)
	var segments := 6
	var top := Vector3.ZERO
	for s in segments:
		var t0 := float(s) / segments
		var t1 := float(s + 1) / segments
		var p0 := Vector3.UP * height * t0 + lean * t0 * t0
		var p1 := Vector3.UP * height * t1 + lean * t1 * t1
		var seg := CylinderMesh.new()
		seg.top_radius = lerpf(0.24, 0.16, t1)
		seg.bottom_radius = lerpf(0.26, 0.17, t0) + 0.03
		seg.height = p0.distance_to(p1) + 0.05
		seg.radial_segments = 8
		seg.rings = 1
		var xf := Transform3D(Basis(Quaternion(Vector3.UP, (p1 - p0).normalized())), (p0 + p1) * 0.5)
		st_trunk.append_from(seg, 0, xf)
		top = p1
	for f in 9:
		var frond := PrismMesh.new()
		frond.size = Vector3(0.9, 4.2, 0.04)
		var yaw := TAU * f / 9.0 + rng.randf_range(-0.2, 0.2)
		var droop := deg_to_rad(rng.randf_range(55, 80))
		var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, droop)
		var xf := Transform3D(b, top + b * Vector3(0, 2.0, 0))
		st_leaf.append_from(frond, 0, xf)
	var mesh := st_trunk.commit()
	st_leaf.commit(mesh)
	return mesh


func _add_prop(node: Node3D, kind: String, radius: float, hp: float) -> void:
	node.add_to_group("props")
	add_child(node)
	props.append({"node": node, "kind": kind, "radius": radius, "hp": hp, "alive": true})


func _random_land_point(minx: float, maxx: float, minz: float, maxz: float, max_slope := 0.25) -> Vector3:
	for attempt in 30:
		var p := Vector3(_rng.randf_range(minx, maxx), 0, _rng.randf_range(minz, maxz))
		if terrain.height_at(p) > 0.6 and terrain.slope_at(p) < max_slope:
			p.y = terrain.height_at(p)
			return p
	return Vector3.INF


func _clear_of_bases(p: Vector3) -> bool:
	for c in [Vector3(64, 0, 160), Vector3(150, 0, 52), Vector3(100, 0, 100)]:
		if Vector2(p.x, p.z).distance_to(Vector2(c.x, c.z)) < 16.0:
			return false
	return true


func _build_props() -> void:
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.5, 0.44, 0.38)
	rock_mat.roughness = 0.9
	rock_mat.uv1_triplanar = true
	rock_mat.normal_enabled = true
	rock_mat.normal_texture = _noise_texture(31, 0.08, true, 256)
	var rock_meshes: Array[ArrayMesh] = []
	for i in 4:
		rock_meshes.append(_rock_mesh(40 + i))
	for i in 55:
		var p := _random_land_point(45, 188, 4, 188, 0.6)
		if p == Vector3.INF or not _clear_of_bases(p):
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = rock_meshes[i % 4]
		mi.material_override = rock_mat
		var s := _rng.randf_range(1.2, 4.0)
		mi.scale = Vector3(s * _rng.randf_range(0.8, 1.4), s * _rng.randf_range(0.5, 1.0), s)
		mi.rotation.y = _rng.randf() * TAU
		mi.position = p + Vector3.DOWN * 0.2 * s
		_add_prop(mi, "rock", s * 0.55, 600.0)

	var palms: Array[ArrayMesh] = []
	for i in 3:
		palms.append(_palm_mesh(70 + i))
	for i in 70:
		# Palms gather along the coast and in the village oasis.
		var p := _random_land_point(42, 80, 8, 188) if i < 35 else _random_land_point(80, 125, 78, 122)
		if p == Vector3.INF or p.y > 6.0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = palms[i % 3]
		mi.rotation.y = _rng.randf() * TAU
		mi.scale = Vector3.ONE * _rng.randf_range(0.8, 1.2)
		mi.position = p
		_add_prop(mi, "palm", 0.6, 60.0)

	# Village: flat-roof houses around the central square.
	for i in 10:
		var ang := TAU * i / 10.0 + _rng.randf_range(-0.15, 0.15)
		var d := _rng.randf_range(8.0, 15.0)
		var p := Vector3(100 + cos(ang) * d, 0, 100 + sin(ang) * d)
		p.y = terrain.height_at(p)
		var house := _house(Vector3(_rng.randf_range(5, 8), _rng.randf_range(3.2, 6.5), _rng.randf_range(5, 8)))
		house.position = p
		house.rotation.y = ang + PI * 0.5
		_add_prop(house, "building", 3.8, 500.0)

	# Fuel storage at the coalition beachhead: explodes spectacularly.
	for i in 3:
		var p := Vector3(52 + i * 7.0, 0, 176)
		p.y = terrain.height_at(p)
		var tank := _fuel_tank()
		tank.position = p
		_add_prop(tank, "fuel_tank", 3.2, 250.0)

	# Concrete T-wall barriers around both bases.
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.62, 0.6, 0.56)
	wall_mat.roughness = 0.85
	for base in [Vector3(64, 0, 160), Vector3(150, 0, 52)]:
		for i in 14:
			var ang := TAU * i / 18.0 + 0.9
			var p: Vector3 = base + Vector3(cos(ang), 0, sin(ang)) * 17.0
			p.y = terrain.height_at(p)
			var wall := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(3.2, 3.4, 0.5)
			wall.mesh = bm
			wall.material_override = wall_mat
			wall.position = p + Vector3.UP * 1.6
			wall.rotation.y = -ang + PI * 0.5
			_add_prop(wall, "wall", 1.7, 300.0)


func _house(size: Vector3) -> Node3D:
	var root := Node3D.new()
	var plaster := StandardMaterial3D.new()
	plaster.albedo_color = Color(0.78, 0.72, 0.62).darkened(_rng.randf_range(0.0, 0.15))
	plaster.roughness = 0.9
	plaster.uv1_triplanar = true
	plaster.roughness_texture = _noise_texture(51, 0.1, false, 128)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.07, 0.06)
	dark.roughness = 0.6
	var body := BoxMesh.new()
	body.size = size
	_mesh_child(root, body, Vector3(0, size.y * 0.5, 0), plaster)
	var parapet := BoxMesh.new()
	parapet.size = Vector3(size.x + 0.2, 0.5, size.z + 0.2)
	_mesh_child(root, parapet, Vector3(0, size.y + 0.25, 0), plaster)
	var roof_inset := BoxMesh.new()
	roof_inset.size = Vector3(size.x - 0.4, 0.3, size.z - 0.4)
	_mesh_child(root, roof_inset, Vector3(0, size.y + 0.4, 0), plaster)
	var door := BoxMesh.new()
	door.size = Vector3(1.1, 2.1, 0.1)
	_mesh_child(root, door, Vector3(0, 1.05, -size.z * 0.5 - 0.03), dark)
	var windows := int(size.x / 2.2)
	for floor_i in int(size.y / 3.0):
		for w in windows:
			var win := BoxMesh.new()
			win.size = Vector3(0.8, 1.0, 0.1)
			var x := -size.x * 0.5 + (w + 0.5) * size.x / windows
			if floor_i == 0 and absf(x) < 0.8:
				continue
			_mesh_child(root, win, Vector3(x, 1.6 + floor_i * 3.0, -size.z * 0.5 - 0.03), dark)
	var tank := CylinderMesh.new()
	tank.top_radius = 0.5
	tank.bottom_radius = 0.5
	tank.height = 1.0
	_mesh_child(root, tank, Vector3(size.x * 0.25, size.y + 1.0, size.z * 0.2), dark)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = 2.5
	light.omni_range = 9.0
	light.position = Vector3(0, 2.4, -size.z * 0.5 - 1.0)
	light.visible = false
	light.add_to_group("night_lights")
	root.add_child(light)
	return root


func _fuel_tank() -> Node3D:
	var root := Node3D.new()
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.85, 0.85, 0.82)
	white.metallic = 0.6
	white.roughness = 0.35
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.8
	cyl.bottom_radius = 2.8
	cyl.height = 4.5
	cyl.radial_segments = 32
	_mesh_child(root, cyl, Vector3(0, 2.25, 0), white)
	var roof := SphereMesh.new()
	roof.radius = 2.8
	roof.height = 1.2
	roof.is_hemisphere = true
	_mesh_child(root, roof, Vector3(0, 4.5, 0), white)
	return root


func _mesh_child(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


func _destroy_prop(prop: Dictionary) -> void:
	prop["alive"] = false
	var node: Node3D = prop["node"]
	var pos := node.global_position
	match prop["kind"]:
		"palm":
			# Trees topple away from the blast and stay as debris.
			var tw := create_tween()
			tw.tween_property(node, "rotation:z", deg_to_rad(_rng.randf_range(70, 88)) * (1 if _rng.randf() > 0.5 else -1), 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		"fuel_tank":
			VFX.explosion(pos + Vector3.UP * 2.0, 5.0)
			VFX.burning(pos + Vector3.UP * 1.0, 25.0, 2.5)
			blast(pos, 200.0, 9.0, 3.0, -1, 0.0)
			node.queue_free()
		"building":
			VFX.explosion(pos + Vector3.UP * 2.0, 3.0)
			_rubble(node)
		_:
			VFX.explosion(pos + Vector3.UP, 1.4)
			node.queue_free()
	_schedule_rebake()


func _rubble(node: Node3D) -> void:
	# Collapse: the building sinks and leaves a low pile of broken slabs.
	for c in node.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = _burned
	var tw := create_tween()
	tw.tween_property(node, "scale:y", 0.22, 1.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
	VFX.burning(node.global_position + Vector3.UP, 15.0, 1.5)


# --- Navigation ----------------------------------------------------------

func _build_navigation() -> void:
	_nav_region = NavigationRegion3D.new()
	_nav_region.name = "Navigation"
	add_child(_nav_region)
	_nav_template = NavigationMesh.new()
	_nav_template.cell_size = 0.5
	_nav_template.cell_height = 0.25
	_nav_template.agent_radius = 1.0
	_nav_template.agent_height = 2.0
	_nav_template.agent_max_climb = 0.75
	_nav_template.agent_max_slope = 38.0
	_nav_template.edge_max_error = 1.3
	_nav_template.detail_sample_distance = 4.0
	_nav_template.filter_baking_aabb = AABB(Vector3(0, -8, 0), Vector3(MAP_SIZE, 60, MAP_SIZE))
	rebake_navigation()


func rebake_navigation() -> void:
	if _nav_baking:
		_nav_pending = true
		return
	_nav_baking = true
	var src := NavigationMeshSourceGeometryData3D.new()
	src.add_faces(terrain.build_nav_faces(), Transform3D.IDENTITY)
	for prop in props:
		if not prop["alive"] or prop["kind"] == "palm":
			continue
		var node: Node3D = prop["node"]
		var c := node.global_position
		var r: float = prop["radius"] + 0.3
		var poly := PackedVector3Array()
		for k in 8:
			var a := TAU * k / 8.0
			poly.append(Vector3(c.x + cos(a) * r, 0, c.z + sin(a) * r))
		src.add_projected_obstruction(poly, c.y - 3.0, 10.0, false)
	var nm := _nav_template.duplicate() as NavigationMesh
	NavigationServer3D.bake_from_source_geometry_data_async(nm, src, _on_nav_baked.bind(nm))


func _on_nav_baked(nm: NavigationMesh) -> void:
	_apply_navmesh.call_deferred(nm)


func _apply_navmesh(nm: NavigationMesh) -> void:
	_nav_region.navigation_mesh = nm
	_nav_baking = false
	if not _nav_ready_emitted:
		_nav_ready_emitted = true
		navigation_ready.emit()
	if _nav_pending:
		_nav_pending = false
		rebake_navigation()


func _schedule_rebake() -> void:
	if _rebake_timer < 0.0:
		_rebake_timer = 1.0


func _process(delta: float) -> void:
	if _rebake_timer >= 0.0:
		_rebake_timer -= delta
		if _rebake_timer < 0.0:
			rebake_navigation()


func _on_terrain_deformed(_center: Vector3, _radius: float) -> void:
	_schedule_rebake()
	# Nudge the particle collider so it re-renders the new ground.
	_particle_collider.position.x = MAP_SIZE * 0.5 + (0.001 if _particle_collider.position.x <= MAP_SIZE * 0.5 else 0.0)


# --- Units and combat ----------------------------------------------------

func spawn_unit(id: String, team: int, pos: Vector3, yaw := 0.0) -> Unit:
	var u := Unit.new()
	u.setup(id, team, self)
	u.name = "%s_%d" % [id, u.get_instance_id()]
	u.rotation.y = yaw
	add_child(u)
	if not u.is_air:
		pos.y = terrain.height_at(pos)
	u.global_position = pos
	units[team].append(u)
	u.died.connect(_on_unit_died)
	if time_of_day == TimeOfDay.NIGHT:
		for light in u.find_children("*", "SpotLight3D", true, false):
			(light as Light3D).visible = true
	unit_spawned.emit(u)
	return u


func _on_unit_died(u: Unit) -> void:
	units[u.team].erase(u)
	unit_killed.emit(u)


func find_target(seeker: Unit, radius: float) -> Unit:
	var best: Unit = null
	var best_d := radius
	var enemy_team := 1 - seeker.team
	for other: Unit in units[enemy_team]:
		if not is_instance_valid(other) or not other.is_alive() or not seeker._can_target(other):
			continue
		var d := seeker.global_position.distance_to(other.global_position)
		if d < best_d:
			best_d = d
			best = other
	return best


## Explosion with splash damage, crater and prop destruction. team is the
## attacker's team (friendly units are spared); -1 hurts everyone.
func blast(pos: Vector3, damage: float, splash: float, crater: float, team: int, fx_size: float) -> void:
	if fx_size > 0.0:
		VFX.explosion(pos, fx_size, VFX.Surface.GROUND if terrain.is_land(pos) else VFX.Surface.WATER)
	if crater > 0.0 and terrain.is_land(pos):
		terrain.deform(pos, crater, crater * 0.45)
		VFX.scorch(pos, crater * 1.4)
	var reach := maxf(splash, 1.0)
	for t in 2:
		if t == team:
			continue
		for u: Unit in units[t].duplicate():
			if not is_instance_valid(u) or not u.is_alive():
				continue
			var d := u.global_position.distance_to(pos)
			if u.is_air and d > reach * 0.5:
				continue
			if d <= reach:
				u.take_damage(damage * lerpf(1.0, 0.3, d / reach), team if team >= 0 else 1 - t)
	for prop in props:
		if not prop["alive"]:
			continue
		var node: Node3D = prop["node"]
		var d := Vector2(node.global_position.x - pos.x, node.global_position.z - pos.z).length()
		if d <= reach + float(prop["radius"]):
			prop["hp"] = float(prop["hp"]) - damage
			if prop["hp"] <= 0.0:
				_destroy_prop.call_deferred(prop)
				prop["alive"] = false


## Keeps a burning hull where a vehicle died.
func leave_wreck(model: Node3D, xform: Transform3D) -> void:
	model.get_parent().remove_child(model)
	_wrecks.add_child(model)
	model.global_transform = xform
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = _burned
	for l in model.find_children("*", "Light3D", true, false):
		l.queue_free()
	var turret := model.find_child("Turret", true, false) as Node3D
	if turret:
		var tw := create_tween()
		tw.tween_property(turret, "position", turret.position + Vector3(_rng.randf_range(-1, 1), 1.2, _rng.randf_range(-1, 1)), 0.25)
		tw.parallel().tween_property(turret, "rotation", Vector3(_rng.randf_range(-0.6, 0.6), turret.rotation.y + 0.8, _rng.randf_range(-0.6, 0.6)), 0.25)
		tw.tween_property(turret, "position:y", turret.position.y + 0.2, 0.3)
	VFX.burning(xform.origin + Vector3.UP * 1.2, 20.0, 1.2)
	var sink := create_tween()
	sink.tween_interval(40.0)
	sink.tween_property(model, "position:y", model.position.y - 3.0, 6.0)
	sink.tween_callback(model.queue_free)
