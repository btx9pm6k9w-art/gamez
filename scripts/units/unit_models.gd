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


## unit_id is the UnitDefs key (e.g. "javelin" vs "ranger" share the soldier
## model); it is stored as meta "unit_id" so asset builders can pick variants.
static func build(model: String, faction: String, unit_id := "") -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	root.set_meta("unit_id", unit_id if unit_id != "" else model)
	if _build_from_assets(root, model, faction):
		return root
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


# --- Real models (res://assets/models) -------------------------------------
# Each builder keeps the named pivots the gameplay code relies on ("Turret",
# "Muzzle", "Engine") and returns false when its files are missing, in which
# case build() falls back to the primitive stand-ins above.

## Turret width in metres that puts each tank hull at about 8 m long.
const TANK_TURRET_WIDTH := {"tank_a": 2.7, "tank_b": 2.1}
## 1 / (model height in its own units), measured in the unit showcase.
const INFANTRY_SCALE_PER_METRE := {"soldier_a": 0.44, "soldier_b": 0.6, "mech_a": 0.36}
## The Quaternius soldier ships with every weapon attached; keep one.
## Yaw that points each boat's bow down -Z.
const BOAT_YAW := {"boat_patrol": PI, "boat_fast": PI}
const SOLDIER_WEAPON := "SMG"
const RIFLE_IN_HAND_ROTATION := Vector3(0, 90, 90)
const RIFLE_IN_HAND_OFFSET := Vector3(0, 0.05, 0.0)
const SOLDIER_WEAPONS := ["Revolver", "Sniper", "Revolver_Small", "Pistol", "SMG", "GrenadeLauncher",
	"ShortCannon", "Shotgun", "Sniper_2", "RocketLauncher", "AK", "Shovel", "Knife_2", "Knife_1"]


static func _build_from_assets(root: Node3D, model: String, faction: String) -> bool:
	var ok := false
	match model:
		"tank":
			ok = _asset_tank(root, faction)
		"soldier":
			ok = _asset_infantry(root, faction, "soldier_a" if faction == "coalition" else "soldier_b", 2.5)
		"robodog":
			ok = _asset_infantry(root, faction, "mech_a", 2.2)
		"patrol_boat":
			ok = _asset_boat(root, faction, "boat_patrol", 12.0, true)
		"fast_boat":
			ok = _asset_boat(root, faction, "boat_fast", 7.0, false)
		"laser_truck":
			ok = _asset_truck(root, faction, true)
		"launcher_truck":
			ok = _asset_truck(root, faction, false)
		"drone":
			ok = _asset_drone(root, faction)
	if ok:
		ModelLibrary.set_layers(root, UNIT_LAYER)
	return ok


static func _marker(parent: Node3D, node_name: String, pos: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = node_name
	m.position = pos
	parent.add_child(m)
	return m


## Moves `nodes` under a new "Turret" pivot placed at `pivot_pos` (root space)
## without changing where they sit.
static func _make_turret(root: Node3D, nodes: Array, pivot_pos: Vector3) -> Node3D:
	var turret := _pivot(root, "Turret", pivot_pos)
	for n: Node3D in nodes:
		var xf := ModelLibrary.xf_to(n, root)
		n.get_parent().remove_child(n)
		n.owner = null
		turret.add_child(n)
		n.transform = turret.transform.affine_inverse() * xf
	return turret


static func _asset_tank(root: Node3D, faction: String) -> bool:
	var file := "tank_a" if faction == "coalition" else "tank_b"
	if not ModelLibrary.has(file):
		return false
	var holder := Node3D.new()
	holder.name = "Fit"
	holder.add_child(ModelLibrary.spawn(file))
	root.add_child(holder)
	var gun := holder.find_child("Tank_Gun", true, false) as MeshInstance3D
	var top := holder.find_child("Tank_Turret", true, false) as MeshInstance3D
	if gun == null or top == null:
		return false
	# The hull is skinned (animated tracks), so size and centre the tank from
	# its rigid turret. The gun tells us which way the model faces; forward is -Z.
	var dir := ModelLibrary.bounds(root, [gun]).get_center() - ModelLibrary.bounds(root, [top]).get_center()
	holder.rotation.y = atan2(dir.x, -dir.z)
	var top_box := ModelLibrary.bounds(root, [top])
	holder.scale = Vector3.ONE * (float(TANK_TURRET_WIDTH[file]) / top_box.size.x)
	top_box = ModelLibrary.bounds(root, [top])
	holder.position = -Vector3(top_box.get_center().x, 0, top_box.get_center().z - 0.3)
	top_box = ModelLibrary.bounds(root, [top])
	var gun_box := ModelLibrary.bounds(root, [gun])
	var top_c := top_box.get_center()
	var turret := _make_turret(root, [top, gun], Vector3(top_c.x, top_box.position.y, top_c.z))
	_marker(turret, "Muzzle", Vector3(gun_box.get_center().x, gun_box.get_center().y, gun_box.position.z) - turret.position)
	_box(turret, Vector3(top_box.size.x * 0.5, 0.06, 0.08),
		Vector3(0, top_box.size.y + 0.02, top_box.size.z * 0.3), mat("glow:" + faction)) # IFF strip
	_headlight(root, Vector3(-1.0, 1.3, -3.2))
	_headlight(root, Vector3(1.0, 1.3, -3.2))
	_setup_anims(root, {"move": "Tank_Forward"})
	return true


static func _asset_infantry(root: Node3D, faction: String, file: String, height: float) -> bool:
	if not ModelLibrary.has(file):
		return false
	# Quaternius characters face +Z. They are skinned, so their bind-pose box is
	# unreliable and each file has a hand-measured scale; `height` is the
	# standing height in game (taller than life so they read at RTS distance).
	var holder := Node3D.new()
	holder.name = "Fit"
	holder.add_child(ModelLibrary.spawn(file))
	holder.scale = Vector3.ONE * height * float(INFANTRY_SCALE_PER_METRE[file])
	holder.rotation.y = PI
	root.add_child(holder)
	for weapon: String in SOLDIER_WEAPONS:
		var w := holder.find_child(weapon, true, false)
		if w and weapon != SOLDIER_WEAPON:
			w.free()
	if file == "soldier_b" and ModelLibrary.has("rifle_ak"):
		# The SWAT figure is unarmed: put a rifle in its right hand.
		var skeleton := holder.find_child("Skeleton3D", true, false) as Skeleton3D
		if skeleton and skeleton.find_bone("Wrist.R") >= 0:
			var hand := BoneAttachment3D.new()
			hand.bone_name = "Wrist.R"
			skeleton.add_child(hand)
			# The armature carries its own scale; undo it so the rifle is 0.95 units long.
			var k := 1.0 / ModelLibrary.xf_to(skeleton, holder).basis.get_scale().x
			var rifle := ModelLibrary.fitted("rifle_ak", 0.95 * k)
			rifle.rotation_degrees = RIFLE_IN_HAND_ROTATION
			rifle.position = RIFLE_IN_HAND_OFFSET * k
			hand.add_child(rifle)
	_marker(root, "Muzzle", Vector3(0.15, height * 0.62, -height * 0.35))
	_box(root, Vector3(0.5, 0.05, 0.05), Vector3(0, height + 0.25, 0), mat("glow:" + faction))
	_setup_anims(root, {
		"idle": ["Idle_Gun", "Idle"],
		"move": ["Run_Gun", "Run"],
		"shoot": ["Idle_Gun_Shoot", "Idle_Shoot", "Shoot_Small"],
	})
	return true


static func _asset_truck(root: Node3D, faction: String, laser: bool) -> bool:
	var file := "truck_armored" if laser else "pickup"
	if not ModelLibrary.has(file) or not ModelLibrary.has("turret_cannon") or not ModelLibrary.has("drone_a"):
		return false
	var holder := ModelLibrary.fitted(file, 6.2, PI)
	root.add_child(holder)
	if not laser: # the civilian pickup is baby blue; repaint it desert olive
		ModelLibrary.tint(holder, Color(0.62, 0.6, 0.4))
	var body := ModelLibrary.bounds(root)
	var bed := Vector3(0, body.size.y * (0.92 if laser else 0.5), body.size.z * 0.2)
	var turret: Node3D
	if laser:
		var mount := ModelLibrary.fitted("turret_cannon", 2.0, PI)
		mount.position = bed
		root.add_child(mount)
		var top := mount.find_child("Turret_Cannon_Top", true, false) as Node3D
		var top_box := ModelLibrary.bounds(root, [top])
		var c := top_box.get_center()
		turret = _make_turret(root, [top], Vector3(c.x, top_box.position.y, c.z))
		_cyl(turret, 0.16, 0.05, Vector3(0, top_box.size.y * 0.55, top_box.position.z - turret.position.z - 0.03), mat("lens"), Vector3(90, 0, 0))
		_marker(turret, "Muzzle", Vector3(0, top_box.size.y * 0.55, top_box.position.z - turret.position.z - 0.1))
	else:
		turret = _pivot(root, "Turret", bed)
		var rack := _pivot(turret, "Rack", Vector3(0, 0.35, 0.3))
		rack.rotation_degrees = Vector3(25, 0, 0)
		_box(rack, Vector3(2.0, 0.12, 3.0), Vector3.ZERO, mat("dark"))
		for i in 3:
			var d := ModelLibrary.fitted("drone_a", 1.5, PI)
			d.position = Vector3(-0.65 + i * 0.65, 0.1, 0.0)
			rack.add_child(d)
		_marker(turret, "Muzzle", Vector3(0, 1.4, -1.6))
	_box(root, Vector3(1.4, 0.05, 0.06), Vector3(0, body.size.y + 0.03, body.position.z + body.size.z * 0.35), mat("glow:" + faction))
	_headlight(root, Vector3(-0.8, 1.0, body.position.z))
	_headlight(root, Vector3(0.8, 1.0, body.position.z))
	return true


static func _asset_boat(root: Node3D, faction: String, file: String, length: float, patrol: bool) -> bool:
	if not ModelLibrary.has(file):
		return false
	var holder := ModelLibrary.fitted(file, length, float(BOAT_YAW[file]))
	holder.position.y = -0.25 # sit in the water rather than on it
	root.add_child(holder)
	if patrol:
		ModelLibrary.tint(holder, Color(0.62, 0.66, 0.7)) # navy grey
	else:
		ModelLibrary.tint(holder, Color(0.36, 0.38, 0.3))
	var box := ModelLibrary.bounds(root)
	var deck := 1.05 if patrol else 0.55
	var turret := _pivot(root, "Turret", Vector3(0, deck, box.position.z + box.size.z * (0.2 if patrol else 0.3)))
	var k := 1.0 if patrol else 0.6
	_cyl(turret, 0.45 * k, 0.4 * k, Vector3(0, 0.2 * k, 0), mat("paint:navy" if patrol else "dark"), Vector3.ZERO, 12)
	_box(turret, Vector3(0.5, 0.35, 0.8) * k, Vector3(0, 0.55 * k, 0), mat("dark"))
	_cyl(turret, 0.06, 1.6 * k, Vector3(0, 0.55 * k, -1.1 * k), mat("steel"), Vector3(90, 0, 0), 8)
	_marker(turret, "Muzzle", Vector3(0, 0.55 * k, -1.95 * k))
	_box(root, Vector3(1.0, 0.05, 0.4), Vector3(0, box.position.y + box.size.y * (0.55 if patrol else 1.0) + 0.05, box.size.z * 0.2), mat("glow:" + faction))
	if patrol:
		_headlight(root, Vector3(0, 1.6, -1.0))
	_pivot(root, "Wake", Vector3(0, 0.0, box.position.z + box.size.z - 0.3))
	return true


static func _asset_drone(root: Node3D, faction: String) -> bool:
	if not ModelLibrary.has("drone_a"):
		return false
	var holder := ModelLibrary.fitted("drone_a", 3.4, PI)
	holder.position.y = -0.3
	root.add_child(holder)
	_box(root, Vector3(0.06, 0.06, 0.06), Vector3(0, -0.12, -1.0), mat("glow:" + faction))
	_marker(root, "Engine", Vector3(0, 0.08, 1.7))
	return true


## Stores the model's AnimationPlayer and the clips to use for each state.
## `wanted` maps a state to a clip suffix (or a list of them, first match wins).
static func _setup_anims(root: Node3D, wanted: Dictionary) -> void:
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		return
	var clips := {}
	for state: String in wanted:
		var options: Array = wanted[state] if wanted[state] is Array else [wanted[state]]
		for suffix: String in options:
			for clip in player.get_animation_list():
				if clip.ends_with("|" + suffix) or clip == suffix:
					clips[state] = clip
					player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
					break
			if clips.has(state):
				break
	root.set_meta("anim_player", player)
	root.set_meta("anim_clips", clips)
	set_state(root, "idle")


## Switches a model to the "idle", "move" or "shoot" clip. Models without that
## clip (tanks only have "move") hold their pose instead.
static func set_state(root: Node3D, state: String) -> void:
	if not root.has_meta("anim_player") or root.get_meta("anim_state", "") == state:
		return
	root.set_meta("anim_state", state)
	var player := root.get_meta("anim_player") as AnimationPlayer
	var clips: Dictionary = root.get_meta("anim_clips")
	if clips.has(state):
		player.play(clips[state], 0.15)
	else:
		player.pause()
