class_name Structure
extends Unit
## A base building. It is a Unit that never moves, so health bars, selection,
## fog of war, targeting and damage all work as for troops. Defences fire
## with the normal weapon code; on low power they go quiet. While it stands,
## the structure is registered as a solid prop on the battlefield, so the
## navmesh routes round it and it blocks line of fire.

const BuildingModels := preload("res://scripts/buildings/building_models.gd")

signal destroyed(s: Structure)

## Seconds the structure takes to rise out of the ground after placement.
const RISE_TIME := 1.6

## Set by the economy: false on low power (defences hold fire).
var powered := true
var _prop := {}


func setup(id: String, p_team: int, bf: Node) -> void:
	super.setup(id, p_team, bf)
	is_structure = true


func _ready() -> void:
	add_to_group("units")
	add_to_group("structures")
	add_to_group("team_%d" % team)
	model = BuildingModels.build(def["model"], faction)
	add_child(model)
	_model_base = model.position
	turret = model.find_child("Turret", true, false) as Node3D
	muzzle = model.find_child("Muzzle", true, false) as Node3D
	_yaw = rotation.y

	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	var r: float = def["radius"]
	torus.inner_radius = r * 1.25
	torus.outer_radius = r * 1.25 + 0.18
	torus.rings = 48
	torus.ring_segments = 4
	_ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(0.4, 2.0, 0.8) if team == 0 else Color(2.0, 0.4, 0.3)
	_ring.material_override = rm
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position.y = 0.4
	_ring.visible = false
	add_child(_ring)


## Called once the node is placed in the world.
func settle(rise := true) -> void:
	# A prop entry makes the navmesh carve round it and shots stop at its
	# walls. Its own hp is huge: damage arrives through take_damage() instead.
	_prop = {"node": self, "kind": "building", "radius": float(def["radius"]) * 0.9, "hp": 1e12, "alive": true}
	battlefield.props.append(_prop)
	# The blocker list fills itself from props on first use; only add to it
	# once it exists, or the map's own walls would never be listed.
	if not battlefield._blockers.is_empty():
		battlefield._blockers.append(_prop)
	battlefield._schedule_rebake()
	if rise:
		model.scale = Vector3(1, 0.05, 1)
		var tw := create_tween()
		tw.tween_property(model, "scale", Vector3.ONE, RISE_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		VFX.ground_ring(global_position, Color(0.4, 1.4, 3.0, 1), float(def["radius"]) * 1.4, 1.0)
		VFX.impact(global_position + Vector3.UP * 0.5)


func aim_point() -> Vector3:
	return global_position + Vector3.UP * 2.0


# --- Orders: structures do not move ------------------------------------------

func order_move(_pos: Vector3, _attack_move := false, _queue := false) -> void:
	pass


func order_patrol(_pos: Vector3) -> void:
	pass


func order_attack(t: Unit, queue := false) -> void:
	if def["weapon"] == "none":
		return
	super.order_attack(t, queue)
	if target != null and global_position.distance_to(target.global_position) > float(def["range"]):
		target = null
		state = State.IDLE


func order_stop() -> void:
	state = State.IDLE
	target = null


func order_hold() -> void:
	order_stop()


# --- Simulation ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _alive or def["weapon"] == "none":
		return
	_cooldown -= delta
	_scan_timer -= delta
	_los_timer -= delta
	if target != null and (not is_instance_valid(target) or not target.is_alive()
			or global_position.distance_to(target.global_position) > float(def["range"]) * 1.1):
		target = null
		state = State.IDLE
	if not powered:
		return
	if _scan_timer <= 0.0:
		_scan_timer = 0.3
		if target == null or not has_line_of_fire(target):
			target = battlefield.find_target(self, float(def["range"]))
	if target != null:
		_aim_and_fire(delta)
	elif turret:
		turret.rotation.y = lerp_angle(turret.rotation.y, turret.rotation.y + 0.3, delta * 0.5)


func _process(_delta: float) -> void:
	pass


func _die() -> void:
	_alive = false
	selected = false
	if not _prop.is_empty():
		_prop["alive"] = false
		battlefield._schedule_rebake()
	died.emit(self)
	destroyed.emit(self)
	var r: float = def["radius"]
	VFX.explosion(global_position + Vector3.UP * 2.0, clampf(r * 0.6, 1.4, 3.0))
	for k in 3:
		var p := global_position + Vector3(randf_range(-r, r) * 0.6, 1.5, randf_range(-r, r) * 0.6)
		get_tree().create_timer(0.3 + k * 0.35).timeout.connect(func() -> void: VFX.explosion(p, 1.3, VFX.Surface.AIR))
	VFX.burning(global_position + Vector3.UP, 25.0, clampf(r * 0.3, 0.8, 1.8))
	# Collapse into a burnt, flattened shell that stays as rubble.
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = UnitModels.mat("dark")
	var tw := create_tween()
	tw.tween_property(model, "scale:y", 0.18, 1.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
	if _ring:
		_ring.visible = false
	set_physics_process(false)
	remove_from_group("units")
