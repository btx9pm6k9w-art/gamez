class_name UnitModels
## Builds unit meshes from primitives with PBR materials. These are stand-ins
## until the art pass: proportions and named pivots ("Turret", "Muzzle",
## "Legs") are what the gameplay code relies on, so real models can replace
## them later without touching the unit logic.

const UNIT_LAYER := 2 # Units render on layer 2 so scorch decals skip them.

static var _mats := {}
static var _wear: NoiseTexture2D


static func paint(faction: String) -> Color:
	match faction:
		"coalition":
			return Color(0.60, 0.53, 0.40)
		"iran":
			return Color(0.30, 0.33, 0.22)
		"navy":
			return Color(0.40, 0.43, 0.46)
	return Color(0.08, 0.09, 0.11)


static func accent(faction: String) -> Color:
	match faction:
		"coalition":
			return Color(0.25, 0.85, 1.0)
		"iran":
			return Color(1.0, 0.25, 0.15)
	return Color(0.6, 1.0, 0.9)


static func mat(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	if _wear == null:
		_wear = NoiseTexture2D.new()
		_wear.seamless = true
		_wear.width = 256
		_wear.height = 256
		var n := FastNoiseLite.new()
		n.frequency = 0.03
		n.fractal_octaves = 4
		_wear.noise = n
	var m := StandardMaterial3D.new()
	var parts := key.split(":")
	match parts[0]:
		"paint":
			m.albedo_color = paint(parts[1])
			m.metallic = 0.45
			m.roughness = 0.55
			m.roughness_texture = _wear
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.6, 0.6, 0.6)
		"dark":
			m.albedo_color = Color(0.09, 0.09, 0.09)
			m.metallic = 0.6
			m.roughness = 0.6
		"rubber":
			m.albedo_color = Color(0.05, 0.05, 0.05)
			m.roughness = 0.9
		"steel":
			m.albedo_color = Color(0.35, 0.35, 0.36)
			m.metallic = 0.9
			m.roughness = 0.35
		"glass":
			m.albedo_color = Color(0.05, 0.08, 0.1)
			m.metallic = 0.2
			m.roughness = 0.05
		"glow":
			var c := accent(parts[1])
			m.albedo_color = c
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 4.0
		"lens":
			m.albedo_color = Color(0.3, 0.9, 1.0)
			m.emission_enabled = true
			m.emission = Color(0.3, 0.9, 1.0)
			m.emission_energy_multiplier = 8.0
			m.metallic = 1.0
			m.roughness = 0.0
		"skin":
			m.albedo_color = Color(0.55, 0.4, 0.3)
			m.roughness = 0.7
	_mats[key] = m
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, pos, material, rot)


static func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material, rot := Vector3.ZERO, sides := 16) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	return _add(parent, mesh, pos, material, rot)


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material, rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot
	mi.layers = UNIT_LAYER
	parent.add_child(mi)
	return mi


static func _pivot(parent: Node3D, node_name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	parent.add_child(n)
	return n


static func _headlight(parent: Node3D, pos: Vector3) -> void:
	var s := SpotLight3D.new()
	s.position = pos
	s.light_color = Color(1.0, 0.92, 0.8)
	s.light_energy = 6.0
	s.spot_range = 22.0
	s.spot_angle = 32.0
	s.rotation_degrees = Vector3(-12, 0, 0)
	s.visible = false
	s.add_to_group("night_lights")
	parent.add_child(s)


static func build(model: String, faction: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	match model:
		"tank":
			_tank(root, faction)
		"soldier":
			_soldier(root, faction)
		"robodog":
			_robodog(root, faction)
		"laser_truck":
			_truck(root, faction, true)
		"launcher_truck":
			_truck(root, faction, false)
		"drone":
			_drone(root, faction)
		"patrol_boat":
			_patrol_boat(root, faction)
		"fast_boat":
			_fast_boat(root, faction)
	return root


static func _tank(root: Node3D, faction: String) -> void:
	var p := mat("paint:" + faction)
	var dark := mat("dark")
	# Hull and sloped glacis. Forward is -Z.
	_box(root, Vector3(3.0, 0.9, 6.4), Vector3(0, 1.0, 0.1), p)
	_box(root, Vector3(3.0, 0.6, 1.4), Vector3(0, 1.05, -3.35), p, Vector3(-28, 0, 0))
	_box(root, Vector3(3.6, 0.12, 6.6), Vector3(0, 1.42, 0.1), p) # track skirts
	# Tracks and road wheels.
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.7, 0.85, 7.0), Vector3(1.45 * side, 0.5, 0.1), mat("rubber"))
		for i in 7:
			_cyl(root, 0.36, 0.2, Vector3(1.82 * side, 0.45, -2.7 + i * 0.9), dark, Vector3(0, 0, 90), 12)
	# Turret.
	var turret := _pivot(root, "Turret", Vector3(0, 1.48, 0.4))
	_box(turret, Vector3(2.6, 0.75, 3.0), Vector3(0, 0.38, 0.2), p)
	_box(turret, Vector3(2.2, 0.6, 1.0), Vector3(0, 0.36, 2.1), p) # bustle
	_box(turret, Vector3(1.2, 0.6, 0.6), Vector3(0, 0.36, -1.45), p) # mantlet
	_cyl(turret, 0.13, 4.8, Vector3(0, 0.38, -3.9), mat("steel"), Vector3(90, 0, 0), 12)
	_cyl(turret, 0.2, 0.7, Vector3(0, 0.38, -2.0), p, Vector3(90, 0, 0), 12) # thermal sleeve
	_box(turret, Vector3(0.45, 0.35, 0.5), Vector3(0.75, 0.92, -0.2), dark) # commander sight
	_box(turret, Vector3(0.18, 0.12, 0.18), Vector3(0.75, 0.92, -0.48), mat("lens"))
	_cyl(turret, 0.015, 2.2, Vector3(-0.9, 1.6, 1.6), dark, Vector3.ZERO, 4) # antenna
	_box(turret, Vector3(1.4, 0.06, 0.08), Vector3(0, 0.77, 1.3), mat("glow:" + faction)) # IFF strip
	if faction == "iran":
		for i in 4: # reactive armour bricks
			_box(turret, Vector3(0.45, 0.25, 0.35), Vector3(-0.85 + i * 0.57, 0.62, -1.25), p, Vector3(-15, 0, 0))
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.38, -6.4)
	turret.add_child(muzzle)
	_headlight(root, Vector3(-1.0, 1.3, -3.4))
	_headlight(root, Vector3(1.0, 1.3, -3.4))


static func _soldier(root: Node3D, faction: String) -> void:
	var p := mat("paint:" + faction)
	var body := _pivot(root, "Body", Vector3.ZERO)
	body.scale = Vector3.ONE * 1.35 # readable at RTS distance
	var torso := CapsuleMesh.new()
	torso.radius = 0.22
	torso.height = 0.85
	_add(body, torso, Vector3(0, 1.15, 0), p, Vector3.ZERO)
	var legs := _pivot(body, "Legs", Vector3(0, 0.75, 0))
	for side in [-1.0, 1.0]:
		var leg := _pivot(legs, "Leg", Vector3(0.1 * side, 0, 0))
		_cyl(leg, 0.08, 0.75, Vector3(0, -0.37, 0), p, Vector3.ZERO, 8)
	var head := SphereMesh.new()
	head.radius = 0.13
	head.height = 0.26
	_add(body, head, Vector3(0, 1.7, 0), mat("skin"), Vector3.ZERO)
	var helmet := SphereMesh.new()
	helmet.radius = 0.16
	helmet.height = 0.2
	helmet.is_hemisphere = true
	_add(body, helmet, Vector3(0, 1.74, 0), p, Vector3.ZERO)
	_box(body, Vector3(0.36, 0.38, 0.2), Vector3(0, 1.2, 0.2), mat("dark")) # pack
	_box(body, Vector3(0.06, 0.09, 0.75), Vector3(0.12, 1.25, -0.35), mat("dark")) # rifle
	_box(body, Vector3(0.05, 0.05, 0.05), Vector3(0, 1.72, -0.15), mat("glow:" + faction))
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.12, 1.25, -0.75)
	body.add_child(muzzle)


static func _robodog(root: Node3D, faction: String) -> void:
	var p := mat("paint:oracle") if faction == "coalition" else mat("paint:" + faction)
	var body := _pivot(root, "Body", Vector3(0, 0.78, 0))
	_box(body, Vector3(0.55, 0.32, 1.15), Vector3.ZERO, p)
	_box(body, Vector3(0.4, 0.26, 0.38), Vector3(0, 0.08, -0.7), p) # head
	_box(body, Vector3(0.34, 0.06, 0.04), Vector3(0, 0.1, -0.9), mat("lens")) # sensor bar
	_box(body, Vector3(0.18, 0.18, 0.5), Vector3(0, 0.28, 0.05), mat("dark")) # gun pod
	_cyl(body, 0.035, 0.5, Vector3(0, 0.28, -0.45), mat("steel"), Vector3(90, 0, 0), 8)
	_box(body, Vector3(0.5, 0.03, 0.06), Vector3(0, 0.17, 0.5), mat("glow:" + faction))
	var legs := _pivot(body, "Legs", Vector3.ZERO)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var hip := _pivot(legs, "Leg", Vector3(0.3 * corner.x, -0.1, 0.45 * corner.y))
		_cyl(hip, 0.05, 0.4, Vector3(0, -0.2, 0), p, Vector3.ZERO, 8)
		_cyl(hip, 0.04, 0.42, Vector3(0, -0.52, 0.08), mat("dark"), Vector3(-20, 0, 0), 8)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.28, -0.72)
	body.add_child(muzzle)


static func _truck(root: Node3D, faction: String, laser: bool) -> void:
	var p := mat("paint:" + faction)
	_box(root, Vector3(2.4, 0.5, 5.6), Vector3(0, 0.9, 0), mat("dark")) # chassis
	_box(root, Vector3(2.4, 1.4, 1.6), Vector3(0, 1.75, -2.0), p) # cab
	_box(root, Vector3(2.2, 0.55, 0.05), Vector3(0, 2.05, -2.81), mat("glass"))
	_box(root, Vector3(2.4, 0.6, 3.6), Vector3(0, 1.45, 0.9), p) # bed
	for side in [-1.0, 1.0]:
		for z in [-2.0, 0.6, 1.9]:
			_cyl(root, 0.5, 0.4, Vector3(1.1 * side, 0.5, z), mat("rubber"), Vector3(0, 0, 90), 14)
	_box(root, Vector3(1.6, 0.05, 0.06), Vector3(0, 2.47, -1.6), mat("glow:" + faction))
	var turret := _pivot(root, "Turret", Vector3(0, 1.8, 1.0))
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	if laser:
		_cyl(turret, 0.8, 0.5, Vector3(0, 0.25, 0), p)
		var dome := SphereMesh.new()
		dome.radius = 0.7
		dome.height = 1.0
		_add(turret, dome, Vector3(0, 0.7, 0), p, Vector3.ZERO)
		_cyl(turret, 0.28, 1.1, Vector3(0, 0.8, -0.7), mat("dark"), Vector3(90, 0, 0))
		_cyl(turret, 0.22, 0.05, Vector3(0, 0.8, -1.26), mat("lens"), Vector3(90, 0, 0))
		muzzle.position = Vector3(0, 0.8, -1.3)
	else:
		var rack := _pivot(turret, "Rack", Vector3(0, 0.2, 0))
		rack.rotation_degrees = Vector3(25, 0, 0)
		_box(rack, Vector3(2.0, 0.12, 3.2), Vector3(0, 0, 0), mat("dark"))
		for i in 3:
			var d := Node3D.new()
			d.position = Vector3(-0.65 + i * 0.65, 0.25, 0.0)
			d.scale = Vector3.ONE * 0.55
			rack.add_child(d)
			_drone_shape(d, faction)
		muzzle.position = Vector3(0, 1.4, -1.6)
	turret.add_child(muzzle)
	_headlight(root, Vector3(-0.8, 1.2, -2.85))
	_headlight(root, Vector3(0.8, 1.2, -2.85))


static func _drone_shape(root: Node3D, faction: String) -> void:
	var p := mat("paint:" + faction)
	var wing := PrismMesh.new()
	wing.size = Vector3(2.6, 3.0, 0.14)
	_add(root, wing, Vector3(0, 0, 0.3), p, Vector3(-90, 0, 0))
	_cyl(root, 0.22, 2.8, Vector3(0, 0.08, 0.2), p, Vector3(90, 0, 0), 10)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.04, 0.45, 0.5), Vector3(1.25 * side, 0.2, 1.55), p)
	_cyl(root, 0.14, 0.3, Vector3(0, 0.08, 1.7), mat("dark"), Vector3(90, 0, 0), 8)


static func _drone(root: Node3D, faction: String) -> void:
	_drone_shape(root, faction)
	_box(root, Vector3(0.06, 0.06, 0.06), Vector3(0, -0.12, -1.0), mat("glow:" + faction))
	var engine := Marker3D.new()
	engine.name = "Engine"
	engine.position = Vector3(0, 0.08, 1.9)
	root.add_child(engine)


## Pointed hull: deck outline with a sharp bow at -Z, sides sloping to a
## narrower keel. length along Z, beam along X.
static func _hull(root: Node3D, length: float, beam: float, depth: float, material: Material) -> void:
	var half := beam * 0.5
	var bow := -length * 0.5
	var stern := length * 0.5
	var deck := [Vector3(0, 0, bow), Vector3(half, 0, bow + length * 0.3), Vector3(half, 0, stern), Vector3(-half, 0, stern), Vector3(-half, 0, bow + length * 0.3)]
	var keel := []
	for v: Vector3 in deck:
		keel.append(Vector3(v.x * 0.35, -depth, v.z * 0.92))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3: # deck
		st.add_vertex(deck[0])
		st.add_vertex(deck[i + 1])
		st.add_vertex(deck[i + 2])
	for i in 5: # sides
		var j := (i + 1) % 5
		for v in [deck[i], keel[i], keel[j], deck[i], keel[j], deck[j]]: # clockwise from outside
			st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	_add(root, mesh, Vector3.ZERO, material, Vector3.ZERO)


## Mk VI-style patrol boat: grey hull, wheelhouse with mast and radar, a
## stabilised 25 mm autocannon on the bow.
static func _patrol_boat(root: Node3D, faction: String) -> void:
	var grey := mat("paint:navy")
	_hull(root, 12.0, 3.2, 1.0, grey)
	_box(root, Vector3(2.0, 1.3, 3.4), Vector3(0, 0.65, 0.6), grey) # wheelhouse
	_box(root, Vector3(1.9, 0.45, 1.0), Vector3(0, 1.1, -0.9), mat("glass"), Vector3(-25, 0, 0))
	_cyl(root, 0.05, 2.4, Vector3(0, 2.4, 1.0), mat("dark"), Vector3.ZERO, 6) # mast
	var radar := _box(root, Vector3(1.0, 0.08, 0.2), Vector3(0, 3.3, 1.0), mat("dark"))
	radar.name = "Radar"
	_box(root, Vector3(1.4, 0.06, 0.08), Vector3(0, 1.32, 2.0), mat("glow:" + faction))
	var turret := _pivot(root, "Turret", Vector3(0, 0.3, -2.6))
	_cyl(turret, 0.45, 0.4, Vector3(0, 0.2, 0), grey, Vector3.ZERO, 12)
	_box(turret, Vector3(0.5, 0.35, 0.8), Vector3(0, 0.55, 0), grey)
	_cyl(turret, 0.06, 1.6, Vector3(0, 0.55, -1.1), mat("steel"), Vector3(90, 0, 0), 8)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.55, -1.95)
	turret.add_child(muzzle)
	_headlight(root, Vector3(0, 1.4, -0.4))
	_pivot(root, "Wake", Vector3(0, 0.0, 5.6))


## IRGC fast attack craft: low dark speedboat, open cockpit, twin outboards
## and a heavy machine gun at the bow.
static func _fast_boat(root: Node3D, faction: String) -> void:
	var hull := mat("paint:" + faction)
	_hull(root, 6.5, 2.0, 0.7, hull)
	_box(root, Vector3(1.4, 0.5, 1.0), Vector3(0, 0.25, 0.4), mat("dark"))
	_box(root, Vector3(1.3, 0.35, 0.08), Vector3(0, 0.6, -0.1), mat("glass"), Vector3(-30, 0, 0))
	for s in [-0.4, 0.4]:
		_box(root, Vector3(0.3, 0.8, 0.4), Vector3(s, 0.1, 3.35), mat("dark"))
	var turret := _pivot(root, "Turret", Vector3(0, 0.2, -1.8))
	_cyl(turret, 0.04, 0.6, Vector3(0, 0.3, 0), mat("dark"), Vector3.ZERO, 6)
	_box(turret, Vector3(0.18, 0.18, 0.9), Vector3(0, 0.6, -0.2), mat("dark"))
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.6, -0.7)
	turret.add_child(muzzle)
	_box(root, Vector3(0.9, 0.04, 0.6), Vector3(0, 0.62, 1.2), mat("glow:" + faction)) # flag panel
	_pivot(root, "Wake", Vector3(0, 0.0, 3.4))
