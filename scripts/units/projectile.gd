class_name Projectile
extends Node3D
## Fast tank shell or missile on a shallow ballistic arc. Calls on_hit(position)
## when it lands or when it strikes something on the way: each physics step
## sweeps the segment flown against the ground and solid props, so walls,
## houses and ridges stop shells. The battlefield turns the hit into damage,
## a crater and effects.

static var _mesh: Mesh

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _duration := 0.1
var _arc := 0.0
var _t := 0.0
var _on_hit: Callable
var _world: Node
var _flown := 0.0


static func launch(parent: Node, from: Vector3, to: Vector3, speed: float, arc_per_meter: float, on_hit: Callable) -> Projectile:
	var p := Projectile.new()
	p._from = from
	p._to = to
	p._duration = maxf(from.distance_to(to) / speed, 0.03)
	p._arc = from.distance_to(to) * arc_per_meter
	p._on_hit = on_hit
	p._world = parent if parent.has_method("line_blocked") else null
	parent.add_child(p)
	p.global_position = from
	return p


func _ready() -> void:
	if _mesh == null:
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.07
		capsule.height = 1.6
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(6.0, 3.5, 1.5)
		capsule.material = m
		_mesh = capsule
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.rotation_degrees = Vector3(90, 0, 0) # capsule axis along -Z
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _point(t: float) -> Vector3:
	return _from.lerp(_to, t) + Vector3.UP * (_arc * 4.0 * t * (1.0 - t))


func _physics_process(delta: float) -> void:
	var last := _point(_t)
	_t = minf(_t + delta / _duration, 1.0)
	var p := _point(_t)
	if _world != null:
		# Ignore the first metres so the shooter's own cover does not stop it.
		var skip := maxf(2.0 - _flown, 0.0)
		_flown += last.distance_to(p)
		var stop: Vector3 = _world.line_blocked(last, p, skip, 0.0)
		if stop != Vector3.INF:
			if _on_hit.is_valid():
				_on_hit.call(stop)
			queue_free()
			return
	var ahead := _point(minf(_t + 0.02, 1.0))
	global_position = p
	var dir := ahead - p
	if dir.length() > 0.001 and absf(dir.normalized().y) < 0.99:
		look_at(ahead, Vector3.UP)
	if _t >= 1.0:
		if _on_hit.is_valid():
			_on_hit.call(_to)
		queue_free()
