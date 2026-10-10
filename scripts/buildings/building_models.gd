extends RefCounted
## Procedural models for base structures, in the same kit as the unit
## models: concrete slab, sand-painted blocks, dark steel, glowing faction
## accents. Each sits on a slab that reaches below ground so it hides uneven
## terrain. Defences get a "Turret" pivot with a "Muzzle" marker.


static var _mats := {}


static func _mat(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"concrete":
			m.albedo_color = Color(0.52, 0.5, 0.46)
			m.roughness = 0.92
		"wall":
			m.albedo_color = Color(0.66, 0.58, 0.45)
			m.roughness = 0.85
		"roof":
			m.albedo_color = Color(0.36, 0.35, 0.32)
			m.roughness = 0.7
			m.metallic = 0.3
		"sandbag":
			m.albedo_color = Color(0.58, 0.5, 0.36)
			m.roughness = 1.0
		"stripe":
			m.albedo_color = Color(0.9, 0.72, 0.15)
			m.roughness = 0.6
		"white":
			m.albedo_color = Color(0.82, 0.82, 0.8)
			m.roughness = 0.5
			m.metallic = 0.4
		_:
			return UnitModels.mat(key)
	_mats[key] = m
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, key: String, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, pos, key, rot)


static func _cyl(parent: Node3D, r_top: float, r_bottom: float, height: float, pos: Vector3, key: String, rot := Vector3.ZERO, sides := 20) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bottom
	mesh.height = height
	mesh.radial_segments = sides
	return _add(parent, mesh, pos, key, rot)


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, key: String, rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(key)
	mi.position = pos
	mi.rotation_degrees = rot
	mi.layers = UnitModels.UNIT_LAYER
	parent.add_child(mi)
	return mi


static func _slab(root: Node3D, half: float) -> void:
	# Reaches 1.5 m below the pivot so slopes never show a gap.
	_box(root, Vector3(half * 2.0, 1.8, half * 2.0), Vector3(0, -0.6, 0), "concrete")
	for s in [-1.0, 1.0]:
		_box(root, Vector3(half * 2.0, 0.06, 0.25), Vector3(0, 0.31, s * (half - 0.3)), "stripe")


static func _glow(root: Node3D, faction: String, size: Vector3, pos: Vector3) -> void:
	_box(root, size, pos, "glow:" + faction)


static func build(model: String, faction: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	root.set_meta("unit_id", model)
	match model:
		"fob":
			_fob(root, faction)
		"power_plant":
			_power_plant(root, faction)
		"refinery":
			_refinery(root, faction)
		"barracks":
			_barracks(root, faction)
		"vehicle_depot":
			_vehicle_depot(root, faction)
		"guard_post":
			_guard_post(root, faction)
		"interceptor":
			_interceptor(root, faction)
	return root


static func _fob(root: Node3D, faction: String) -> void:
	_slab(root, 5.6)
	# Command block with a stepped upper floor and a glass ops room.
	_box(root, Vector3(7.0, 3.2, 5.0), Vector3(-0.8, 1.9, -0.6), "wall")
	_box(root, Vector3(7.4, 0.3, 5.4), Vector3(-0.8, 3.6, -0.6), "roof")
	_box(root, Vector3(4.0, 2.0, 3.4), Vector3(-1.6, 4.7, -0.9), "wall")
	_box(root, Vector3(4.05, 0.7, 3.45), Vector3(-1.6, 4.9, -0.9), "glass")
	_box(root, Vector3(4.3, 0.25, 3.7), Vector3(-1.6, 5.8, -0.9), "roof")
	# Antenna mast and dish.
	_cyl(root, 0.08, 0.12, 5.0, Vector3(0.9, 8.2, -1.6), "steel")
	_cyl(root, 0.9, 0.2, 0.3, Vector3(-2.8, 6.3, -1.8), "white", Vector3(-35, 0, 0))
	_glow(root, faction, Vector3(0.25, 0.25, 0.25), Vector3(0.9, 10.75, -1.6))
	# Helipad on the open corner.
	_cyl(root, 2.0, 2.0, 0.08, Vector3(3.2, 0.34, 3.0), "roof", Vector3.ZERO, 32)
	_box(root, Vector3(0.3, 0.02, 1.8), Vector3(2.6, 0.39, 3.0), "white")
	_box(root, Vector3(0.3, 0.02, 1.8), Vector3(3.8, 0.39, 3.0), "white")
	_box(root, Vector3(1.2, 0.02, 0.3), Vector3(3.2, 0.39, 3.0), "white")
	# Doors and window band.
	_box(root, Vector3(1.6, 2.0, 0.1), Vector3(-0.8, 1.3, 1.95), "dark")
	_glow(root, faction, Vector3(6.0, 0.12, 0.05), Vector3(-0.8, 3.0, 1.93))
	for k in 4:
		_box(root, Vector3(1.0, 0.7, 0.4), Vector3(-4.4 + k * 1.05, 0.65, 4.6), "sandbag")


static func _power_plant(root: Node3D, faction: String) -> void:
	_slab(root, 3.8)
	_box(root, Vector3(5.0, 2.6, 3.0), Vector3(0, 1.6, 1.2), "wall")
	_box(root, Vector3(5.2, 0.25, 3.2), Vector3(0, 3.0, 1.2), "roof")
	# Two cooling stacks, the plant's silhouette from any angle.
	for x in [-1.3, 1.3]:
		_cyl(root, 0.9, 1.3, 6.5, Vector3(x, 3.6, -1.6), "concrete")
		_cyl(root, 0.95, 0.95, 0.3, Vector3(x, 6.95, -1.6), "dark")
		_glow(root, faction, Vector3(0.2, 0.2, 0.2), Vector3(x, 7.2, -1.6))
	# Transformer yard with glowing coils.
	for k in 3:
		_box(root, Vector3(0.7, 1.2, 0.7), Vector3(-1.6 + k * 1.6, 0.9, 3.3), "steel")
		_glow(root, faction, Vector3(0.75, 0.1, 0.75), Vector3(-1.6 + k * 1.6, 1.3, 3.3))


static func _refinery(root: Node3D, faction: String) -> void:
	_slab(root, 5.2)
	# Storage tanks, a distillation column and pipe runs.
	for p: Vector3 in [Vector3(-2.6, 0, -2.4), Vector3(0.2, 0, -2.6), Vector3(-2.6, 0, 0.6)]:
		_cyl(root, 1.4, 1.4, 2.6, p + Vector3(0, 1.6, 0), "white", Vector3.ZERO, 24)
		_cyl(root, 1.42, 1.42, 0.12, p + Vector3(0, 2.95, 0), "roof", Vector3.ZERO, 24)
	_cyl(root, 0.6, 0.7, 8.0, Vector3(2.6, 4.3, -1.0), "steel")
	for y in [2.0, 4.0, 6.0]:
		_cyl(root, 0.85, 0.85, 0.15, Vector3(2.6, y, -1.0), "dark")
	_glow(root, faction, Vector3(0.2, 0.2, 0.2), Vector3(2.6, 8.45, -1.0))
	_box(root, Vector3(6.5, 0.25, 0.25), Vector3(-0.2, 1.2, -1.0), "steel")
	_box(root, Vector3(0.25, 0.25, 4.0), Vector3(1.4, 1.2, 1.0), "steel")
	_box(root, Vector3(3.2, 2.0, 2.4), Vector3(1.6, 1.3, 2.8), "wall")
	_box(root, Vector3(3.4, 0.2, 2.6), Vector3(1.6, 2.4, 2.8), "roof")


static func _barracks(root: Node3D, faction: String) -> void:
	_slab(root, 4.2)
	# Long hut with a curved roof, and a sandbagged entrance.
	_box(root, Vector3(7.0, 2.0, 3.6), Vector3(0, 1.3, -0.6), "wall")
	var roof := _cyl(root, 1.9, 1.9, 7.2, Vector3(0, 2.3, -0.6), "roof", Vector3(0, 0, 90), 16)
	roof.scale = Vector3(1, 1, 0.55)
	_box(root, Vector3(1.4, 1.8, 0.1), Vector3(0, 1.2, 1.25), "dark")
	_glow(root, faction, Vector3(1.4, 0.1, 0.05), Vector3(0, 2.2, 1.24))
	for k in 3:
		_box(root, Vector3(1.0, 0.7, 0.45), Vector3(-2.6 + k * 1.05, 0.65, 2.6), "sandbag")
		_box(root, Vector3(1.0, 0.7, 0.45), Vector3(0.5 + k * 1.05, 0.65, 2.6), "sandbag")
	# Flag pole.
	_cyl(root, 0.05, 0.05, 4.0, Vector3(3.4, 2.3, 2.6), "steel")
	_glow(root, faction, Vector3(0.9, 0.5, 0.04), Vector3(3.85, 4.0, 2.6))


static func _vehicle_depot(root: Node3D, faction: String) -> void:
	_slab(root, 5.6)
	# Hangar with a big roller door facing the yard.
	_box(root, Vector3(8.0, 4.4, 6.0), Vector3(0, 2.5, -1.6), "wall")
	_box(root, Vector3(8.4, 0.3, 6.4), Vector3(0, 4.85, -1.6), "roof")
	_box(root, Vector3(4.6, 3.4, 0.12), Vector3(0, 2.0, 1.42), "dark")
	for k in 6:
		_box(root, Vector3(4.6, 0.04, 0.05), Vector3(0, 0.6 + k * 0.55, 1.5), "steel")
	_glow(root, faction, Vector3(4.8, 0.12, 0.05), Vector3(0, 3.8, 1.45))
	# Crane gantry over the yard.
	for x in [-3.6, 3.6]:
		_box(root, Vector3(0.3, 4.0, 0.3), Vector3(x, 2.3, 4.2), "stripe")
	_box(root, Vector3(7.6, 0.4, 0.4), Vector3(0, 4.4, 4.2), "stripe")
	_box(root, Vector3(0.8, 0.5, 0.8), Vector3(1.2, 3.9, 4.2), "steel")


static func _guard_post(root: Node3D, faction: String) -> void:
	_slab(root, 1.8)
	# Octagonal sandbag ring with a turret on top.
	for k in 8:
		var a := TAU * k / 8.0
		_box(root, Vector3(1.3, 0.9, 0.5), Vector3(cos(a) * 1.4, 0.75, sin(a) * 1.4), "sandbag", Vector3(0, -rad_to_deg(a) + 90.0, 0))
	_cyl(root, 1.0, 1.1, 1.2, Vector3(0, 0.9, 0), "wall")
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0, 1.7, 0)
	root.add_child(turret)
	_box(turret, Vector3(1.1, 0.6, 1.2), Vector3(0, 0, 0), "paint:" + faction)
	_cyl(turret, 0.09, 0.09, 1.8, Vector3(0, 0.05, -1.3), "dark", Vector3(90, 0, 0), 10)
	_glow(turret, faction, Vector3(0.6, 0.06, 0.05), Vector3(0, 0.2, 0.62))
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.05, -2.25)
	turret.add_child(muzzle)


static func _interceptor(root: Node3D, faction: String) -> void:
	_slab(root, 2.4)
	_box(root, Vector3(3.0, 0.8, 3.0), Vector3(0, 0.7, 0), "paint:" + faction)
	_cyl(root, 0.5, 0.7, 1.0, Vector3(0, 1.5, 0), "steel")
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0, 2.2, 0)
	root.add_child(turret)
	# Twin emitter head with a radar panel behind it.
	_box(turret, Vector3(1.6, 0.9, 1.4), Vector3(0, 0, 0), "paint:" + faction)
	for x in [-0.45, 0.45]:
		_cyl(turret, 0.16, 0.2, 1.6, Vector3(x, 0.25, -1.0), "steel", Vector3(70, 0, 0), 12)
		_cyl(turret, 0.12, 0.12, 0.05, Vector3(x, 0.55, -1.75), "lens", Vector3(70, 0, 0), 12)
	_box(turret, Vector3(1.4, 1.0, 0.1), Vector3(0, 0.6, 0.75), "dark", Vector3(-15, 0, 0))
	_glow(turret, faction, Vector3(1.2, 0.06, 0.04), Vector3(0, 0.9, 0.81))
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.6, -1.8)
	turret.add_child(muzzle)
