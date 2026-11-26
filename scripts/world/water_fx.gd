class_name WaterFx
extends RefCounted
## Water surface effects: splash spray and expanding ripple rings. Shared
## materials/meshes so a swimmer's constant strokes stay cheap.

static var _drop_mat: StandardMaterial3D
static var _drop_mesh: SphereMesh
static var _ring_mesh: TorusMesh


static func _init_shared() -> void:
	if _drop_mat:
		return
	_drop_mat = StandardMaterial3D.new()
	_drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_drop_mat.albedo_color = Color(0.86, 0.93, 0.95, 0.5)
	_drop_mat.vertex_color_use_as_albedo = true
	_drop_mesh = SphereMesh.new()
	_drop_mesh.radius = 0.018
	_drop_mesh.height = 0.036
	_drop_mesh.radial_segments = 6
	_drop_mesh.rings = 3
	_drop_mesh.material = _drop_mat
	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.96
	_ring_mesh.outer_radius = 1.0
	_ring_mesh.rings = 48
	_ring_mesh.ring_segments = 4


## Spray of droplets thrown up from the surface. `strength` ~0.3 for a
## stroke, 1.0+ for jumping in.
static func splash(pos: Vector3, strength: float, dir := Vector3.UP) -> void:
	_init_shared()
	pos.y = Game.WATER_LEVEL + 0.02
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = int(8 + strength * 34)
	p.lifetime = 0.5 + strength * 0.35
	p.explosiveness = 0.92
	p.direction = (dir + Vector3.UP * 1.5).normalized()
	p.spread = 32.0 + strength * 10.0
	p.initial_velocity_min = 1.2 + strength * 1.5
	p.initial_velocity_max = 2.4 + strength * 4.0
	p.gravity = Vector3(0, -14.0, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12 + strength * 0.25
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0 + strength * 0.6
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0.25))
	p.scale_amount_curve = c
	p.mesh = _drop_mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.world.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	ripple(pos, 0.6 + strength * 1.6, 0.7 + strength * 0.5)


## A pale ring spreading over the surface and fading out.
static func ripple(pos: Vector3, radius: float, life := 0.9) -> void:
	_init_shared()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.85, 0.93, 0.95, 0.22)
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.world.add_child(mi)
	mi.global_position = Vector3(pos.x, Game.WATER_LEVEL + 0.03, pos.z)
	mi.scale = Vector3(0.15, 0.01, 0.15)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.01, radius), life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(m, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)
