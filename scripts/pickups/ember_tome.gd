extends Node3D
## The Ember Codex left at the heart of a cleared site. Walk up and press E
## to read it: choose a boon, recover a little health and a few rounds.

const RANGE := 2.8

var taken := false
var book: Node3D
var light: OmniLight3D
var t := 0.0
var near := false


func _ready() -> void:
	var stone := ShaderMaterial.new()
	stone.shader = load("res://shaders/world/rock.gdshader")
	stone.set_shader_parameter("base_a", Color(0.55, 0.5, 0.45))
	stone.set_shader_parameter("base_b", Color(0.28, 0.26, 0.24))
	stone.set_shader_parameter("moss_amount", 0.4)
	var body := StaticBody3D.new()
	body.collision_layer = Game.L_WORLD
	add_child(body)
	for p in [[Vector3(1.4, 0.3, 1.4), 0.15], [Vector3(0.7, 0.9, 0.7), 0.75], [Vector3(1.0, 0.14, 0.8), 1.27]]:
		var bm := BoxMesh.new()
		bm.size = p[0]
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = stone
		mi.position.y = p[1]
		add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = p[0]
		cs.shape = sh
		cs.position.y = p[1]
		body.add_child(cs)

	# An open book hovering over the lectern.
	book = Node3D.new()
	book.position.y = 1.75
	add_child(book)
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.3, 0.07, 0.04)
	leather.roughness = 0.6
	var page := StandardMaterial3D.new()
	page.albedo_color = Color(0.92, 0.84, 0.66)
	page.emission_enabled = true
	page.emission = Color(1.0, 0.6, 0.25)
	page.emission_energy_multiplier = 0.9
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.9, 0.65, 0.25)
	gold.metallic = 1.0
	gold.roughness = 0.3
	for side in [-1.0, 1.0]:
		var half := Node3D.new()
		half.rotation.z = -0.22 * side
		book.add_child(half)
		var cover := BoxMesh.new()
		cover.size = Vector3(0.36, 0.025, 0.5)
		cover.material = leather
		var cm := MeshInstance3D.new()
		cm.mesh = cover
		cm.position = Vector3(0.18 * side, 0, 0)
		half.add_child(cm)
		var pages := BoxMesh.new()
		pages.size = Vector3(0.33, 0.05, 0.46)
		pages.material = page
		var pm := MeshInstance3D.new()
		pm.mesh = pages
		pm.position = Vector3(0.17 * side, 0.035, 0)
		half.add_child(pm)
		var clasp := BoxMesh.new()
		clasp.size = Vector3(0.04, 0.03, 0.08)
		clasp.material = gold
		var gm := MeshInstance3D.new()
		gm.mesh = clasp
		gm.position = Vector3(0.35 * side, 0.0, 0)
		half.add_child(gm)
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 2.5
	light.omni_range = 6.0
	light.position.y = 2.1
	add_child(light)
	# Embers drifting up from the pages.
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 2.2
	var pm2 := ParticleProcessMaterial.new()
	pm2.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm2.emission_box_extents = Vector3(0.35, 0.05, 0.25)
	pm2.direction = Vector3.UP
	pm2.spread = 20.0
	pm2.initial_velocity_min = 0.3
	pm2.initial_velocity_max = 0.8
	pm2.gravity = Vector3(0, 0.2, 0)
	pm2.turbulence_enabled = true
	var g := Gradient.new()
	g.set_color(0, Color(3.0, 1.5, 0.5, 1))
	g.set_color(1, Color(2.0, 0.4, 0.1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm2.color_ramp = gt
	p.process_material = pm2
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = WorldBuilder._soft_dot()
	q.material = qm
	p.draw_pass_1 = q
	p.position.y = 1.8
	add_child(p)
	p.name = "Embers"
	# Rise from the ground.
	scale = Vector3(1, 0.01, 1)
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.ring(global_position + Vector3(0, 0.1, 0), Color(1.0, 0.6, 0.25), 3.0)
	Sfx.play("emerge", global_position, -2.0)
	# A faint magical hum draws you to the lectern.
	Sfx.loop("fire", self, -14.0)


func _process(delta: float) -> void:
	t += delta
	if taken:
		return
	book.position.y = 1.75 + sin(t * 1.6) * 0.06
	book.rotation.y += delta * 0.4
	light.light_energy = 2.2 + sin(t * 3.0) * 0.4
	var p := Game.player
	if p == null:
		return
	var d := p.global_position.distance_to(global_position)
	var now_near: bool = d < RANGE and not p.dead
	if now_near != near:
		near = now_near
		Game.hud.set_interact("[E]  Read the Ember Codex" if near else "")
	if near and Input.is_action_just_pressed("interact"):
		_take()


func _take() -> void:
	taken = true
	near = false
	Game.hud.set_interact("")
	Sfx.play("codex", null, -13.0, 1.0, 0.0)   # soft: it was too loud and in-your-face
	var p := Game.player
	p.heal(20.0)
	p.add_ammo(20)
	Fx.death_burst(book.global_position, Color(1.0, 0.6, 0.25))
	Fx.ring(global_position + Vector3(0, 0.1, 0), Color(1.0, 0.7, 0.3), 4.0)
	Game.hud.offer_boons("Ember Codex  ·  Choose a boon")
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(book, "scale", Vector3.ONE * 0.01, 0.4).set_ease(Tween.EASE_IN)
	tw.tween_property(light, "light_energy", 0.3, 0.6)
	(get_node("Embers") as GPUParticles3D).emitting = false
