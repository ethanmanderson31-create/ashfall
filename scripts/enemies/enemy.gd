extends CharacterBody3D
## An ash creature in combat: physics body + procedural Creature visual +
## tactical AI. Ghouls surround the player and take turns attacking (only a
## couple swing at once, the rest circle and feint); hounds circle at range,
## then pounce at where you're going to be and retreat. Damage is applied on
## the animation's impact frame, only if the blow actually reaches you.

signal died_at(pos: Vector3)

const GRAVITY := 24.0
const CreatureScript := preload("res://scripts/enemies/creatures/creature.gd")

var kind := "ghoul"
var elite := false
var level := 0
var max_hp := 60.0
var hp := 60.0
var speed := 5.0
var damage := 12.0
var reach := 2.1
var knock := 5.0
var xp_value := 6.0
var size := 1.0

var state := "emerge"
var state_t := 0.0
var face := 0.0
var circle_dir := 1.0
var slot_angle := 0.0
var dodge_cd := 0.0
var attack_cd := 0.0
var combo_left := 0
var launched := false
var home := Vector3.ZERO
var creature: Creature
var emerge_t := 0.0
var stagger_t := 0.0
var hit_landed := false
var windup_t := 0.0
var turn_vel := 0.0
var lean := 0.0
var voice_t := 0.0
var hurt_voice_t := 0.0
var barked := false
var breath: Node
var burn_t := 0.0
var burn_dps := 0.0
var burn_tick := 0.0
var flames: CPUParticles3D

static var _slot_counter := 0


func setup(k: String, is_elite: bool, lvl: int) -> void:
	kind = k
	elite = is_elite
	level = lvl
	var hp_mult := 1.0 + 0.3 * lvl
	var dmg_mult := 1.0 + 0.15 * lvl
	match kind:
		"ghoul":
			max_hp = 55.0
			speed = 4.8
			damage = 11.0
			reach = 2.1
			knock = 5.0
			xp_value = 6.0
		"hound":
			max_hp = 38.0
			speed = 8.5
			damage = 9.0
			reach = 1.9
			knock = 7.0
			xp_value = 7.0
	if elite:
		size = 1.35
		max_hp *= 3.5
		damage *= 1.5
		reach *= 1.25
		knock *= 1.6
		speed *= 0.9
		xp_value *= 5.0
	max_hp *= hp_mult
	damage *= dmg_mult
	hp = max_hp


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = Game.L_ENEMY
	collision_mask = Game.L_WORLD | Game.L_PLAYER | Game.L_ENEMY
	floor_snap_length = 0.6
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	if kind == "hound":
		cap.radius = 0.42 * size
		cap.height = 1.1 * size
		cs.position.y = 0.55 * size
	else:
		cap.radius = 0.4 * size
		cap.height = 1.9 * size
		cs.position.y = 0.95 * size
	cs.shape = cap
	add_child(cs)

	creature = CreatureScript.new()
	creature.setup(kind)
	add_child(creature)
	creature.scale = Vector3.ONE * size
	if elite:
		creature.flesh_mat.set_shader_parameter("ember", Color(0.75, 0.25, 1.0))
		creature.flesh_mat.set_shader_parameter("crack_amount", 0.85)
	creature.attack_impact.connect(_on_impact)
	home = global_position
	_slot_counter += 1
	slot_angle = _slot_counter * 2.39996
	circle_dir = 1.0 if randf() < 0.5 else -1.0
	# Erupt from the ground.
	creature.position.y = -2.2 * size
	Fx.ring(global_position + Vector3(0, 0.1, 0), Color(1.0, 0.45, 0.15), 2.0 * size)
	Fx.impact(global_position + Vector3(0, 0.3, 0), Vector3.UP, true)
	Sfx.play("emerge", global_position, -7.0)
	if elite:
		Sfx.play("elite", global_position, -1.0, 0.85)
	voice_t = randf_range(1.0, 4.0)
	# Constant breathing presence; inverse-square falloff makes it swell as they close in.
	breath = Sfx.loop("ghoul_breath" if kind == "ghoul" else "hound_breath", creature, -12.0 + (3.0 if elite else 0.0), 1.6, 20.0)
	if breath:
		breath.pitch_scale = randf_range(0.92, 1.08) / size


func _player() -> CharacterBody3D:
	return Game.player


func _set_state(s: String) -> void:
	if s != "bite_windup" and s != "pounce":
		_heat(1.0)
		creature.crouch = 0.0
	state = s
	state_t = 0.0


func _attackers_now() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e.kind == kind and e.state in ["close_in", "attack", "pounce", "bite_windup"]:
			n += 1
	return n


func _physics_process(delta: float) -> void:
	if state == "dead":
		if creature.death_done():
			queue_free()
		return
	state_t += delta
	attack_cd -= delta
	dodge_cd -= delta
	if burn_t > 0.0:
		burn_t -= delta
		burn_tick -= delta
		if burn_tick <= 0.0:
			burn_tick = 0.5
			take_damage(burn_dps * 0.5, global_position + Vector3(0, 1.4 * size, 0), Vector3.ZERO, false, 0.0)
		if burn_t <= 0.0 and flames:
			flames.emitting = false
	hurt_voice_t -= delta
	voice_t -= delta
	if voice_t <= 0.0 and state in ["hunt", "recover", "retreat"]:
		voice_t = randf_range(4.0, 9.0)
		if kind == "ghoul":
			Sfx.play("ghoul", global_position, -12.0, 0.95 / size)
		elif not barked or randf() < 0.3:
			barked = true
			Sfx.play("hound_growl", global_position, -9.0, 0.95 / size)
	var p := _player()
	var to_p := p.global_position - global_position
	to_p.y = 0.0
	var dist := to_p.length()
	var dir := to_p / maxf(dist, 0.001)
	var side := Vector3(-dir.z, 0, dir.x)
	var hv := Vector3.ZERO
	var look := true

	match state:
		"emerge":
			emerge_t += delta / 0.9
			creature.position.y = lerpf(-2.2 * size, 0.0, ease(minf(emerge_t, 1.0), 0.4))
			look = false
			if emerge_t >= 1.0:
				creature.position.y = 0.0
				_set_state("hunt")
		"hunt":
			if kind == "hound":
				hv = _hound_hunt(dist, dir, side)
			else:
				hv = _ghoul_hunt(dist, dir, side)
		"close_in":
			hv = dir * speed * 1.1
			if dist <= reach * 0.85:
				_start_attack()
			elif state_t > 2.5:
				_set_state("hunt")
		"attack":
			# Track the target through the windup, commit once the swing starts.
			if creature.clip_progress() < 0.42:
				hv = dir * (0.8 if dist > reach * 0.7 else 0.0)
			else:
				look = false
				hv = Vector3(-sin(face), 0, -cos(face)) * (2.5 if creature.clip_progress() < 0.6 else 0.0)
			if not creature.is_attacking():
				if combo_left > 0 and dist < reach * 1.3:
					combo_left -= 1
					_start_attack()
				else:
					attack_cd = (randf_range(0.6, 1.0) if kind == "hound" else randf_range(0.9, 1.6)) / (1.0 + 0.1 * level)
					_set_state("recover")
		"bite_windup":
			if windup_t == 0.0:
				Sfx.play("snarl", global_position, -5.0, 1.0 / size)
			windup_t += delta
			_heat(1.0 + windup_t / 0.45 * 1.8)
			creature.crouch = minf(windup_t / 0.3, 1.0)
			hv = Vector3.ZERO
			if windup_t >= 0.45:
				_heat(1.0)
				creature.crouch = 0.0
				hit_landed = false
				if creature.attack("bite"):
					velocity += dir * 5.5
					_set_state("attack")
				else:
					_set_state("hunt")
		"pounce":
			var a := creature.clip_progress()
			look = a < 0.3
			if state_t <= delta * 1.5:
				Sfx.play("snarl", global_position, -3.0, 0.92 / size)
			if a < 0.33:
				_heat(1.0 + a / 0.33 * 1.8)
			elif not launched:
				_heat(1.0)
			if a >= 0.33 and not launched and is_on_floor():
				launched = true
				var lead: Vector3 = p.global_position + p.velocity * 0.35
				var to := lead - global_position
				to.y = 0
				var horiz := to.normalized() * minf(to.length() / 0.32, 17.0)
				velocity = Vector3(horiz.x, 5.5, horiz.z)
				face = atan2(-horiz.x, -horiz.z)
			if launched:
				hv = Vector3(velocity.x, 0, velocity.z)
				if is_on_floor() and a > 0.6:
					hv = hv * 0.2
				# Damage only if the jaws actually reach you mid-leap.
				if not hit_landed and _jaws_reach(1.5):
					hit_landed = true
					Sfx.play("bite", global_position, 2.0)
					p.take_damage(damage, self, dir * knock + Vector3(0, 3.0, 0))
					Fx.impact(p.global_position + Vector3(0, 1.1, 0), -dir, true)
					velocity.x *= -0.25
					velocity.z *= -0.25
			if not creature.is_attacking():
				attack_cd = randf_range(0.9, 1.5)
				_set_state("retreat")
		"retreat":
			hv = -dir * speed * 0.9 + side * circle_dir * speed * 0.4
			if state_t > (0.55 if kind == "hound" else 1.1) or dist > 9.0:
				_set_state("hunt")
		"recover":
			hv = -dir * 1.4 + side * circle_dir * 1.0
			if state_t > 0.55:
				_set_state("hunt")
		"stagger":
			look = false
			if state_t > stagger_t:
				_set_state("hunt")

	# Smart dodge: sidestep when the player is lining up a shot at us.
	if state == "hunt" and dodge_cd <= 0.0 and p.aiming and dist > 4.0:
		var cam_fwd: Vector3 = -p.cam.global_basis.z
		var to_me: Vector3 = (global_position + Vector3.UP - p.cam.global_position).normalized()
		if cam_fwd.dot(to_me) > 0.995 and randf() < 0.04 * (1.0 + level * 0.2):
			dodge_cd = randf_range(1.5, 3.0)
			velocity += side * (1.0 if randf() < 0.5 else -1.0) * 9.0
			Fx.impact(global_position + Vector3(0, 0.2, 0), Vector3.UP, false)

	# Personal space from other creatures.
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or e.state == "dead":
			continue
		var d: Vector3 = global_position - e.global_position
		d.y = 0
		var l := d.length()
		if l < 1.4 * size and l > 0.01:
			hv += d / l * (1.4 * size - l) * 4.0
	# Never shove into the player's body; stop at arm's length.
	if dist < 1.15 * size and state != "pounce":
		hv -= dir * maxf(hv.dot(dir), 0.0)

	var steer := kind == "hound" and state in ["hunt", "retreat", "recover"]
	steer = steer or (kind == "ghoul" and state == "hunt" and dist > 7.0)
	if steer and hv.length() > 0.6:
		var want := atan2(-hv.x, -hv.z)
		var diff := wrapf(want - face, -PI, PI)
		var rate := (5.5 if kind == "hound" else 4.0) * delta
		var stepv := clampf(diff, -rate, rate)
		face = wrapf(face + stepv, -PI, PI)
		turn_vel = lerpf(turn_vel, stepv / maxf(delta, 0.001), 1.0 - exp(-8.0 * delta))
		var fwd_dir := Vector3(-sin(face), 0, -cos(face))
		hv = fwd_dir * hv.length() * clampf(cos(diff) * 0.8 + 0.4, 0.25, 1.0)
		look = false
	else:
		turn_vel = lerpf(turn_vel, 0.0, 1.0 - exp(-6.0 * delta))
	# Molten creatures won't wade into deep water: they prowl the shore.
	if hv.length() > 0.1 and state != "dead":
		var ahead := global_position + hv.normalized() * 1.2 * size
		if Game.sample_height(ahead.x, ahead.z) < Game.WATER_LEVEL - 0.9:
			hv = Vector3.ZERO
	var accel := 10.0 if is_on_floor() else 1.5
	if state == "pounce" and launched and not is_on_floor():
		accel = 0.0
	velocity.x = lerpf(velocity.x, hv.x, 1.0 - exp(-accel * delta))
	velocity.z = lerpf(velocity.z, hv.z, 1.0 - exp(-accel * delta))
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()

	var hs := Vector2(velocity.x, velocity.z)
	if look and dist > 0.1:
		face = lerp_angle(face, atan2(-dir.x, -dir.z), 1.0 - exp(-9.0 * delta))
	elif not look and not steer and hs.length() > 1.0 and state != "attack":
		face = lerp_angle(face, atan2(-hs.x, -hs.y), 1.0 - exp(-6.0 * delta))
	creature.rotation.y = face
	lean = lerpf(lean, clampf(-turn_vel * 0.07, -0.35, 0.35), 1.0 - exp(-8.0 * delta))
	creature.rotation.z = lean if kind == "hound" else lean * 0.4
	creature.speed = hs.length() / size
	creature.has_look = true
	creature.look_at_point = p.global_position + Vector3(0, 1.4, 0)


func _ghoul_hunt(dist: float, dir: Vector3, side: Vector3) -> Vector3:
	var p := _player()
	if dist < 8.0 and attack_cd <= 0.0 and _attackers_now() < (1 + mini(level, 2)):
		_set_state("close_in")
		return dir * speed
	if dist > 7.5:
		# Approach toward a slot around the player so the pack surrounds you.
		var slot := p.global_position + Vector3(cos(slot_angle), 0, sin(slot_angle)) * 4.5
		var to := slot - global_position
		to.y = 0
		return to.normalized() * speed
	# Wait your turn: circle at mid range, feinting in and out.
	var want_r := 4.5 + sin(state_t * 1.3 + slot_angle) * 1.0
	var radial := (dist - want_r) * 1.2
	if randf() < 0.004:
		circle_dir = -circle_dir
	return dir * clampf(radial, -2.5, 3.0) + side * circle_dir * speed * 0.45


func _hound_hunt(dist: float, dir: Vector3, side: Vector3) -> Vector3:
	if dist < 2.3 and attack_cd <= 0.0:
		_start_bite()
		return Vector3.ZERO
	if dist < 10.5 and dist > 3.2 and attack_cd <= 0.0 and _attackers_now() < 2 + int(level / 2):
		launched = false
		hit_landed = false
		if creature.attack("pounce"):
			_set_state("pounce")
		return Vector3.ZERO
	# Stay close and keep pressure on: tight arcs, then straight in.
	var want_r := 5.0
	if attack_cd <= 0.0:
		return dir * speed
	var radial := clampf((dist - want_r) * 0.5, -0.8, 1.0)
	if randf() < 0.004:
		circle_dir = -circle_dir
	return (side * circle_dir + dir * radial).normalized() * speed * 0.85


func _start_attack() -> void:
	hit_landed = false
	var clip := "swipe_r" if randf() < 0.5 else "swipe_l"
	if creature.attack(clip):
		Sfx.play("ghoul_attack", global_position, -4.0, 0.9 / size)
		if combo_left == 0 and state != "attack":
			combo_left = 1 if randf() < 0.35 + 0.1 * level else 0
		_set_state("attack")


func _start_bite() -> void:
	windup_t = 0.0
	combo_left = 0
	_set_state("bite_windup")


func _heat(v: float) -> void:
	creature.flesh_mat.set_shader_parameter("heat", v)


## True if the creature's mouth is within r metres of the player's chest.
func _jaws_reach(r: float) -> bool:
	var p := _player()
	var fwd := Vector3(-sin(face), 0, -cos(face))
	var mouth := global_position + fwd * 0.95 * size + Vector3(0, 0.65 * size, 0)
	return mouth.distance_to(p.global_position + Vector3(0, 1.0, 0)) < r


func _on_impact(clip: String) -> void:
	if state == "dead" or hit_landed or clip == "pounce":
		return
	if clip == "bite":
		if _jaws_reach(1.45):
			hit_landed = true
			var pp := _player()
			var bd := (pp.global_position - global_position).normalized()
			pp.take_damage(damage, self, bd * knock * 0.6 + Vector3(0, 1.5, 0))
			Sfx.play("bite", global_position, 2.0)
			Fx.impact(pp.global_position + Vector3(0, 1.0, 0), -bd, true)
		return
	var p := _player()
	var to := p.global_position - global_position
	to.y = 0
	var fwd := Vector3(-sin(face), 0, -cos(face))
	var in_front := to.length() < 0.6 or fwd.angle_to(to.normalized()) < 1.1
	var r := reach * (1.25 if clip == "pounce" else 1.0)
	if kind == "ghoul":
		Sfx.play("ghoul_attack", global_position, -5.0, 0.8 / size)
	if to.length() <= r and in_front and absf(p.global_position.y - global_position.y) < 1.8:
		hit_landed = true
		var kdir := to.normalized()
		p.take_damage(damage, self, kdir * knock + Vector3(0, 2.5, 0))


## Returns true if this hit killed the creature.
func take_damage(dmg: float, pos: Vector3, dir: Vector3, crit: bool, kb: float = 2.5) -> bool:
	if state == "dead":
		return false
	hp -= dmg
	Fx.damage_number(pos, dmg, crit)
	creature.hit_react(dir)
	if hurt_voice_t <= 0.0 and hp > 0.0:
		hurt_voice_t = 0.9
		Sfx.play("ghoul_attack" if kind == "ghoul" else "hound_growl", global_position, -11.0, 1.15 / size)
	var resist := 0.35 if elite else 1.0
	velocity += Vector3(dir.x, 0, dir.z) * kb * resist
	if kb >= 9.0:
		velocity.y = (3.5 if kb < 14.0 else 6.0) * resist
	if state == "emerge":
		pass
	elif kb >= 5.0 and state in ["attack", "close_in", "hunt"] and not elite:
		creature.attack_a = -1.0
		stagger_t = 0.45
		_set_state("stagger")
	if hp <= 0.0:
		_die()
		return true
	return false


func _die() -> void:
	state = "dead"
	_silence()
	collision_layer = 0
	collision_mask = Game.L_WORLD
	velocity = Vector3.ZERO
	creature.die()
	if elite:
		Sfx.play("elite", global_position, -3.0, 0.7)
	else:
		Sfx.play("death", global_position, -7.0, 0.9 if kind == "ghoul" else 1.15)
	Fx.death_burst(global_position + Vector3(0, 1.0 * size, 0), Color(0.8, 0.3, 1.0) if elite else Color(1.0, 0.45, 0.15))
	var orbs := 5 if elite else 2
	for i in orbs:
		_drop("xp", xp_value / orbs)
	var p := Game.player
	if elite:
		_drop("ammo", 12)
	elif randf() < p.stats.ammo_drop:
		_drop("ammo", roundi(randi_range(3, 6) * p.stats.ammo_amount))
	if randf() < (0.25 if elite else 0.025):
		_drop_potion(Consumables.roll(0))
	died_at.emit(global_position)


func _drop_potion(id: String) -> void:
	var orb := preload("res://scripts/pickups/pickup.gd").new()
	orb.kind = "potion"
	orb.item = id
	Game.world.add_child(orb)
	orb.global_position = global_position + Vector3(0, 1.2, 0)


func _drop(k: String, value: float) -> void:
	var orb := preload("res://scripts/pickups/pickup.gd").new()
	orb.kind = k
	orb.value = value
	Game.world.add_child(orb)
	orb.global_position = global_position + Vector3(randf_range(-0.6, 0.6), 1.0, randf_range(-0.6, 0.6))


## Stop this creature's breathing loop for good (death or removal).
func _silence() -> void:
	if is_instance_valid(breath):
		breath.stop()
		breath.queue_free()
	breath = null


func _exit_tree() -> void:
	_silence()


## Molten Edge: set the creature ablaze.
func ignite(seconds: float, dps: float) -> void:
	burn_t = seconds
	burn_dps = dps
	if flames == null:
		flames = CPUParticles3D.new()
		flames.amount = 24
		flames.lifetime = 0.6
		flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		flames.emission_sphere_radius = 0.45 * size
		flames.direction = Vector3.UP
		flames.spread = 20.0
		flames.initial_velocity_min = 0.5
		flames.initial_velocity_max = 1.6
		flames.gravity = Vector3(0, 2.0, 0)
		var g := Gradient.new()
		g.set_color(0, Color(3.0, 1.4, 0.4, 1))
		g.set_color(1, Color(1.0, 0.2, 0.05, 0))
		flames.color_ramp = g
		var q := QuadMesh.new()
		q.size = Vector2(0.18, 0.18)
		var qm := StandardMaterial3D.new()
		qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		qm.vertex_color_use_as_albedo = true
		qm.albedo_texture = WorldBuilder._soft_dot()
		q.material = qm
		flames.mesh = q
		flames.position.y = 1.0 * size
		add_child(flames)
	flames.emitting = true
