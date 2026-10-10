class_name Airstrike
extends Node3D
## Commander ability: a pair of strike fighters runs in low across the screen
## and ripples six retarded bombs along a line through the target. It is also
## the VFX showcase (F7): jets with afterburners, wingtip vapour and doppler
## roar, whistling bombs, then a chain of blasts with fireballs, debris, dust,
## shockwaves, craters, lingering fires and a drifting smoke pall.

const ALTITUDE := 32.0
const SPEED := 95.0
const RUN_IN := 260.0
const WINGMAN_LAG := 28.0
const WINGMAN_SIDE := 11.0
const BOMBS := 6
const SPACING := 7.5
const FALL_TIME := 1.6
const RELEASE_LEAD := 45.0

var battlefield: Battlefield
var target := Vector3.ZERO
var heading := Vector3.FORWARD
var team := Battlefield.COALITION
var damage := 260.0

var _t := 0.0
var _jets: Array[Node3D] = []
var _impacts: Array[Vector3] = []
var _release_times: Array[float] = []
var _released := 0
var _bombs: Array[Dictionary] = []


static func launch(bf: Battlefield, p_target: Vector3, p_heading: Vector3, p_team := Battlefield.COALITION, p_damage := 260.0) -> Airstrike:
	var a := Airstrike.new()
	a.battlefield = bf
	a.target = p_target
	var flat := Vector3(p_heading.x, 0.0, p_heading.z)
	a.heading = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	a.team = p_team
	a.damage = p_damage
	bf.add_child(a)
	return a


func _ready() -> void:
	for i in BOMBS:
		var along := (i - (BOMBS - 1) * 0.5) * SPACING
		var p := battlefield.terrain.clamp_to_map(target + heading * along)
		p.y = battlefield.terrain.height_at(p) if battlefield.terrain.is_land(p) else 0.0
		_impacts.append(p)
		var jet := i % 2
		_release_times.append((along - RELEASE_LEAD + RUN_IN + jet * WINGMAN_LAG) / SPEED)
	for j in 2:
		var jet := _build_jet()
		add_child(jet)
		jet.global_position = _jet_pos(j, 0.0)
		Audio.attach_loop(jet, "jet", 8.0, 70.0, true)
		_jets.append(jet)
	VFX.ground_ring(target, Color(4, 1.2, 0.2, 1), BOMBS * SPACING * 0.5, 3.0)
	Audio.play_ui("alert")


func _jet_pos(j: int, t: float) -> Vector3:
	var side := heading.cross(Vector3.UP).normalized() * (WINGMAN_SIDE if j == 1 else 0.0)
	var p := target + heading * (SPEED * t - RUN_IN - j * WINGMAN_LAG) + side
	p.y = target.y + ALTITUDE + sin(t * 1.4 + j * 2.0) * 0.6
	return p


func _process(delta: float) -> void:
	_t += delta
	for j in _jets.size():
		var jet := _jets[j]
		jet.global_position = _jet_pos(j, _t)
		jet.look_at(jet.global_position + heading, Vector3.UP)
		jet.rotate_object_local(Vector3.BACK, sin(_t * 0.9 + j) * 0.06)
	while _released < BOMBS and _t >= _release_times[_released]:
		_drop(_released)
		_released += 1
	for b in _bombs.duplicate():
		_update_bomb(b, delta)
	if _released == BOMBS and _bombs.is_empty() and _t > (RUN_IN * 2.0 + WINGMAN_LAG) / SPEED:
		queue_free()


func _drop(i: int) -> void:
	var jet := _jets[i % 2]
	var bomb := _build_bomb()
	add_child(bomb)
	bomb.global_position = jet.global_position + Vector3.DOWN * 1.2
	Audio.attach_loop(bomb, "bomb_whistle", 2.0, 30.0)
	_bombs.append({"node": bomb, "from": bomb.global_position, "to": _impacts[i], "t": 0.0})


## Retarded bomb: drag bleeds off the jet's speed while it accelerates down.
func _update_bomb(b: Dictionary, delta: float) -> void:
	var node: Node3D = b["node"]
	var from: Vector3 = b["from"]
	var to: Vector3 = b["to"]
	var t: float = minf(float(b["t"]) + delta / FALL_TIME, 1.0)
	b["t"] = t
	var h := 1.0 - (1.0 - t) * (1.0 - t)
	var p := Vector3(lerpf(from.x, to.x, h), lerpf(from.y, to.y, t * t), lerpf(from.z, to.z, h))
	var vel := p - node.global_position
	node.global_position = p
	if vel.length() > 0.01 and absf(vel.normalized().y) < 0.99:
		node.look_at(p + vel, Vector3.UP)
	if t >= 1.0:
		_bombs.erase(b)
		node.queue_free()
		battlefield.blast(to, damage, 7.0, 3.0, team, 3.5)


# --- Procedural models -----------------------------------------------------

func _metal(color: Color, metallic := 0.6, roughness := 0.38) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale
	parent.add_child(mi)
	return mi


## Flat swept planform (wing or tailplane), mirrored left and right.
func _planform(root_front: float, root_back: float, span: float, tip_front: float, tip_back: float, mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in [-1.0, 1.0]:
		var a := Vector3(0, 0, root_front)
		var b := Vector3(span * s, 0, tip_front)
		var c := Vector3(span * s, 0, tip_back)
		var d := Vector3(0, 0, root_back)
		for v in [a, b, c, a, c, d]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	st.set_material(mat)
	return st.commit()


func _build_jet() -> Node3D:
	var jet := Node3D.new()
	var skin := _metal(Color(0.4, 0.43, 0.46))
	skin.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body := CylinderMesh.new()
	body.top_radius = 0.6
	body.bottom_radius = 0.75
	body.height = 11.0
	body.material = skin
	_part(jet, body, Vector3(0, 0, 0.5), Vector3(-PI * 0.5, 0, 0))
	var nose := CylinderMesh.new()
	nose.top_radius = 0.02
	nose.bottom_radius = 0.6
	nose.height = 3.2
	nose.material = skin
	_part(jet, nose, Vector3(0, 0, -6.6), Vector3(-PI * 0.5, 0, 0))
	var canopy := SphereMesh.new()
	canopy.material = _metal(Color(0.06, 0.08, 0.1), 0.9, 0.05)
	_part(jet, canopy, Vector3(0, 0.55, -3.6), Vector3.ZERO, Vector3(0.5, 0.45, 1.7))
	_part(jet, _planform(-2.4, 4.4, 5.8, 2.4, 3.6, skin), Vector3(0, -0.1, 0))
	_part(jet, _planform(4.4, 6.4, 2.6, 5.9, 6.6, skin), Vector3(0, 0, 0))
	var fin := BoxMesh.new()
	fin.size = Vector3(0.12, 2.1, 1.9)
	fin.material = skin
	for s in [-1.0, 1.0]:
		_part(jet, fin, Vector3(0.9 * s, 1.1, 5.0), Vector3(0, 0, -0.26 * s))
		var burner := VFX.make_afterburner(1.1)
		burner.position = Vector3(0.4 * s, 0, 6.1)
		jet.add_child(burner)
		burner.emitting = true
		var vapour := VFX.make_contrail(0.8)
		vapour.position = Vector3(5.7 * s, 0, 3.0)
		jet.add_child(vapour)
		vapour.emitting = true
	return jet


func _build_bomb() -> Node3D:
	var bomb := Node3D.new()
	var olive := _metal(Color(0.24, 0.26, 0.2), 0.3, 0.6)
	var body := CapsuleMesh.new()
	body.radius = 0.2
	body.height = 1.9
	body.material = olive
	_part(bomb, body, Vector3.ZERO, Vector3(-PI * 0.5, 0, 0))
	var fin := BoxMesh.new()
	fin.size = Vector3(0.7, 0.04, 0.4)
	fin.material = olive
	_part(bomb, fin, Vector3(0, 0, 0.85))
	_part(bomb, fin, Vector3(0, 0, 0.85), Vector3(0, 0, PI * 0.5))
	return bomb
