class_name ModelLibrary
## Loads the CC0 models in res://assets/models (see assets/CREDITS.md) and
## helps fit them to game scale. Every caller checks has() first and falls
## back to its procedural stand-in, so the game still runs without the assets.

const DIR := "res://assets/models/"

static var _scenes := {}


static func has(model: String) -> bool:
	return ResourceLoader.exists(DIR + model + ".glb")


static func spawn(model: String) -> Node3D:
	if not _scenes.has(model):
		_scenes[model] = load(DIR + model + ".glb")
	return (_scenes[model] as PackedScene).instantiate() as Node3D


## Transform of `node` expressed in the space of `ancestor`. Works outside the tree.
static func xf_to(node: Node, ancestor: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n := node
	while n != null and n != ancestor:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## Bounding box of every mesh under `root`, in root space. Skinned meshes are
## measured in their bind pose, which can be far off; pass `rigid_only` to skip them.
static func bounds(root: Node3D, only: Array = [], rigid_only := false) -> AABB:
	var box := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or (not only.is_empty() and not only.has(mi)):
			continue
		if rigid_only and mi.skin != null:
			continue
		var b := xf_to(mi, root) * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Wraps a spawned model in a holder that is scaled so its largest horizontal
## size (or its height, when `by_height`) equals `size`, turned by `yaw`, sitting
## on the ground and centred on the origin.
static func fitted(model: String, size: float, yaw := 0.0, by_height := false) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Fit"
	var inst := spawn(model)
	holder.add_child(inst)
	var b := bounds(inst)
	var extent := b.size.y if by_height else maxf(b.size.x, b.size.z)
	var s := size / maxf(extent, 0.0001)
	var c := b.get_center()
	inst.position = -Vector3(c.x, b.position.y, c.z)
	holder.scale = Vector3.ONE * s
	holder.rotation.y = yaw
	return holder


## Replaces the albedo colour of every material whose name is a key in `colors`
## (materials are duplicated, so other instances keep the original look).
static func recolor(root: Node3D, colors: Dictionary) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if m and colors.has(m.resource_name):
				var copy := m.duplicate() as BaseMaterial3D
				copy.albedo_color = colors[m.resource_name]
				mi.set_surface_override_material(s, copy)


## Multiplies every material's albedo by `color` (for atlas-textured models).
static func tint(root: Node3D, color: Color) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if m:
				var copy := m.duplicate() as BaseMaterial3D
				copy.albedo_color = m.albedo_color * color
				mi.set_surface_override_material(s, copy)


static func set_layers(root: Node3D, layers: int) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).layers = layers
