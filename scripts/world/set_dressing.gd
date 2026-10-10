class_name SetDressing
## Procedural builders for the map's landmarks and vegetation: ghaf trees,
## mangroves, desert shrubs, sandstone pillars, an oil-field pumpjack, a flare
## stack, an offshore platform, a lighthouse, the coalition pier, shipping
## containers, a fishing dhow and the big ships that pass far out in the
## Strait. Stand-ins until the art pass, but built to read well from the RTS
## camera: strong silhouettes, PBR materials and lights that come on at night.

static var _mats := {}


static func mat(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"bark":
			m.albedo_color = Color(0.36, 0.3, 0.24)
			m.roughness = 0.95
		"ghaf_leaf":
			m.albedo_color = Color(0.3, 0.38, 0.18)
			m.roughness = 0.8
			m.backlight_enabled = true
			m.backlight = Color(0.2, 0.28, 0.08)
		"mangrove":
			m.albedo_color = Color(0.14, 0.24, 0.12)
			m.roughness = 0.6
			m.backlight_enabled = true
			m.backlight = Color(0.1, 0.2, 0.05)
		"root":
			m.albedo_color = Color(0.22, 0.18, 0.14)
			m.roughness = 0.9
		"shrub":
			m.albedo_color = Color(0.46, 0.44, 0.28)
			m.roughness = 0.95
			m.backlight_enabled = true
			m.backlight = Color(0.25, 0.22, 0.1)
		"sandstone":
			m.albedo_color = Color(0.72, 0.5, 0.34)
			m.roughness = 0.92
			m.uv1_triplanar = true
		"steel":
			m.albedo_color = Color(0.42, 0.43, 0.44)
			m.metallic = 0.85
			m.roughness = 0.4
		"rust":
			m.albedo_color = Color(0.38, 0.2, 0.12)
			m.metallic = 0.5
			m.roughness = 0.75
		"yellow":
			m.albedo_color = Color(0.85, 0.65, 0.12)
			m.metallic = 0.4
			m.roughness = 0.5
		"white":
			m.albedo_color = Color(0.88, 0.88, 0.85)
			m.roughness = 0.6
		"red":
			m.albedo_color = Color(0.6, 0.1, 0.08)
			m.roughness = 0.6
		"concrete":
			m.albedo_color = Color(0.6, 0.58, 0.54)
			m.roughness = 0.88
		"wood":
			m.albedo_color = Color(0.45, 0.3, 0.18)
			m.roughness = 0.85
		"hull_grey":
			m.albedo_color = Color(0.42, 0.45, 0.48)
			m.metallic = 0.5
			m.roughness = 0.5
		"hull_dark":
			m.albedo_color = Color(0.12, 0.13, 0.15)
			m.metallic = 0.5
			m.roughness = 0.55
		"lamp":
			m.albedo_color = Color(1.0, 0.85, 0.5)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.8, 0.45)
			m.emission_energy_multiplier = 6.0
	_mats[key] = m
	return m


## Merge the static meshes directly under root into one MeshInstance3D with a
## surface per material. A ghaf tree goes from about 10 draw calls to 2; the
## battlefield has hundreds of these props, so this keeps the scene from being
## draw-call bound. Pivots (Beam, Lamp, FlareTip...) and their children are
## left alone so animation still works.
static func bake(root: Node3D) -> Node3D:
	var by_mat := {}
	var merged: Array[MeshInstance3D] = []
	for c in root.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null or mi.get_child_count() > 0:
			continue
		for si in mi.mesh.get_surface_count():
			var m: Material = mi.material_override if mi.material_override else mi.mesh.surface_get_material(si)
			if not by_mat.has(m):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_material(m)
				by_mat[m] = st
			(by_mat[m] as SurfaceTool).append_from(mi.mesh, si, mi.transform)
		merged.append(mi)
	if merged.size() < 2:
		return root
	var am := ArrayMesh.new()
	for m in by_mat:
		var st: SurfaceTool = by_mat[m]
		st.set_material(m)
		am = st.commit(am)
	for mi in merged:
		root.remove_child(mi)
		mi.free()
	var baked := MeshInstance3D.new()
	baked.name = "Baked"
	baked.mesh = am
	root.add_child(baked)
	root.move_child(baked, 0)
	return root


static func _mi(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mi(parent, b, pos, material, rot)


static func _cyl(parent: Node3D, r_top: float, r_bottom: float, h: float, pos: Vector3, material: Material, rot := Vector3.ZERO, sides := 12) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return _mi(parent, c, pos, material, rot)


static func _blob(parent: Node3D, r: float, pos: Vector3, material: Material, squash := 0.6) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 6
	return _mi(parent, s, pos, material, Vector3.ZERO, Vector3(1.0, squash, 1.0))


static func _night_light(parent: Node3D, pos: Vector3, color: Color, energy: float, reach: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.visible = false
	l.add_to_group("night_lights")
	parent.add_child(l)


# --- Vegetation ------------------------------------------------------------

## Ghaf / acacia: twisted trunk splitting into branches under a wide, flat
## umbrella canopy, the signature tree of the UAE desert.
static func ghaf(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var h := rng.randf_range(3.2, 5.0)
	var lean := rng.randf_range(-0.25, 0.25)
	_cyl(root, 0.16, 0.26, h, Vector3(0, h * 0.5, 0), mat("bark"), Vector3(0, 0, lean), 7)
	var top := Vector3(-sin(lean) * h, h, 0)
	for b in 3:
		var a := TAU * b / 3.0 + rng.randf()
		var dir := Vector3(cos(a), 0.9, sin(a)).normalized()
		var blen := rng.randf_range(1.4, 2.2)
		var branch := _cyl(root, 0.06, 0.12, blen, top + dir * blen * 0.5, mat("bark"), Vector3.ZERO, 5)
		branch.basis = Basis(Quaternion(Vector3.UP, dir))
	var w := rng.randf_range(2.6, 3.8)
	for c in 5:
		var off := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.0, 0.4), rng.randf_range(-1, 1)) * w * 0.55
		_blob(root, w * rng.randf_range(0.45, 0.65), top + Vector3.UP * 1.1 + off, mat("ghaf_leaf"), 0.32)
	return bake(root)


## Grey mangrove clump: dense dark canopy standing on arching stilt roots.
static func mangrove(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	for r in 6:
		var a := TAU * r / 6.0
		var stilt := _cyl(root, 0.04, 0.06, 1.4, Vector3(cos(a) * 0.6, 0.5, sin(a) * 0.6), mat("root"), Vector3.ZERO, 4)
		stilt.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)
	for c in 4:
		var off := Vector3(rng.randf_range(-1, 1), rng.randf_range(0, 0.5), rng.randf_range(-1, 1)) * 1.1
		_blob(root, rng.randf_range(1.0, 1.5), Vector3.UP * 1.9 + off, mat("mangrove"), 0.7)
	return bake(root)


## Low desert shrub mesh used for the instanced scatter.
static func shrub_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat("shrub"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 4:
		var s := SphereMesh.new()
		s.radius = 0.35
		s.height = 0.5
		s.radial_segments = 7
		s.rings = 4
		var off := Vector3(rng.randf_range(-0.3, 0.3), 0.2, rng.randf_range(-0.3, 0.3))
		st.append_from(s, 0, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.7, 1.2)), off))
	st.generate_normals()
	return st.commit()


# --- Rock formations -------------------------------------------------------

## Wind-eroded sandstone pillar: stacked, offset slabs that narrow at the waist.
static func sandstone_pillar(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var y := 0.0
	var tiers := rng.randi_range(4, 6)
	for t in tiers:
		var k := float(t) / tiers
		var r := lerpf(2.4, 1.4, sin(k * PI)) * rng.randf_range(0.85, 1.15)
		if t == tiers - 1:
			r *= 1.5 # mushroom cap
		var h := rng.randf_range(1.4, 2.4)
		var slab := _cyl(root, r * 0.92, r, h, Vector3(rng.randf_range(-0.3, 0.3), y + h * 0.5, rng.randf_range(-0.3, 0.3)), mat("sandstone"), Vector3(0, rng.randf() * TAU, 0), 7)
		slab.scale = Vector3(1.0, 1.0, rng.randf_range(0.7, 1.0))
		y += h * 0.95
	return bake(root)


# --- Industry --------------------------------------------------------------

## Oil pumpjack ("nodding donkey"). The walking beam pivot is named Beam so the
## battlefield can animate it.
static func pumpjack() -> Node3D:
	var root := Node3D.new()
	_box(root, Vector3(2.2, 0.4, 6.0), Vector3(0, 0.2, 0), mat("concrete"))
	for s in [-1.0, 1.0]:
		var leg := _box(root, Vector3(0.2, 4.2, 0.2), Vector3(0.7 * s, 2.2, 0.4), mat("yellow"))
		leg.rotation.z = -0.12 * s
	var beam := Node3D.new()
	beam.name = "Beam"
	beam.position = Vector3(0, 4.3, 0.4)
	root.add_child(beam)
	_box(beam, Vector3(0.35, 0.5, 6.4), Vector3(0, 0, -0.4), mat("yellow"))
	var head := _cyl(beam, 1.1, 1.1, 0.5, Vector3(0, -0.3, -3.6), mat("yellow"), Vector3(0, 0, PI * 0.5), 16)
	head.scale = Vector3(1, 1, 0.6)
	_box(beam, Vector3(0.1, 4.0, 0.1), Vector3(0, -2.2, -4.1), mat("steel")) # bridle
	_box(root, Vector3(1.4, 1.6, 1.6), Vector3(0, 0.9, 2.4), mat("rust")) # gearbox
	_cyl(root, 0.18, 0.18, 2.0, Vector3(0, 1.0, -3.7), mat("steel"))
	return bake(root)


## Gas flare stack; the battlefield puts a permanent fire on top.
static func flare_stack(height: float) -> Node3D:
	var root := Node3D.new()
	_cyl(root, 0.35, 0.5, height, Vector3(0, height * 0.5, 0), mat("steel"), Vector3.ZERO, 10)
	for i in int(height / 4.0):
		_cyl(root, 0.6, 0.6, 0.15, Vector3(0, 2.0 + i * 4.0, 0), mat("red" if i % 2 == 0 else "white"), Vector3.ZERO, 10)
	_night_light(root, Vector3(0, height + 0.5, 0), Color(1.0, 0.25, 0.15), 1.5, 4.0)
	return bake(root)


## Offshore wellhead platform: four legs, two decks, a derrick, helipad,
## crane and flare boom.
static func offshore_platform() -> Node3D:
	var root := Node3D.new()
	for x in [-5.0, 5.0]:
		for z in [-5.0, 5.0]:
			_cyl(root, 0.6, 0.8, 16.0, Vector3(x, 2.0, z), mat("rust"), Vector3.ZERO, 10)
			_box(root, Vector3(0.25, 0.25, 10.0), Vector3(x, 3.0, 0), mat("rust"), Vector3(0.6, 0, 0))
	_box(root, Vector3(14.0, 1.0, 14.0), Vector3(0, 10.5, 0), mat("steel"))
	_box(root, Vector3(13.0, 3.0, 9.0), Vector3(0, 12.5, -1.5), mat("white"))
	_box(root, Vector3(14.0, 0.6, 14.0), Vector3(0, 14.3, 0), mat("steel"))
	var helipad := _cyl(root, 4.0, 4.0, 0.3, Vector3(3.5, 15.0, 3.5), mat("hull_dark"), Vector3.ZERO, 24)
	_cyl(helipad, 2.6, 2.6, 0.05, Vector3(0, 0.18, 0), mat("yellow"), Vector3.ZERO, 24)
	for i in 6: # derrick lattice
		var y := 15.0 + i * 2.2
		var w := lerpf(3.0, 0.8, float(i) / 6.0)
		_box(root, Vector3(w, 0.15, 0.15), Vector3(-3.5, y, -3.5 - w * 0.5), mat("yellow"))
		_box(root, Vector3(w, 0.15, 0.15), Vector3(-3.5, y, -3.5 + w * 0.5), mat("yellow"))
		_box(root, Vector3(0.15, 2.3, 0.15), Vector3(-3.5 - w * 0.5, y + 1.1, -3.5), mat("yellow"))
		_box(root, Vector3(0.15, 2.3, 0.15), Vector3(-3.5 + w * 0.5, y + 1.1, -3.5), mat("yellow"))
	var boom := _box(root, Vector3(0.4, 0.4, 12.0), Vector3(-6.0, 16.0, 8.0), mat("steel"))
	boom.rotation = Vector3(0.4, -0.6, 0)
	var tip := Marker3D.new()
	tip.name = "FlareTip"
	tip.position = Vector3(0, 0.6, 6.0)
	boom.add_child(tip)
	var crane := _box(root, Vector3(0.5, 0.5, 9.0), Vector3(5.0, 17.5, -4.0), mat("yellow"))
	crane.rotation = Vector3(-0.5, 0.7, 0)
	for p in [Vector3(-7, 11, -7), Vector3(7, 11, 7), Vector3(-7, 15, 7)]:
		_night_light(root, p, Color(1.0, 0.85, 0.55), 3.0, 14.0)
	return bake(root)


# --- Coast -----------------------------------------------------------------

## Lighthouse: white tower with red bands and a lamp room whose light sweeps
## at night (the lamp pivot is named Lamp).
static func lighthouse() -> Node3D:
	var root := Node3D.new()
	_cyl(root, 1.2, 1.8, 13.0, Vector3(0, 6.5, 0), mat("white"), Vector3.ZERO, 16)
	for i in 3:
		_cyl(root, 1.35 - i * 0.12, 1.45 - i * 0.12, 1.2, Vector3(0, 3.0 + i * 3.5, 0), mat("red"), Vector3.ZERO, 16)
	_cyl(root, 1.5, 1.5, 0.3, Vector3(0, 13.1, 0), mat("hull_dark"), Vector3.ZERO, 16)
	_cyl(root, 0.9, 0.9, 1.4, Vector3(0, 14.0, 0), mat("lamp"), Vector3.ZERO, 12)
	_cyl(root, 0.1, 1.1, 1.0, Vector3(0, 15.2, 0), mat("red"), Vector3.ZERO, 12)
	var lamp := Node3D.new()
	lamp.name = "Lamp"
	lamp.position = Vector3(0, 14.0, 0)
	root.add_child(lamp)
	var beam := SpotLight3D.new()
	beam.light_color = Color(1.0, 0.92, 0.75)
	beam.light_energy = 12.0
	beam.spot_range = 120.0
	beam.spot_angle = 9.0
	beam.light_volumetric_fog_energy = 4.0
	beam.rotation.x = -0.12
	beam.visible = false
	beam.add_to_group("night_lights")
	lamp.add_child(beam)
	return bake(root)


## Concrete pier on pylons with bollards and lamp posts. Extends along -X.
static func pier(length: float) -> Node3D:
	var root := Node3D.new()
	_box(root, Vector3(length, 0.6, 5.0), Vector3(-length * 0.5, 1.4, 0), mat("concrete"))
	var i := 0.0
	while i < length:
		for z in [-2.0, 2.0]:
			_cyl(root, 0.3, 0.3, 6.0, Vector3(-i, -1.6, z), mat("concrete"), Vector3.ZERO, 8)
			_cyl(root, 0.15, 0.2, 0.5, Vector3(-i, 1.9, z * 1.1), mat("hull_dark"), Vector3.ZERO, 8)
		if int(i) % 12 == 0:
			_cyl(root, 0.06, 0.08, 4.0, Vector3(-i, 3.7, 2.2), mat("steel"), Vector3.ZERO, 6)
			_night_light(root, Vector3(-i, 5.6, 2.0), Color(1.0, 0.8, 0.5), 2.5, 10.0)
		i += 6.0
	return bake(root)


static func container(color: Color) -> Node3D:
	var root := Node3D.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.6
	m.roughness = 0.55
	_box(root, Vector3(2.44, 2.6, 6.06), Vector3(0, 1.3, 0), m)
	for x in [-1.0, 1.0]:
		for k in 8:
			_box(root, Vector3(0.05, 2.4, 0.1), Vector3(1.24 * x, 1.3, -2.6 + k * 0.75), m)
	return bake(root)


## Wooden fishing dhow with a raked bow, high stern and a short mast.
static func dhow() -> Node3D:
	var root := Node3D.new()
	_box(root, Vector3(3.0, 1.4, 10.0), Vector3(0, 0.2, 0), mat("wood"))
	_box(root, Vector3(2.2, 1.2, 3.0), Vector3(0, 0.6, -5.6), mat("wood"), Vector3(-0.6, 0, 0))
	_box(root, Vector3(3.2, 1.6, 2.4), Vector3(0, 1.3, 3.8), mat("wood"))
	_box(root, Vector3(2.4, 1.6, 2.0), Vector3(0, 2.6, 3.8), mat("white"))
	_cyl(root, 0.1, 0.14, 7.0, Vector3(0, 4.2, -1.5), mat("wood"), Vector3(-0.15, 0, 0), 6)
	return bake(root)


## Far-off shipping that sells the scale of the Strait: a VLCC tanker or a
## grey destroyer, as simple silhouettes with deck lights.
static func big_ship(kind: String) -> Node3D:
	var root := Node3D.new()
	if kind == "tanker":
		_box(root, Vector3(44.0, 14.0, 300.0), Vector3(0, 2.0, 0), mat("red"))
		_box(root, Vector3(44.2, 6.0, 300.2), Vector3(0, 7.0, 0), mat("hull_dark"))
		_box(root, Vector3(40.0, 0.5, 280.0), Vector3(0, 10.2, -8.0), mat("rust"))
		_box(root, Vector3(36.0, 18.0, 18.0), Vector3(0, 19.0, 128.0), mat("white"))
		_cyl(root, 2.8, 3.2, 12.0, Vector3(0, 32.0, 136.0), mat("hull_dark"))
		for z in range(-120, 120, 30):
			_box(root, Vector3(1.0, 1.0, 26.0), Vector3(0, 11.0, z), mat("steel"))
		_night_light(root, Vector3(0, 30.0, 120.0), Color(1.0, 0.85, 0.6), 8.0, 60.0)
	else:
		_box(root, Vector3(20.0, 8.0, 150.0), Vector3(0, 1.0, 0), mat("hull_grey"))
		_box(root, Vector3(14.0, 4.0, 30.0), Vector3(0, -2.0, -70.0), mat("hull_grey"), Vector3(0.12, 0, 0))
		_box(root, Vector3(16.0, 12.0, 34.0), Vector3(0, 11.0, -5.0), mat("hull_grey"))
		_box(root, Vector3(9.0, 10.0, 10.0), Vector3(0, 22.0, -10.0), mat("hull_grey"))
		_cyl(root, 0.6, 0.8, 16.0, Vector3(0, 33.0, -10.0), mat("hull_grey"))
		_cyl(root, 2.0, 2.4, 3.0, Vector3(0, 6.5, -50.0), mat("hull_grey"))
		_night_light(root, Vector3(0, 42.0, -10.0), Color(1.0, 0.3, 0.2), 6.0, 40.0)
	return bake(root)
