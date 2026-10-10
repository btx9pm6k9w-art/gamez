extends Node
## Fog of war for the player's side, on a 2 m grid over the map.
## Each cell is unexplored (never seen), explored (seen before: terrain and
## buildings show, enemy units do not) or visible (inside a coalition unit's
## sight right now). Enemy units outside sight are hidden, are not shown on
## the minimap and cannot be picked. The world is shaded by one map-sized
## decal whose texture is this grid, so terrain, props and buildings darken
## with a soft edge and nothing reads the screen.

const CELL := 2.0
const TICK := 0.2
## Darkness of the decal over unexplored and explored-but-not-visible ground.
const DARK_UNEXPLORED := 0.82
const DARK_EXPLORED := 0.45

var battlefield: Node # Battlefield
var team := 0 # Battlefield.COALITION
var cells := 0
var enabled := true

var _explored := PackedByteArray()
var _visible := PackedByteArray()
var _image: Image
var _pixels := PackedByteArray() # luminance, alpha per cell
var _last_pixels := PackedByteArray()
var _texture: ImageTexture
var _decal: Decal
var _timer := 0.0


func setup(bf: Node) -> void:
	battlefield = bf
	cells = int(ceil(bf.MAP_SIZE / CELL))
	_explored.resize(cells * cells)
	_visible.resize(cells * cells)
	_pixels.resize(cells * cells * 2)
	_image = Image.create(cells, cells, false, Image.FORMAT_LA8)
	_image.fill(Color(0, 0, 0, DARK_UNEXPLORED))
	_texture = ImageTexture.create_from_image(_image)
	_decal = Decal.new()
	_decal.name = "FogOfWar"
	_decal.size = Vector3(bf.MAP_SIZE, 120.0, bf.MAP_SIZE)
	_decal.position = Vector3(bf.MAP_SIZE * 0.5, 30.0, bf.MAP_SIZE * 0.5)
	_decal.texture_albedo = _texture
	_decal.albedo_mix = 1.0
	_decal.upper_fade = 0.0
	_decal.lower_fade = 0.0
	_decal.normal_fade = 0.0
	bf.add_child(_decal)
	update_now()


## Cell index for a world position, or -1 off the map.
func _cell(p: Vector3) -> int:
	var x := int(p.x / CELL)
	var z := int(p.z / CELL)
	if x < 0 or z < 0 or x >= cells or z >= cells:
		return -1
	return z * cells + x


func is_visible_at(p: Vector3) -> bool:
	if not enabled:
		return true
	var i := _cell(p)
	return i >= 0 and _visible[i] != 0


func is_explored_at(p: Vector3) -> bool:
	if not enabled:
		return true
	var i := _cell(p)
	return i >= 0 and _explored[i] != 0


## Uncover an area without a unit there (mission start, intel, flares).
func reveal(p: Vector3, radius: float) -> void:
	_stamp(p, radius, false)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = TICK
		update_now()


func update_now() -> void:
	if battlefield == null:
		return
	_visible.fill(0)
	if enabled:
		for u: Unit in battlefield.units[team]:
			if is_instance_valid(u) and u.is_alive():
				var r: float = float(u.def["vision"])
				# High ground sees further, like the range bonus for firing down.
				r *= 1.0 + clampf((u.global_position.y - 2.0) * 0.015, 0.0, 0.2)
				_stamp(u.global_position, r, true)
	else:
		# Off (main menu, showcase): everything shows, nothing gets explored.
		_visible.fill(1)
	_apply_to_units()
	_refresh_texture()


func _stamp(p: Vector3, radius: float, now: bool) -> void:
	var cx := p.x / CELL
	var cz := p.z / CELL
	var rc := radius / CELL
	var r2 := rc * rc
	var z0 := maxi(int(cz - rc), 0)
	var z1 := mini(int(cz + rc) + 1, cells)
	var x0 := maxi(int(cx - rc), 0)
	var x1 := mini(int(cx + rc) + 1, cells)
	for z in range(z0, z1):
		var dz := z + 0.5 - cz
		var row := z * cells
		for x in range(x0, x1):
			var dx := x + 0.5 - cx
			if dx * dx + dz * dz <= r2:
				_explored[row + x] = 1
				if now:
					_visible[row + x] = 1


## Hide enemy units the player cannot see.
func _apply_to_units() -> void:
	for u: Unit in battlefield.units[1 - team]:
		if is_instance_valid(u) and u.is_alive():
			u.visible = is_visible_at(u.global_position)


func _refresh_texture() -> void:
	var unexplored := int(DARK_UNEXPLORED * 255.0)
	var explored := int(DARK_EXPLORED * 255.0)
	for i in cells * cells:
		_pixels[i * 2 + 1] = 0 if _visible[i] != 0 else (explored if _explored[i] != 0 else unexplored)
	if _pixels == _last_pixels:
		return
	_last_pixels = _pixels.duplicate()
	_image.set_data(cells, cells, false, Image.FORMAT_LA8, _pixels)
	# set_image, not update(): decals read from an atlas that is only rebuilt
	# when a texture is replaced (Godot's texture_2d_update skips it).
	_texture.set_image(_image)


## The fog as a texture (for the minimap), black with alpha = darkness.
func texture() -> Texture2D:
	return _texture
