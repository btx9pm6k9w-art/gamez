class_name Terrain
extends Node3D
## Deformable heightmap terrain with biomes.
##
## The map reads like a real stretch of the UAE / Musandam coast: open sea and
## a rocky island to the west, a tidal creek (khor) lined with mangroves that
## cuts the coastal plain, salt-flat sabkha by the shore, a gravel wadi running
## down from the northern mountains, an oasis village, and a sea of dunes to
## the south-east with an oil field. Biome weights are stored per vertex
## (vertex colour: r = scorch, g = dune sand, b = wadi gravel) for the shader.
##
## Heights live in one array (1 m grid). The visible mesh is split into
## chunks so a crater only rebuilds the few chunks it touches. Collision is a
## single HeightMapShape3D and the navigation mesh is re-baked in the
## background after deformation.

signal deformed(center: Vector3, radius: float)

const CHUNK := 32
const WATER_LEVEL := 0.0

var size := 192 # cells per side; vertices = size + 1
var heights := PackedFloat32Array()
var scorch := PackedFloat32Array()
var dune := PackedFloat32Array()
var gravel := PackedFloat32Array()

## Landmarks other systems place things around.
const CREEK_END := Vector2(80, 128)
const ISLAND := Vector2(15, 62)
const OIL_FIELD := Vector2(166, 162)
const WADI := [Vector2(126, 0), Vector2(112, 40), Vector2(92, 74), Vector2(84, 104), Vector2(80, 126)]

var material: ShaderMaterial
var height_texture: ImageTexture

var _chunks: Array[MeshInstance3D] = []
var _dirty_chunks := {}
var _shape: HeightMapShape3D
var _body: StaticBody3D
var _height_image: Image


func generate(seed_value: int) -> void:
	var verts := size + 1
	heights.resize(verts * verts)
	scorch.resize(verts * verts)
	scorch.fill(0.0)
	dune.resize(verts * verts)
	gravel.resize(verts * verts)

	var hills := FastNoiseLite.new()
	hills.seed = seed_value
	hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	hills.frequency = 0.012
	hills.fractal_octaves = 5
	var ridges := FastNoiseLite.new()
	ridges.seed = seed_value + 7
	ridges.frequency = 0.02
	ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridges.fractal_octaves = 4
	var dunes := FastNoiseLite.new()
	dunes.seed = seed_value + 13
	dunes.frequency = 0.06
	var warp := FastNoiseLite.new()
	warp.seed = seed_value + 21
	warp.frequency = 0.025

	for z in verts:
		for x in verts:
			var fx := float(x)
			var fz := float(z)
			var h := 2.2 + hills.get_noise_2d(fx, fz) * 3.0 + dunes.get_noise_2d(fx * 0.6, fz) * 0.35
			# Mountains along the north (Iranian side), with passes.
			var north := 1.0 - smoothstep(0.0, 70.0, fz)
			h += max(ridges.get_noise_2d(fx, fz), 0.0) * 16.0 * north
			# Coastline: the Strait of Hormuz on the west edge.
			var coast := smoothstep(26.0, 52.0, fx + hills.get_noise_2d(fz * 0.7, 99.0) * 14.0)
			h = lerpf(-5.0, h, coast)
			# Tidal creek winding in from the sea; boats can use it to flank.
			var creek_z := CREEK_END.y + sin(fx * 0.09) * 5.0 + warp.get_noise_2d(fx, 7.0) * 4.0
			var creek_w := lerpf(9.0, 3.0, smoothstep(30.0, CREEK_END.x, fx)) * (1.0 - smoothstep(CREEK_END.x - 4.0, CREEK_END.x + 2.0, fx))
			if creek_w > 0.1:
				h = lerpf(-2.6, h, smoothstep(creek_w * 0.45, creek_w, absf(fz - creek_z)))
			# Rocky island offshore and a small islet.
			var isl := 1.0 - smoothstep(4.0, 10.0, Vector2(fx, fz).distance_to(ISLAND) + warp.get_noise_2d(fx * 3.0, fz * 3.0) * 3.0)
			h = maxf(h, lerpf(-5.0, 2.5 + maxf(ridges.get_noise_2d(fx * 2.0, fz * 2.0), 0.0) * 7.0, isl))
			var islet := 1.0 - smoothstep(1.5, 4.5, Vector2(fx, fz).distance_to(Vector2(9, 148)))
			h = maxf(h, lerpf(-5.0, 1.4, islet))
			# Dry wadi from the mountains to the head of the creek.
			var wd := _polyline_distance(Vector2(fx, fz), WADI) + warp.get_noise_2d(fx, fz) * 3.0
			var wadi := 1.0 - smoothstep(2.5, 6.0, wd)
			h -= wadi * 1.3
			# Dune sea in the south-east: long wind-sculpted crests.
			var dm := smoothstep(118.0, 145.0, fx + warp.get_noise_2d(fz, 3.0) * 12.0) * smoothstep(100.0, 128.0, fz + warp.get_noise_2d(fx, 5.0) * 12.0)
			var crest := 1.0 - absf(sin(fx * 0.11 + fz * 0.045 + warp.get_noise_2d(fx, fz) * 2.4))
			h += dm * (pow(crest, 2.2) * 4.2 + dunes.get_noise_2d(fx, fz) * 0.6)
			# Flatten the village in the middle and the two base areas.
			h = _flatten(h, fx, fz, Vector2(100, 100), 18.0, 2.4)
			h = _flatten(h, fx, fz, Vector2(64, 160), 16.0, 1.8)
			h = _flatten(h, fx, fz, Vector2(150, 52), 16.0, 3.4)
			h = _flatten(h, fx, fz, OIL_FIELD, 14.0, 3.0)
			# Fade the land edges to a flat skirt height so the horizon is seamless.
			var edge := minf(minf(fz, float(size) - fz), float(size) - fx)
			h = lerpf(1.0, h, smoothstep(0.0, 14.0, edge)) if fx > 60.0 else h
			heights[z * verts + x] = h
			dune[z * verts + x] = dm * (1.0 - smoothstep(10.0, 14.0, Vector2(fx, fz).distance_to(OIL_FIELD)))
			gravel[z * verts + x] = wadi

	_height_image = Image.create(verts, verts, false, Image.FORMAT_RF)
	_update_height_image(0, 0, size, size)
	height_texture = ImageTexture.create_from_image(_height_image)

	for cz in size / CHUNK:
		for cx in size / CHUNK:
			var mi := MeshInstance3D.new()
			mi.name = "Chunk_%d_%d" % [cx, cz]
			mi.material_override = material
			mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
			add_child(mi)
			_chunks.append(mi)
			_build_chunk(cx, cz)

	_body = StaticBody3D.new()
	_body.name = "TerrainBody"
	_body.collision_layer = 1
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	_shape = HeightMapShape3D.new()
	_shape.map_width = verts
	_shape.map_depth = verts
	_shape.map_data = heights
	cs.shape = _shape
	_body.add_child(cs)
	_body.position = Vector3(size * 0.5, 0.0, size * 0.5)
	add_child(_body)


static func _polyline_distance(p: Vector2, pts: Array) -> float:
	var best := INF
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + (b - a) * t))
	return best


## Soft sand in the dunes slows vehicles and infantry (0.6 .. 1.0).
func ground_speed_factor(p: Vector3) -> float:
	var k := _idx(clampi(int(round(p.x)), 0, size), clampi(int(round(p.z)), 0, size))
	return lerpf(1.0, 0.6, dune[k])


func dune_at(p: Vector3) -> float:
	return dune[_idx(clampi(int(round(p.x)), 0, size), clampi(int(round(p.z)), 0, size))]


func gravel_at(p: Vector3) -> float:
	return gravel[_idx(clampi(int(round(p.x)), 0, size), clampi(int(round(p.z)), 0, size))]


func _flatten(h: float, x: float, z: float, center: Vector2, radius: float, target: float) -> float:
	var d := Vector2(x, z).distance_to(center)
	return lerpf(target, h, smoothstep(radius * 0.6, radius, d))


func _idx(x: int, z: int) -> int:
	return z * (size + 1) + x


func get_height(x: int, z: int) -> float:
	return heights[_idx(clampi(x, 0, size), clampi(z, 0, size))]


## Bilinear height at a world position.
func height_at(p: Vector3) -> float:
	var fx := clampf(p.x, 0.0, float(size) - 0.001)
	var fz := clampf(p.z, 0.0, float(size) - 0.001)
	var x0 := int(fx)
	var z0 := int(fz)
	var tx := fx - x0
	var tz := fz - z0
	var a := lerpf(get_height(x0, z0), get_height(x0 + 1, z0), tx)
	var b := lerpf(get_height(x0, z0 + 1), get_height(x0 + 1, z0 + 1), tx)
	return lerpf(a, b, tz)


func normal_at(p: Vector3) -> Vector3:
	var x := int(round(p.x))
	var z := int(round(p.z))
	return _normal(x, z)


func _normal(x: int, z: int) -> Vector3:
	var hl := get_height(x - 1, z)
	var hr := get_height(x + 1, z)
	var hd := get_height(x, z - 1)
	var hu := get_height(x, z + 1)
	return Vector3(hl - hr, 2.0, hd - hu).normalized()


func slope_at(p: Vector3) -> float:
	return 1.0 - normal_at(p).y


func is_land(p: Vector3) -> bool:
	return height_at(p) > WATER_LEVEL + 0.4


func clamp_to_map(p: Vector3, margin := 2.0) -> Vector3:
	return Vector3(clampf(p.x, margin, size - margin), p.y, clampf(p.z, margin, size - margin))


func _build_chunk(cx: int, cz: int) -> void:
	var n := CHUNK + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(n * n)
	normals.resize(n * n)
	colors.resize(n * n)
	uvs.resize(n * n)
	var x0 := cx * CHUNK
	var z0 := cz * CHUNK
	for j in n:
		for i in n:
			var x := x0 + i
			var z := z0 + j
			var k := j * n + i
			verts[k] = Vector3(x, get_height(x, z), z)
			normals[k] = _normal(x, z)
			var vi := _idx(x, z)
			colors[k] = Color(scorch[vi], dune[vi], gravel[vi], 1.0)
			uvs[k] = Vector2(x, z) / float(size)
	var indices := PackedInt32Array()
	indices.resize(CHUNK * CHUNK * 6)
	var t := 0
	for j in CHUNK:
		for i in CHUNK:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			indices[t] = a
			indices[t + 1] = b
			indices[t + 2] = c
			indices[t + 3] = b
			indices[t + 4] = d
			indices[t + 5] = c
			t += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_chunks[cz * (size / CHUNK) + cx].mesh = mesh


## Blasts a crater: lowers the ground, raises a rim, scorches the area, then
## rebuilds the touched chunks, the collision shape and the water foam map.
func deform(center: Vector3, radius: float, depth: float) -> void:
	var r_outer := radius * 1.6
	var minx := clampi(int(center.x - r_outer) - 1, 0, size)
	var maxx := clampi(int(center.x + r_outer) + 1, 0, size)
	var minz := clampi(int(center.z - r_outer) - 1, 0, size)
	var maxz := clampi(int(center.z + r_outer) + 1, 0, size)
	for z in range(minz, maxz + 1):
		for x in range(minx, maxx + 1):
			var d := Vector2(x - center.x, z - center.z).length()
			var k := _idx(x, z)
			if d < radius:
				var f := 1.0 - (d * d) / (radius * radius)
				heights[k] -= depth * f
			elif d < radius * 1.3:
				var rim := 1.0 - absf(d - radius * 1.15) / (radius * 0.15)
				heights[k] += depth * 0.18 * clampf(rim, 0.0, 1.0)
			if d < r_outer:
				scorch[k] = clampf(scorch[k] + (1.0 - d / r_outer) * 1.2, 0.0, 1.0)
			heights[k] = maxf(heights[k], -6.0)
	# Normals at chunk borders depend on neighbours, so expand by one cell.
	for cz in range(maxi(0, (minz - 1) / CHUNK), mini(size / CHUNK - 1, (maxz + 1) / CHUNK) + 1):
		for cx in range(maxi(0, (minx - 1) / CHUNK), mini(size / CHUNK - 1, (maxx + 1) / CHUNK) + 1):
			_dirty_chunks[Vector2i(cx, cz)] = true
	_update_height_image(minx, minz, maxx, maxz)
	set_process(true)
	deformed.emit(center, radius)


func _process(_delta: float) -> void:
	if _dirty_chunks.is_empty():
		set_process(false)
		return
	for key: Vector2i in _dirty_chunks:
		_build_chunk(key.x, key.y)
	_dirty_chunks.clear()
	_shape.map_data = heights
	height_texture.update(_height_image)
	set_process(false)


func _update_height_image(minx: int, minz: int, maxx: int, maxz: int) -> void:
	for z in range(minz, maxz + 1):
		for x in range(minx, maxx + 1):
			_height_image.set_pixel(x, z, Color(heights[_idx(x, z)], 0.0, 0.0))


## Triangles for the navigation baker. Underwater cells are left out so the
## shoreline becomes the edge of the walkable area.
func build_nav_faces() -> PackedVector3Array:
	var faces := PackedVector3Array()
	var step := 1
	for z in range(0, size, step):
		for x in range(0, size, step):
			var a := Vector3(x, get_height(x, z), z)
			var b := Vector3(x + step, get_height(x + step, z), z)
			var c := Vector3(x, get_height(x, z + step), z + step)
			var d := Vector3(x + step, get_height(x + step, z + step), z + step)
			if minf(minf(a.y, b.y), minf(c.y, d.y)) < WATER_LEVEL + 0.3:
				continue
			faces.append_array(PackedVector3Array([a, b, c, b, d, c]))
	return faces


## Pixels for the minimap: sand, rock and sea shaded by height.
func build_minimap_image() -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for z in size:
		for x in size:
			var h := get_height(x, z)
			var c: Color
			if h < WATER_LEVEL:
				c = Color(0.06, 0.24, 0.3).lerp(Color(0.12, 0.42, 0.45), clampf(1.0 + h / 5.0, 0.0, 1.0))
			else:
				c = Color(0.62, 0.53, 0.38).lerp(Color(0.42, 0.37, 0.33), clampf(h / 14.0, 0.0, 1.0))
				c = c.lerp(Color(0.78, 0.55, 0.34), dune[_idx(x, z)] * 0.8)
				c = c.lerp(Color(0.52, 0.5, 0.46), gravel[_idx(x, z)] * 0.6)
				c = c.darkened(clampf(slope_at(Vector3(x, 0, z)) * 1.5, 0.0, 0.4))
			img.set_pixel(x, z, c)
	return img
