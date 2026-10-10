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


static var _outline_shader: Shader
static var _outline_mats := {}


## Adds an inverted-hull outline to every mesh under `root`. The extra pass is
## chained to each surface material, so wrecks (which override materials) lose it.
static func outline(root: Node3D, color: Color, width: float) -> void:
	if _outline_shader == null:
		_outline_shader = Shader.new()
		_outline_shader.code = """shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque, shadows_disabled;
uniform vec4 line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float width = 0.05;
void vertex() {
	// Push the shell out along its normals by `width` metres of world space.
	float s = length(MODEL_MATRIX[0].xyz);
	VERTEX += NORMAL * width / max(s, 0.0001);
}
void fragment() {
	ALBEDO = line_color.rgb;
}
"""
	var key := "%s_%.3f" % [color.to_html(false), width]
	if not _outline_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = _outline_shader
		m.set_shader_parameter("line_color", color)
		m.set_shader_parameter("width", width)
		_outline_mats[key] = m
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var base := mi.get_surface_override_material(s)
			if base == null:
				base = mi.mesh.surface_get_material(s)
			if base == null:
				continue
			var copy := base.duplicate() as Material
			copy.next_pass = _outline_mats[key]
			mi.set_surface_override_material(s, copy)


## The first mesh of a model, scaled and centred so it is `size` metres across
## and sits on y = 0, as a standalone ArrayMesh-compatible Mesh plus the
## transform applied. Used for MultiMesh scatter where a node tree would be too
## heavy. `tint` multiplies every albedo colour.
static func baked_mesh(model: String, size: float, tint := Color.WHITE) -> Mesh:
	var root := spawn(model)
	var box := bounds(root)
	var mi: MeshInstance3D = null
	for n in root.find_children("*", "MeshInstance3D", true, false):
		mi = n as MeshInstance3D
		break
	if mi == null:
		root.free()
		return null
	var k := size / maxf(maxf(box.size.x, box.size.z), 0.0001)
	var c := box.get_center()
	var xf := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * k), -Vector3(c.x, box.position.y, c.z) * k)
	var out := ArrayMesh.new()
	var src := mi.mesh
	for sidx in src.get_surface_count():
		var arrays := src.surface_get_arrays(sidx)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var moved := PackedVector3Array()
		moved.resize(verts.size())
		var node_xf := xf_to(mi, root)
		for i in verts.size():
			moved[i] = xf * (node_xf * verts[i])
		arrays[Mesh.ARRAY_VERTEX] = moved
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat := src.surface_get_material(sidx)
		if mat is BaseMaterial3D:
			var copy := mat.duplicate() as BaseMaterial3D
			copy.albedo_color = copy.albedo_color * tint
			out.surface_set_material(sidx, copy)
		else:
			out.surface_set_material(sidx, mat)
	root.free()
	return out
