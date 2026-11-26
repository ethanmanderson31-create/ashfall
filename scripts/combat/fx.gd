class_name Fx
extends RefCounted
## One-shot visual effects: tracers, impacts, muzzle flash, damage numbers.

static var _tracer_mat: StandardMaterial3D
static var _spark_mat: StandardMaterial3D
static var _ember_mat: StandardMaterial3D


static func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c * energy
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


static func tracer(from: Vector3, to: Vector3) -> void:
	if _tracer_mat == null:
		_tracer_mat = _emissive(Color(1.0, 0.75, 0.35), 6.0)
	var len := from.distance_to(to)
	if len < 0.3:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.025, len)
	mesh.material = _tracer_mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.world.add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.2, 0.2, 1.0), 0.06)
	tw.tween_callback(mi.queue_free)


static func _burst(pos: Vector3, dir: Vector3, color: Color, amount: int, speed: float, life: float, size: float, grav: float, energy: float = 3.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = dir
	p.spread = 45.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -grav, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	p.scale_amount_curve = c
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size, size, size * 4.0)
	mesh.material = _emissive(color, energy)
	p.mesh = mesh
	p.particle_flag_align_y = true
	Game.world.add_child(p)
	p.global_position = pos
	p.emitting = true
	Game.world.get_tree().create_timer(life + 0.2).timeout.connect(p.queue_free)


static func impact(pos: Vector3, normal: Vector3, flesh: bool) -> void:
	if flesh:
		_burst(pos, normal, Color(1.0, 0.45, 0.12), 12, 8.0, 0.35, 0.018, 12.0, 4.0)
	else:
		_burst(pos, normal, Color(1.0, 0.8, 0.5), 7, 6.0, 0.25, 0.012, 14.0, 4.0)


static func death_burst(pos: Vector3, color: Color) -> void:
	_burst(pos, Vector3.UP, color, 36, 5.0, 1.0, 0.03, 2.0, 3.0)
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 6.0
	l.omni_range = 7.0
	Game.world.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


static var _flash_mat: ShaderMaterial
static var _smoke_mat: StandardMaterial3D
static var _shell_mesh: BoxMesh


static func _flash_material() -> ShaderMaterial:
	if _flash_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float seed = 0.0;
uniform float fade = 1.0;
uniform float stretch = 0.0;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.x *= mix(1.0, 0.45, stretch);
	float r = length(p);
	float a = atan(p.y, p.x);
	float spikes = 0.55 + 0.45 * pow(abs(cos(a * 3.5 + seed * 6.0)), 6.0);
	float core = pow(max(0.0, 1.0 - r / spikes), 2.2);
	float hot = pow(max(0.0, 1.0 - r * 2.2), 3.0);
	vec3 col = mix(vec3(1.0, 0.45, 0.1), vec3(1.0, 0.95, 0.7), hot) * 9.0;
	ALBEDO = col * core * fade;
	ALPHA = core * fade;
}
"""
		_flash_mat = ShaderMaterial.new()
		_flash_mat.shader = sh
	return _flash_mat


## Star-burst muzzle flash, a side cone, a smoke puff and an ejected shell.
static func muzzle_flash(at: Node3D) -> void:
	var w := Game.world
	var root := Node3D.new()
	w.add_child(root)
	root.global_transform = at.global_transform
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.35)
	l.light_energy = 5.0
	l.omni_range = 6.0
	root.add_child(l)
	var seed := randf()
	# Front star (faces along the barrel) + two crossed side planes (cone).
	var defs := [
		[Vector2(0.5, 0.5), Vector3(0, 0, -0.03), Vector3.ZERO, 0.0],
		[Vector2(0.3, 0.8), Vector3(0, 0, -0.32), Vector3(-PI * 0.5, 0, 0), 1.0],
		[Vector2(0.3, 0.8), Vector3(0, 0, -0.32), Vector3(-PI * 0.5, PI * 0.5, 0), 1.0],
	]
	var mats: Array[ShaderMaterial] = []
	for d in defs:
		var q := QuadMesh.new()
		q.size = d[0] * randf_range(0.8, 1.2)
		var m: ShaderMaterial = _flash_material().duplicate()
		m.set_shader_parameter("seed", seed)
		m.set_shader_parameter("stretch", d[3])
		mats.append(m)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = d[1]
		mi.rotation = d[2]
		mi.rotate_object_local(Vector3.FORWARD, randf() * TAU)
		root.add_child(mi)
	var tw := root.create_tween()
	tw.tween_method(func(v: float):
		for m in mats:
			m.set_shader_parameter("fade", v)
		l.light_energy = 5.0 * v, 1.0, 0.0, 0.075)
	tw.tween_callback(root.queue_free)

	# Smoke puff drifting off the muzzle.
	if _smoke_mat == null:
		_smoke_mat = StandardMaterial3D.new()
		_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_smoke_mat.vertex_color_use_as_albedo = true
		_smoke_mat.albedo_texture = WorldBuilder._soft_dot()
		_shell_mesh = BoxMesh.new()
		_shell_mesh.size = Vector3(0.012, 0.012, 0.035)
		var brass := StandardMaterial3D.new()
		brass.albedo_color = Color(0.85, 0.62, 0.25)
		brass.metallic = 1.0
		brass.roughness = 0.3
		_shell_mesh.material = brass
	var smoke := CPUParticles3D.new()
	smoke.one_shot = true
	smoke.emitting = false
	smoke.amount = 5
	smoke.lifetime = 0.9
	smoke.explosiveness = 0.9
	smoke.direction = -at.global_basis.z
	smoke.spread = 25.0
	smoke.initial_velocity_min = 0.4
	smoke.initial_velocity_max = 1.2
	smoke.gravity = Vector3(0, 0.6, 0)
	smoke.damping_min = 1.5
	smoke.damping_max = 2.5
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 2.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.3))
	sc.add_point(Vector2(1, 1.0))
	smoke.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(0.7, 0.68, 0.65, 0.35))
	g.set_color(1, Color(0.6, 0.6, 0.6, 0.0))
	smoke.color_ramp = g
	var sq := QuadMesh.new()
	sq.size = Vector2(0.16, 0.16)
	sq.material = _smoke_mat
	smoke.mesh = sq
	w.add_child(smoke)
	smoke.global_position = at.global_position
	smoke.emitting = true
	w.get_tree().create_timer(1.2).timeout.connect(smoke.queue_free)

	# Spent casing kicked out to the right.
	var shell := CPUParticles3D.new()
	shell.one_shot = true
	shell.emitting = false
	shell.amount = 1
	shell.lifetime = 0.7
	shell.direction = (at.global_basis.x * 1.0 + Vector3.UP * 0.8 + at.global_basis.z * 0.3).normalized()
	shell.spread = 12.0
	shell.initial_velocity_min = 2.5
	shell.initial_velocity_max = 3.5
	shell.gravity = Vector3(0, -12, 0)
	shell.angular_velocity_min = 600.0
	shell.angular_velocity_max = 900.0
	shell.mesh = _shell_mesh
	w.add_child(shell)
	shell.global_position = at.global_position + at.global_basis.z * 0.42 + at.global_basis.y * 0.02
	shell.emitting = true
	w.get_tree().create_timer(0.9).timeout.connect(shell.queue_free)


static func damage_number(pos: Vector3, amount: float, crit: bool) -> void:
	var lbl := Label3D.new()
	lbl.text = str(roundi(amount)) + ("!" if crit else "")
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.fixed_size = true
	lbl.pixel_size = 0.0012
	lbl.font_size = 44 if crit else 32
	lbl.outline_size = 10
	lbl.modulate = Color(1.0, 0.85, 0.2) if crit else Color(1, 1, 1)
	lbl.outline_modulate = Color(0, 0, 0, 0.8)
	Game.world.add_child(lbl)
	lbl.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0.3, randf_range(-0.3, 0.3))
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position", lbl.global_position + Vector3(0, 1.0, 0), 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.tween_property(lbl, "outline_modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(lbl.queue_free)


static func explosion(pos: Vector3) -> void:
	Sfx.play("explosion", pos, 4.0)
	_burst(pos, Vector3.UP, Color(1.0, 0.5, 0.15), 30, 9.0, 0.5, 0.03, 8.0, 4.0)
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	var m := _emissive(Color(1.0, 0.5, 0.15), 3.0)
	sm.material = m
	s.mesh = sm
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.world.add_child(s)
	s.global_position = pos
	s.scale = Vector3.ONE * 0.3
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector3.ONE * 2.6, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw.chain().tween_callback(s.queue_free)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 8.0
	l.omni_range = 9.0
	Game.world.add_child(l)
	l.global_position = pos
	var tl := l.create_tween()
	tl.tween_property(l, "light_energy", 0.0, 0.35)
	tl.tween_callback(l.queue_free)


## Expanding ground shockwave ring (slams, double jumps, phoenix).
static func ring(pos: Vector3, color: Color, radius: float) -> void:
	var t := TorusMesh.new()
	t.inner_radius = 0.85
	t.outer_radius = 1.0
	t.rings = 40
	t.ring_segments = 6
	var m := _emissive(color, 3.0)
	t.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.world.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3(0.3, 0.15, 0.3)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.3, radius), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(mi.queue_free)
	_burst(pos, Vector3.UP, color, int(10 + radius * 4), radius * 2.0, 0.5, 0.025, 6.0, 3.0)


## Heavy axe impact: a hot spark spray, ember chunks, a dust kick and a
## brief flash; the finisher adds a shock ring.
static func axe_impact(pos: Vector3, normal: Vector3, heavy: bool) -> void:
	_burst(pos, normal + Vector3.UP * 0.4, Color(1.0, 0.55, 0.15), 26 if heavy else 18, 11.0, 0.45, 0.02, 14.0, 5.0)
	_burst(pos, Vector3.UP, Color(1.0, 0.3, 0.08), 10, 5.0, 0.8, 0.05, 9.0, 3.0)
	_burst(pos - Vector3(0, 0.9, 0), Vector3.UP, Color(0.35, 0.3, 0.26), 10, 3.0, 0.9, 0.12, 2.0, 1.0)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.3)
	l.light_energy = 9.0 if heavy else 6.0
	l.omni_range = 6.0
	Game.world.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.25)
	tw.tween_callback(l.queue_free)
	if heavy:
		ring(pos - Vector3(0, 1.0, 0), Color(1.0, 0.5, 0.2), 3.0)


## Big gold call-out for combos ("POINT BLANK", "JUMP BASH", synergies).
static func combo_text(pos: Vector3, text: String, col: Color) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.fixed_size = true
	lbl.pixel_size = 0.0016
	lbl.font_size = 40
	lbl.outline_size = 12
	lbl.modulate = col
	lbl.outline_modulate = Color(0.1, 0.03, 0.0, 0.9)
	Game.world.add_child(lbl)
	lbl.global_position = pos
	lbl.scale = Vector3.ONE * 0.6
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector3.ONE * 1.1, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector3.ONE, 0.1)
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position", pos + Vector3(0, 0.8, 0), 0.9).set_delay(0.25)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6).set_delay(0.55)
	tw.tween_property(lbl, "outline_modulate:a", 0.0, 0.6).set_delay(0.55)
	tw.chain().tween_callback(lbl.queue_free)
