extends Node3D
## Ground-slam "Rubble Eruption": a ring of boulders bursts out of the ground
## and rolls outward, kicking up dust and leaving rubble that sinks away.
## Damages the player when the wavefront passes them while grounded.

var max_radius := 16.0
var grow_speed := 12.0
var damage := 20.0
var radius := 0.0
var t := 0.0
var hit := false
var last_ring := 0.0
var chunks: Array = []
var dust_t := 0.0
var front: MeshInstance3D
var front_mat: ShaderMaterial
var show_front := true

static var _rock_meshes: Array[Mesh] = []
static var _rock_mat: ShaderMaterial
static var _dust_mat: StandardMaterial3D


func _ready() -> void:
	if _rock_meshes.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 4321
		_rock_mat = ShaderMaterial.new()
		_rock_mat.shader = load("res://shaders/world/rock.gdshader")
		_rock_mat.set_shader_parameter("moss_amount", 0.15)
		_rock_mat.set_shader_parameter("base_a", Color(0.42, 0.36, 0.3))
		_rock_mat.set_shader_parameter("base_b", Color(0.16, 0.13, 0.11))
		for i in 4:
			var m := WorldBuilder.make_rock(rng)
			m.surface_set_material(0, _rock_mat)
			_rock_meshes.append(m)
		_dust_mat = StandardMaterial3D.new()
		_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_dust_mat.vertex_color_use_as_albedo = true
		_dust_mat.albedo_texture = WorldBuilder._soft_dot()
	if show_front and damage > 0.0:
		# The wavefront you have to jump: a glowing molten band on the ground.
		var t := TorusMesh.new()
		t.inner_radius = 0.9
		t.outer_radius = 1.0
		t.rings = 96
		t.ring_segments = 8
		# Same charred-basalt-and-ember skin as the creatures.
		front_mat = ShaderMaterial.new()
		front_mat.shader = load("res://shaders/creatures/ember_flesh.gdshader")
		front_mat.set_shader_parameter("crack_amount", 0.95)
		front_mat.set_shader_parameter("ember_energy", 7.0)
		front_mat.set_shader_parameter("crack_scale", 3.0)
		front_mat.set_shader_parameter("pattern_scale", 1.6)
		t.material = front_mat
		front = MeshInstance3D.new()
		front.mesh = t
		front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(front)
	# Impact crater flash + scorch.
	Fx.explosion(global_position + Vector3(0, 0.4, 0))
	_dust(global_position, 2.5, 30, 5.0)


func _h(x: float, z: float) -> float:
	return Game.sample_height(x, z)


func _physics_process(delta: float) -> void:
	t += delta
	var front := t * grow_speed
	radius = minf(front, max_radius)
	var p := Game.player
	# Camera shake falls off with distance from the wavefront.
	if p and front < max_radius + 2.0:
		var dp := p.global_position - global_position
		dp.y = 0
		var near := 1.0 - clampf(absf(dp.length() - radius) / 14.0, 0.0, 1.0)
		p.shake = maxf(p.shake, 0.55 + 0.6 * near)

	_rings(front, 1.0, 1.0)
	if self.front:
		var r := maxf(front, 0.5)
		self.front.scale = Vector3(r, 1.6, r)
		self.front.position.y = 0.25
		front_mat.set_shader_parameter("dissolve", clampf((front / max_radius - 0.6) / 0.4, 0.0, 1.0))
		front_mat.set_shader_parameter("heat", 1.6 - front / max_radius)
		# Thick dust wall riding the wave.
		dust_t -= get_physics_process_delta_time()
		if dust_t <= 0.0 and front < max_radius:
			dust_t = 0.06
			for k in 5:
				var a := randf() * TAU
				var dp := global_position + Vector3(cos(a) * front, 0, sin(a) * front)
				dp.y = _h(dp.x, dp.z) + 0.4
				_dust(dp, 1.4, 3, 1.5)

	# Rock chunks: burst up, spin, fall and settle as rubble.
	for c in chunks:
		var n: MeshInstance3D = c[0]
		if c[3]:
			continue
		var v: Vector3 = c[1]
		v.y -= 22.0 * delta
		c[1] = v
		n.position += v * delta
		n.rotate(c[2].normalized(), c[2].length() * delta)
		var gy := _h(n.global_position.x, n.global_position.z) + n.scale.y * 0.6
		if v.y < 0.0 and n.global_position.y < gy:
			n.global_position.y = gy
			c[3] = true

	if not hit and p and not p.dead and front <= max_radius:
		var d := p.global_position - global_position
		var dy := d.y
		d.y = 0
		if absf(d.length() - front) < 1.0 and dy < 1.2 and p.is_on_floor():
			hit = true
			p.take_damage(damage, null, d.normalized() * 10.0 + Vector3(0, 7.0, 0))

	var life := max_radius / grow_speed
	if t > life + 2.5:
		# Rubble sinks away.
		for c in chunks:
			c[0].position.y -= delta * 0.6
	if t > life + 4.5:
		queue_free()


func _rings(front: float, density: float, size_mul: float, offset := 0.0) -> void:
	while last_ring + 0.9 <= front and last_ring + offset < max_radius:
		last_ring += 0.9
		var r := last_ring + offset
		var count := int((4.0 + r * 0.9) * density)
		var falloff := 1.0 - r / max_radius * 0.45
		for k in count:
			var a := TAU * k / count + randf() * 0.4
			var pos := global_position + Vector3(cos(a) * r, 0, sin(a) * r)
			pos.y = _h(pos.x, pos.z) - 0.35
			var n := MeshInstance3D.new()
			n.mesh = _rock_meshes[randi() % _rock_meshes.size()]
			var s := randf_range(0.3, 0.75) * falloff * size_mul
			n.scale = Vector3(s, s * randf_range(0.7, 1.3), s)
			add_child(n)
			n.global_position = pos
			n.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
			var out := Vector3(cos(a), 0, sin(a))
			var vel := out * randf_range(2.0, 5.0) + Vector3(0, randf_range(6.0, 11.0) * falloff, 0)
			chunks.append([n, vel, Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 6.0, false])
		if int(last_ring / 0.9) % 2 == 0:
			for k in 6:
				var a := randf() * TAU
				var dp := global_position + Vector3(cos(a) * r, 0, sin(a) * r)
				dp.y = _h(dp.x, dp.z) + 0.3
				_dust(dp, 1.0, 4, 2.0)


func _dust(pos: Vector3, size: float, amount: int, speed: float) -> void:
	var d := CPUParticles3D.new()
	d.one_shot = true
	d.emitting = false
	d.amount = amount
	d.lifetime = 1.6
	d.explosiveness = 0.95
	d.direction = Vector3.UP
	d.spread = 70.0
	d.initial_velocity_min = speed * 0.3
	d.initial_velocity_max = speed
	d.gravity = Vector3(0, 0.4, 0)
	d.damping_min = 2.0
	d.damping_max = 4.0
	d.scale_amount_min = size
	d.scale_amount_max = size * 2.2
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 1.0))
	d.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(0.34, 0.28, 0.23, 0.4))
	g.set_color(1, Color(0.3, 0.27, 0.24, 0.0))
	d.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.material = _dust_mat
	d.mesh = q
	add_child(d)
	d.global_position = pos
	d.emitting = true
