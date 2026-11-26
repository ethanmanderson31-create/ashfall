extends CharacterBody3D
## Act I boss: the Ashen Colossus. Shoves you away up close, slams the
## ground to send out shockwaves you must jump, charges across the arena,
## summons ghouls at 66% and 33% health, and enrages below 40%.

signal died_at(pos: Vector3)
signal health_changed(ratio: float)

const GRAVITY := 24.0
const SIZE := 2.8
const CreatureScript := preload("res://scripts/enemies/creatures/creature.gd")
const SlamScript := preload("res://scripts/combat/slam_fx.gd")

var kind := "colossus"
var elite := true
var max_hp := 3400.0
var hp := 3400.0
var state := "dormant"
var state_t := 0.0
var face := 0.0
var attack_cd := 2.0
var charge_dir := Vector3.ZERO
var charge_hit := false
var summoned := 0
var enraged := false
var creature: Creature
var arena_center := Vector3.ZERO
var summon_cb: Callable
var step_dist := 0.0
var last_pos := Vector3.ZERO
var env_saved := {}
var slam_cd := 4.0
var breath: Node


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = Game.L_ENEMY
	collision_mask = Game.L_WORLD | Game.L_PLAYER
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.25
	cap.height = 5.4
	cs.shape = cap
	cs.position.y = 2.7
	add_child(cs)
	creature = CreatureScript.new()
	creature.setup("colossus")
	add_child(creature)
	creature.scale = Vector3.ONE * SIZE
	creature.attack_impact.connect(_on_impact)
	creature.position.y = -6.0
	arena_center = global_position


func awaken() -> void:
	if state != "dormant":
		return
	state = "emerge"
	state_t = 0.0
	Fx.ring(global_position + Vector3(0, 0.2, 0), Color(1.0, 0.45, 0.15), 10.0)
	Fx.explosion(global_position + Vector3(0, 1.0, 0))
	Game.player.shake = 1.4
	_darken_arena(true)
	last_pos = global_position
	breath = Sfx.loop("boss_breath", creature, -5.0, 5.0, 55.0)
	Sfx.play("emerge", global_position, 8.0, 0.6)
	Sfx.play("slam", global_position, 4.0, 0.7)
	get_tree().create_timer(1.4).timeout.connect(func(): Sfx.play("boss_voice", global_position, 9.0, 0.6, 0.0))


func _go(s: String) -> void:
	state = s
	state_t = 0.0


func _physics_process(delta: float) -> void:
	if state == "dead":
		if creature.death_done():
			queue_free()
		return
	state_t += delta
	attack_cd -= delta
	slam_cd -= delta
	var p := Game.player
	var to_p := p.global_position - global_position
	to_p.y = 0.0
	var dist := to_p.length()
	var dir := to_p / maxf(dist, 0.001)
	var hv := Vector3.ZERO
	var look := true
	var spd := 4.4 if enraged else 3.3

	match state:
		"dormant":
			look = false
		"emerge":
			creature.position.y = lerpf(-6.0, 0.0, ease(minf(state_t / 1.8, 1.0), 0.4))
			if state_t > 1.0 and state_t - delta <= 1.0:
				Game.player.shake = 1.3
			Game.player.shake = maxf(Game.player.shake, 0.5)
			if state_t > 2.2:
				creature.position.y = 0.0
				creature.attack("slam")
				_go("roar")
		"roar":
			if not creature.is_attacking():
				_go("hunt")
		"hunt":
			hv = dir * spd if dist > 4.0 else Vector3.ZERO
			if attack_cd <= 0.0:
				_choose_attack(dist)
		"attack":
			hv = dir * (0.6 if creature.clip_progress() < 0.4 else 0.0)
			look = creature.clip_progress() < 0.42
			if not creature.is_attacking():
				attack_cd = randf_range(0.8, 1.6) * (0.65 if enraged else 1.0)
				_go("hunt")
		"charge_windup":
			look = true
			creature.speed = 0.0
			if state_t > 0.75:
				charge_dir = dir
				charge_hit = false
				_go("charge")
		"charge":
			look = false
			hv = charge_dir * (15.0 if enraged else 12.5)
			if not charge_hit and dist < 2.6:
				charge_hit = true
				p.take_damage(26.0, self, charge_dir * 17.0 + dir * 4.0 + Vector3(0, 7.0, 0))
				Sfx.play("axe_hit", p.global_position, 6.0, 0.55, 0.05, 3)
				Game.hud.flash(Color(1.0, 0.3, 0.15), 0.55)
			if state_t > 1.5 or (state_t > 0.3 and get_slide_collision_count() > 0 and get_slide_collision(0).get_collider() != p):
				Game.player.shake = maxf(Game.player.shake, 0.6)
				attack_cd = 1.6
				_go("recover")
		"recover":
			look = false
			if state_t > 1.3:
				_go("hunt")

	velocity.x = lerpf(velocity.x, hv.x, 1.0 - exp(-(6.0 if state != "charge" else 3.0) * delta))
	velocity.z = lerpf(velocity.z, hv.z, 1.0 - exp(-(6.0 if state != "charge" else 3.0) * delta))
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	var hs := Vector2(velocity.x, velocity.z)
	if look and dist > 0.1:
		face = lerp_angle(face, atan2(-dir.x, -dir.z), 1.0 - exp(-4.0 * delta))
	elif hs.length() > 1.0:
		face = lerp_angle(face, atan2(-hs.x, -hs.y), 1.0 - exp(-4.0 * delta))
	creature.rotation.y = face
	creature.speed = hs.length() / SIZE * 1.4
	# Every heavy footfall shakes the ground under you.
	if state not in ["dormant", "emerge", "dead"]:
		step_dist += Vector2(global_position.x - last_pos.x, global_position.z - last_pos.z).length()
		last_pos = global_position
		if step_dist > (3.2 if state != "charge" else 2.4):
			step_dist = 0.0
			var fd := global_position.distance_to(p.global_position)
			p.shake = maxf(p.shake, 0.75 * (1.0 - clampf(fd / 32.0, 0.0, 1.0)))
			Sfx.play("step", global_position, 0.0, 1.0, 0.08)
			Fx.impact(global_position + Vector3(randf_range(-1, 1), 0.1, randf_range(-1, 1)), Vector3.UP, false)
	creature.has_look = state != "dormant"
	creature.look_at_point = p.global_position + Vector3(0, 1.5, 0)


func _choose_attack(dist: float) -> void:
	# The slam is now a rarer, devastating move on its own cooldown.
	var can_slam := slam_cd <= 0.0
	if dist < 5.5:
		if can_slam and randf() < 0.5:
			_slam()
		else:
			creature.attack("shove")
			_go("attack")
	elif dist < 18.0:
		if can_slam and randf() < 0.55:
			_slam()
		else:
			_go("charge_windup")
			Sfx.play("boss_voice", global_position, 6.0, 0.72)
			Fx.ring(global_position + Vector3(0, 0.2, 0), Color(1.0, 0.4, 0.1), 3.0)


func _slam() -> void:
	slam_cd = 6.5 if enraged else 9.0
	creature.attack("slam")
	Sfx.play("boss_voice", global_position, 0.0, 0.62)
	_go("attack")
	_telegraph()


## Wind-up warning: a pulsing red ring where the slam will land, a rising
## rumble, and the ground starting to shake.
func _telegraph() -> void:
	var fwd := Vector3(-sin(face), 0, -cos(face))
	var at := global_position + fwd * 2.6
	at.y = Game.sample_height(at.x, at.z) + 0.08
	var t := TorusMesh.new()
	t.inner_radius = 0.82
	t.outer_radius = 1.0
	t.rings = 64
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/creatures/ember_flesh.gdshader")
	m.set_shader_parameter("crack_amount", 1.0)
	m.set_shader_parameter("crack_scale", 3.0)
	m.set_shader_parameter("pattern_scale", 1.6)
	m.set_shader_parameter("dissolve", 0.98)
	t.material = m
	var ring := MeshInstance3D.new()
	ring.mesh = t
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.world.add_child(ring)
	ring.global_position = at
	ring.scale = Vector3(4.0, 0.5, 4.0)
	var windup := 1.5 * 0.56 / (1.0 if not enraged else 1.0)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(2.2, 0.5, 2.2), windup).set_ease(Tween.EASE_IN)
	# Cracks spread in from nothing and pulse hotter as the slam winds up.
	tw.tween_method(func(v: float):
		m.set_shader_parameter("dissolve", 0.98 - v * 0.98)
		m.set_shader_parameter("ember_energy", 4.0 + v * 6.0 * (0.7 + 0.3 * sin(v * 30.0))), 0.0, 1.0, windup)
	tw.chain().tween_callback(ring.queue_free)
	Sfx.play("emerge", at, 2.0, 0.55, 0.0)
	var p := Game.player
	var steps := 6
	for i in steps:
		get_tree().create_timer(windup * i / steps).timeout.connect(func():
			if is_instance_valid(p):
				p.shake = maxf(p.shake, 0.15 + 0.08 * i))


func _on_impact(clip: String) -> void:
	if state == "dead":
		return
	var p := Game.player
	var fwd := Vector3(-sin(face), 0, -cos(face))
	var to := p.global_position - global_position
	to.y = 0
	match clip:
		"shove":
			if to.length() < 4.6 and fwd.angle_to(to.normalized()) < 1.1:
				p.take_damage(28.0 if enraged else 22.0, self, to.normalized() * 19.0 + Vector3(0, 6.0, 0))
				Sfx.play("axe_hit", p.global_position, 6.0, 0.6, 0.05, 3)
				Game.hud.flash(Color(1.0, 0.3, 0.15), 0.55)
			Game.player.shake = maxf(Game.player.shake, 0.9)
		"slam":
			var at := global_position + fwd * 2.6
			if state == "roar":
				at = global_position
			var w := SlamScript.new()
			w.damage = 44.0 if enraged else 36.0
			w.grow_speed = 14.0 if enraged else 11.0
			w.max_radius = 18.0
			Game.world.add_child(w)
			w.global_position = Vector3(at.x, Game.sample_height(at.x, at.z) + 0.05, at.z)
			Game.player.shake = maxf(Game.player.shake, 1.3)
			Sfx.play("slam", w.global_position, 8.0, 1.0, 0.04)
			Game.hud.flash(Color(1.0, 0.55, 0.25), 0.3)
			var near := p.global_position - at
			near.y = 0
			if near.length() < 3.2 and p.is_on_floor():
				p.take_damage(40.0, self, near.normalized() * 14.0 + Vector3(0, 10.0, 0))


func take_damage(dmg: float, pos: Vector3, dir: Vector3, crit: bool, _kb: float = 2.5) -> bool:
	if state in ["dead", "dormant", "emerge"]:
		return false
	hp -= dmg
	Fx.damage_number(pos, dmg, crit)
	creature.hit_react(dir)
	creature.hit *= 0.35
	health_changed.emit(hp / max_hp)
	var ratio := hp / max_hp
	if summoned == 0 and ratio < 0.66 or summoned == 1 and ratio < 0.33:
		summoned += 1
		if summon_cb.is_valid():
			summon_cb.call(2)
		Sfx.play("boss_voice", global_position, 6.0, 0.6)
		Game.hud.show_banner("THE COLOSSUS CALLS ITS BROOD")
	if not enraged and ratio < 0.4:
		enraged = true
		creature.flesh_mat.set_shader_parameter("ember_energy", 10.0)
		creature.flesh_mat.set_shader_parameter("crack_amount", 1.1)
		Game.hud.show_banner("THE COLOSSUS ENRAGES")
		Sfx.play("boss_voice", global_position, 8.0, 0.55)
	if hp <= 0.0:
		state = "dead"
		collision_layer = 0
		creature.die()
		Fx.explosion(global_position + Vector3(0, 2.5, 0))
		Fx.ring(global_position + Vector3(0, 0.3, 0), Color(1.0, 0.5, 0.2), 14.0)
		for i in 12:
			var orb := preload("res://scripts/pickups/pickup.gd").new()
			orb.kind = "xp" if i < 9 else "ammo"
			orb.value = 12.0 if i < 9 else 15.0
			Game.world.add_child(orb)
			orb.global_position = global_position + Vector3(randf_range(-2, 2), 2.0, randf_range(-2, 2))
		_darken_arena(false)
		if is_instance_valid(breath):
			breath.stop()
			breath.queue_free()
		Game.player.shake = 1.5
		Sfx.play("boss_voice", global_position, 10.0, 0.5, 0.0)
		Sfx.play("slam", global_position, 6.0, 0.8)
		var pot := preload("res://scripts/pickups/pickup.gd").new()
		pot.kind = "potion"
		pot.item = Consumables.roll(2)
		Game.world.add_child(pot)
		pot.global_position = global_position + Vector3(1.5, 2.0, 0)
		died_at.emit(global_position)
		return true
	return false


## Blood-red sky and thicker fog while the Colossus lives.
func _darken_arena(on: bool) -> void:
	var env: Environment = Game.env
	var sun: DirectionalLight3D = Game.sun
	if env == null or sun == null:
		return
	if on:
		env_saved = {"fog": env.fog_light_color, "vfog": env.volumetric_fog_albedo, "vden": env.volumetric_fog_density,
			"sun": sun.light_color, "energy": sun.light_energy}
	var tw := get_tree().create_tween()
	tw.set_parallel(true)
	var t := 2.5
	tw.tween_property(env, "fog_light_color", Color(0.55, 0.22, 0.14) if on else env_saved.fog, t)
	tw.tween_property(env, "volumetric_fog_albedo", Color(0.9, 0.45, 0.3) if on else env_saved.vfog, t)
	tw.tween_property(env, "volumetric_fog_density", (env_saved.vden * 2.2) if on else env_saved.vden, t)
	tw.tween_property(sun, "light_color", Color(1.0, 0.55, 0.38) if on else env_saved.sun, t)
	tw.tween_property(sun, "light_energy", (env_saved.energy * 0.75) if on else env_saved.energy, t)
