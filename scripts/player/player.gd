extends CharacterBody3D
## Third-person controller. Gun + energy blade combat; every stat is derived
## from the boons picked this run (see SkillTree), so builds play differently.

signal health_changed(cur: float, maxv: float, shield: float)
signal ammo_changed(mag: int, mag_max: int, reserve: int, reloading: bool)
signal xp_changed(xp: float, need: float, level: int)
signal leveled_up
signal hit_enemy(killed: bool, crit: bool)
signal fired
signal died
signal inventory_changed
signal weapon_changed(w: String)

const GRAVITY := 24.0
const MOUSE_SENS := 0.0025

var ranks := {}
var stats := {}
var hp := 100.0
var shield := 0.0
var shield_t := 0.0
var ammo := 30
var reserve := 90
var level := 1
var xp := 0.0
var xp_need := 30.0
var kills := 0
var phoenix_used := false

var yaw := 0.0
var pitch := -0.12
var aiming := false
var force_aim := false
var force_fire := false
var input_enabled := true
var reloading := false
var reload_t := 0.0
var fire_cd := 0.0
var shot_count := 0
var dodge_t := 0.0
var dodge_cd := 0.0
var dodge_dir := Vector3.ZERO
var dodge_hits: Array = []
var invuln := 0.0
var last_shot_t := 10.0
var last_hurt_t := 10.0
var air_jumps_left := 0
var shake := 0.0
var recoil := 0.0
var dead := false
var inventory: Array[String] = []
var buffs := {}               ## name -> [seconds_left, value]
var weapon := "gun"
var roll_dur := 0.8
var bash_t := 0.0
var bash_dur := 0.36
var bash_hit_done := false
var bash_shot_t := 0.0
var recover_t := 0.0
var dancer_t := 0.0
var lunged := false
var gun_trim_mat: StandardMaterial3D
var axe_edge_mat: StandardMaterial3D
var gun_runes: Node3D
var gun_flame: GPUParticles3D
var axe_flame: GPUParticles3D
var ward_aura: GPUParticles3D
var streak := 0
var empowered := false
var ward_cd := 0.0
var ward_t := 0.0
var flinch := 0.0
var knock_t := 0.0
var was_on_floor := true
var land_t := 0.0
var air_t := 0.0

# Melee state.
var swing_t := 0.0
var swing_dur := 0.3
var swing_side := 1.0
var swing_hit_done := false
var combo := 0
var combo_reset_t := 0.0
var melee_cd := 0.0
var slamming := false
var frenzy := 0
var frenzy_t := 0.0
var overclock_t := 0.0

var visual: Node3D
var anim: AnimationPlayer
var skel: Skeleton3D
var cam_pivot: Node3D
var cam_pitch: Node3D
var spring: SpringArm3D
var cam: Camera3D
var muzzle: Node3D
var mag_node: Node3D
var hand_mag: MeshInstance3D
var mag_dropped := false
var mag_in_played := false
var slap_played := false
var whoosh_played := false
var xp_streak := 0
var xp_streak_t := 0.0
var gun: Node3D
var blade: Node3D
var aim_mod: AimModifier
var cur_anim := ""
var face_yaw := 0.0
var swim: SwimController
var force_move := Vector2.ZERO     ## scripted input for the screenshot tours

static var _slash_mesh: ArrayMesh


# ============================================================ build stats

func rank(id: String) -> int:
	return int(ranks.get(id, 0))


func recalc() -> void:
	var s := {}
	var lvl_dmg := 1.0 + 0.04 * (level - 1)
	s.gun_damage = 14.0 * (1.0 + 0.3 * rank("g_dmg")) * lvl_dmg
	s.fire_rate = 8.5 * (1.0 + 0.25 * rank("g_rate"))
	s.mag = 30 + 12 * rank("g_mag")
	s.max_reserve = 90 + 40 * rank("g_mag") + 40 * rank("g_scav")
	s.start_reserve = 60
	s.reload_time = 1.7 * (0.55 if rank("g_reload") > 0 else 1.0)
	s.crit_chance = 0.06 + 0.15 * rank("g_crit")
	s.crit_mult = 2.5 if rank("g_crit") > 0 else 2.0
	s.pierce = rank("g_pierce")
	s.deadeye = rank("g_deadeye") > 0
	s.explode_chance = 0.2 * rank("g_explode")
	s.ammo_drop = 0.22 * (2.0 if rank("g_scav") > 0 else 1.0)
	s.ammo_amount = 1.6 if rank("g_scav") > 0 else 1.0
	s.lead_storm = rank("g_ks_storm") > 0
	s.overclock = rank("g_ks_overclock") > 0

	s.melee_damage = 48.0 * (1.0 + 0.4 * rank("b_dmg")) * lvl_dmg
	s.attack_speed = 1.0 + 0.25 * rank("b_speed")
	s.jump = 8.5 * (1.0 + 0.4 * rank("b_leap"))
	s.air_jumps = 1 if rank("b_double") > 0 else 0
	s.melee_heal = 5.0 * rank("b_leech")
	s.lunge = rank("b_lunge")
	s.slam = rank("b_slam") > 0
	s.blade_dash = rank("b_dash") > 0
	s.reach = 1.0 + 0.5 * rank("b_reach")
	s.bladestorm = rank("b_ks_storm") > 0
	s.frenzy = rank("b_ks_frenzy") > 0

	var jugg := rank("s_ks_jugg") > 0
	s.max_hp = 100.0 + 40.0 * rank("s_hp") + (100.0 if jugg else 0.0) + 6.0 * (level - 1)
	s.move_speed = 5.0 * (1.0 + 0.15 * rank("s_speed")) * (0.9 if jugg else 1.0)
	s.sprint_mult = 1.65
	s.dodge_cd = 0.8 * (0.5 if rank("s_dodge") > 0 else 1.0)
	s.regen = 3.0 * rank("s_regen")
	s.pickup_radius = 7.0 * (2.0 if rank("s_magnet") > 0 else 1.0)
	s.armor = 0.2 * rank("s_armor")
	s.aegis = rank("s_aegis") > 0
	s.thorns = 30.0 * rank("s_thorns")
	s.phoenix = rank("s_ks_phoenix") > 0
	s.hot_streak = SkillTree.has_mastery(ranks, "gun")
	s.combo = SkillTree.has_mastery(ranks, "blade")
	s.ember_ward = SkillTree.has_mastery(ranks, "ward")
	s.syn = {}
	for sy in SkillTree.active_synergies(ranks):
		s.syn[sy.id] = true
	stats = s


func apply_boon(id: String) -> void:
	var branch: String = SkillTree.find(id).get("branch", "")
	var had := SkillTree.has_mastery(ranks, branch)
	var new_syn := SkillTree.completes(ranks, id)
	ranks[id] = rank(id) + 1
	recalc()
	if id == "s_hp":
		heal(999.0)
	elif id == "s_ks_jugg":
		heal(100.0)
	elif id == "g_mag":
		reserve = mini(reserve + 40, stats.max_reserve)
	update_weapon_look()
	celebrate_boon(id)
	for sy in new_syn:
		if Game.hud:
			get_tree().create_timer(1.6).timeout.connect(func():
				Game.hud.show_banner("SYNERGY  ·  " + String(sy.name).to_upper())
				Game.hud.prompt(sy.desc, 3.5)
				Sfx.play("mastery", null, -8.0, 1.1, 0.0))
	if not had and SkillTree.has_mastery(ranks, branch) and Game.hud:
		var m: Dictionary = SkillTree.MASTERY[branch]
		Game.hud.show_banner("MASTERY AWAKENED  ·  " + String(m.name).to_upper())
		Sfx.play("mastery", null, -7.0, 1.0, 0.0)
		Game.hud.prompt(m.desc, 4.0)
	hp = minf(hp, stats.max_hp)
	_emit_all()
	if Game.hud:
		Game.hud._refresh_build()


func _emit_all() -> void:
	health_changed.emit(hp, stats.max_hp, shield)
	ammo_changed.emit(ammo, stats.mag, reserve, reloading)
	xp_changed.emit(xp, xp_need, level)


# ============================================================ setup

func _ready() -> void:
	recalc()
	hp = stats.max_hp
	ammo = stats.mag
	reserve = stats.start_reserve
	collision_layer = Game.L_PLAYER
	collision_mask = Game.L_WORLD | Game.L_ENEMY
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)

	visual = Node3D.new()
	add_child(visual)
	var model: Node3D = load("res://assets/models/player/Soldier.glb").instantiate()
	visual.add_child(model)
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	skel = model.find_children("*", "Skeleton3D", true, false)[0]
	for n in ["Idle", "Walk", "Run"]:
		if anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_build_gun()
	_build_blade()
	aim_mod = AimModifier.new()
	aim_mod.gun = gun
	aim_mod.blade = blade
	skel.add_child(aim_mod)
	swim = SwimController.new()
	swim.p = self
	add_child(swim)
	var steps := Footsteps.new()
	steps.p = self
	add_child(steps)

	cam_pivot = Node3D.new()
	cam_pivot.position.y = 1.55
	add_child(cam_pivot)
	cam_pitch = Node3D.new()
	cam_pivot.add_child(cam_pitch)
	spring = SpringArm3D.new()
	spring.spring_length = 3.6
	spring.collision_mask = Game.L_WORLD
	spring.margin = 0.2
	var ss := SphereShape3D.new()
	ss.radius = 0.2
	spring.shape = ss
	spring.position.x = 0.55
	cam_pitch.add_child(spring)
	spring.add_excluded_object(get_rid())
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 900.0
	spring.add_child(cam)
	cam.current = true
	face_yaw = yaw


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)


func _build_gun() -> void:
	gun = Node3D.new()
	gun.name = "Gun"
	gun.top_level = true
	add_child(gun)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.09, 0.09, 0.1)
	metal.metallic = 0.8
	metal.roughness = 0.35
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.1, 0.1, 0.1)
	trim.emission_enabled = true
	trim.emission = Color(1.0, 0.45, 0.1)
	trim.emission_energy_multiplier = 3.0
	gun_trim_mat = trim
	_box(gun, Vector3(0.06, 0.1, 0.42), Vector3(0, 0.04, -0.12), metal)
	_box(gun, Vector3(0.035, 0.035, 0.26), Vector3(0, 0.06, -0.44), metal)
	_box(gun, Vector3(0.045, 0.12, 0.06), Vector3(0, -0.04, 0.0), metal)
	mag_node = Node3D.new()
	mag_node.position = Vector3(0, -0.03, -0.2)
	gun.add_child(mag_node)
	_box(mag_node, Vector3(0.04, 0.12, 0.05), Vector3(0, -0.01, 0), metal)
	hand_mag = MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.04, 0.12, 0.05)
	hm.material = metal
	hand_mag.mesh = hm
	hand_mag.top_level = true
	hand_mag.visible = false
	add_child(hand_mag)
	_box(gun, Vector3(0.05, 0.07, 0.18), Vector3(0, 0.05, 0.16), metal)
	_box(gun, Vector3(0.062, 0.012, 0.26), Vector3(0, 0.095, -0.12), trim)
	muzzle = Node3D.new()
	muzzle.position = Vector3(0, 0.06, -0.58)
	gun.add_child(muzzle)


## Two-handed battle axe: dark haft, bearded blade with a molten edge.
## Local -Z runs up the haft from the grip; the edge faces local -Y.
func _build_blade() -> void:
	blade = Node3D.new()
	blade.name = "Axe"
	blade.top_level = true
	blade.visible = false
	add_child(blade)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.16, 0.1, 0.07)
	wood.roughness = 0.8
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.13, 0.12, 0.12)
	iron.metallic = 0.85
	iron.roughness = 0.38
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color(1.0, 0.5, 0.2)
	edge.emission_enabled = true
	edge.emission = Color(1.0, 0.4, 0.1)
	edge.emission_energy_multiplier = 4.0
	axe_edge_mat = edge
	var haft := CylinderMesh.new()
	haft.top_radius = 0.022
	haft.bottom_radius = 0.026
	haft.height = 1.15
	haft.material = wood
	var hm := MeshInstance3D.new()
	hm.mesh = haft
	hm.rotation.x = PI * 0.5
	hm.position.z = -0.4
	blade.add_child(hm)
	for z in [0.12, -0.2, -0.95]:
		var band := CylinderMesh.new()
		band.top_radius = 0.03
		band.bottom_radius = 0.03
		band.height = 0.05
		band.material = iron
		var bm := MeshInstance3D.new()
		bm.mesh = band
		bm.rotation.x = PI * 0.5
		bm.position.z = z
		blade.add_child(bm)
	# Bearded blade outline in the (z, y) plane, extruded along x.
	var head := PackedVector2Array([
		Vector2(-0.74, 0.03), Vector2(-1.0, 0.03), Vector2(-1.02, -0.08),
		Vector2(-1.13, -0.3), Vector2(-1.1, -0.42), Vector2(-0.98, -0.47),
		Vector2(-0.82, -0.44), Vector2(-0.7, -0.36), Vector2(-0.72, -0.12),
	])
	var spike := PackedVector2Array([Vector2(-0.8, 0.03), Vector2(-0.94, 0.03), Vector2(-0.87, 0.2)])
	_extrude(blade, head, 0.045, iron)
	_extrude(blade, spike, 0.035, iron)
	var rim := PackedVector2Array()
	var pts := [Vector2(-1.02, -0.08), Vector2(-1.13, -0.3), Vector2(-1.1, -0.42), Vector2(-0.98, -0.47), Vector2(-0.82, -0.44)]
	for k in pts.size():
		rim.append(pts[k])
	for k in range(pts.size() - 1, -1, -1):
		var p: Vector2 = pts[k]
		var c := Vector2(-0.92, -0.25)
		rim.append(p + (c - p).normalized() * 0.035)
	_extrude(blade, rim, 0.05, edge)


func _extrude(parent: Node3D, poly: PackedVector2Array, thick: float, mat: Material) -> void:
	var tris := Geometry2D.triangulate_polygon(poly)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx in [1.0, -1.0]:
		st.set_normal(Vector3(sx, 0, 0))
		var order := [0, 1, 2] if sx > 0 else [0, 2, 1]
		for t in range(0, tris.size(), 3):
			for o in order:
				var p := poly[tris[t + o]]
				st.add_vertex(Vector3(thick * 0.5 * sx, p.y, p.x))
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		var n := Vector3(0, -(b.x - a.x), b.y - a.y).normalized()
		st.set_normal(n)
		for v in [Vector3(thick * 0.5, a.y, a.x), Vector3(-thick * 0.5, a.y, a.x), Vector3(-thick * 0.5, b.y, b.x),
				Vector3(thick * 0.5, a.y, a.x), Vector3(-thick * 0.5, b.y, b.x), Vector3(thick * 0.5, b.y, b.x)]:
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)


# ============================================================ input / update

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := MOUSE_SENS * Settings.sensitivity * (0.55 if aiming else 1.0)
		yaw -= event.relative.x * sens
		var dy: float = event.relative.y * (-1.0 if Settings.invert_y else 1.0)
		pitch = clampf(pitch - dy * sens, -1.25, 0.7)
	if event.is_action_pressed("dodge") and recover_t <= 0.0 and not swim.swimming:
		_dodge()
	if event.is_action_pressed("reload"):
		_start_reload()
	if event.is_action_pressed("melee") and not swim.swimming:
		if weapon == "gun" and is_on_floor():
			rifle_bash()
		else:
			melee()
	if event.is_action_pressed("weapon_gun"):
		set_weapon("gun")
	if event.is_action_pressed("weapon_axe"):
		set_weapon("axe")
	for k in 3:
		if event.is_action_pressed("use_%d" % (k + 1)):
			use_slot(k)
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if dead:
		velocity.y -= GRAVITY * delta
		velocity.x = move_toward(velocity.x, 0, 20 * delta)
		velocity.z = move_toward(velocity.z, 0, 20 * delta)
		move_and_slide()
		return
	fire_cd -= delta
	xp_streak_t -= delta
	dancer_t -= delta
	dodge_cd -= delta
	ward_cd -= delta
	_tick_buffs(delta)
	ward_t -= delta
	melee_cd -= delta
	invuln -= delta
	last_shot_t += delta
	last_hurt_t += delta
	combo_reset_t -= delta
	overclock_t -= delta
	if frenzy > 0:
		frenzy_t -= delta
		if frenzy_t <= 0.0:
			frenzy = 0
	if shield > 0.0:
		shield_t -= delta
		if shield_t <= 0.0:
			shield = 0.0
			health_changed.emit(hp, stats.max_hp, shield)
	if stats.regen > 0.0 and last_hurt_t > 3.0 and hp < stats.max_hp:
		heal(stats.regen * delta)
	if reloading:
		reload_t -= delta
		if reload_t <= 0.0:
			reloading = false
			var take := mini(stats.mag - ammo, reserve)
			ammo += take
			reserve -= take
			ammo_changed.emit(ammo, stats.mag, reserve, false)

	var input_dir := Vector2.ZERO
	if input_enabled:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if force_move != Vector2.ZERO:
		input_dir = force_move
	aiming = ((input_enabled and Input.is_action_pressed("aim")) or force_aim) and swing_t <= 0.0 and weapon == "gun"
	var move := Basis(Vector3.UP, yaw) * Vector3(input_dir.x, 0, input_dir.y)
	var sprinting := input_enabled and Input.is_action_pressed("sprint") and not aiming and input_dir.length() > 0.1
	if swim.physics(delta, move, sprinting):
		return
	var speed: float = stats.move_speed * (stats.sprint_mult if sprinting else 1.0) * (0.6 if aiming else 1.0) * (1.0 + 0.1 * frenzy) * buff_val("speed")

	if recover_t > 0.0:
		recover_t -= delta
		land_t = maxf(land_t, 0.9)
		velocity.x = move_toward(velocity.x, 0.0, 60.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 60.0 * delta)
	elif dodge_t > 0.0:
		dodge_t -= delta
		var ra := 1.0 - dodge_t / roll_dur
		# Same ~5.4 m as before, spread over a slower roll that ends in a slide.
		var rs := 8.4 * (1.3 - 1.0 * ra)
		# Never drop below your running pace if you're still holding a direction.
		if input_dir.length() > 0.1:
			var run_pace: float = stats.move_speed * (stats.sprint_mult if Input.is_action_pressed("sprint") else 1.0) * buff_val("speed")
			rs = maxf(rs, run_pace)
		velocity.x = dodge_dir.x * rs
		velocity.z = dodge_dir.z * rs
		if ra > 0.7 and randf() < 0.5:
			Fx.impact(global_position + Vector3(0, 0.08, 0), Vector3.UP, false)
		if stats.blade_dash:
			_blade_dash_hits()
	elif swing_t <= 0.0 or not is_on_floor():
		var target := move * speed
		knock_t -= delta
		var accel := (14.0 if is_on_floor() else 4.0) * (0.15 if knock_t > 0.0 else 1.0)
		velocity.x = lerpf(velocity.x, target.x, 1.0 - exp(-accel * delta))
		velocity.z = lerpf(velocity.z, target.z, 1.0 - exp(-accel * delta))
	else:
		velocity.x = lerpf(velocity.x, move.x * speed * 0.4, 1.0 - exp(-6.0 * delta))
		velocity.z = lerpf(velocity.z, move.z * speed * 0.4, 1.0 - exp(-6.0 * delta))

	if slamming:
		velocity = Vector3(0, -32.0, 0)
	if is_on_floor():
		air_jumps_left = stats.air_jumps
		if slamming:
			_slam_impact()
	else:
		velocity.y -= GRAVITY * delta
	if input_enabled and Input.is_action_just_pressed("jump") and not slamming and recover_t <= 0.0:
		if is_on_floor():
			velocity.y = stats.jump
			Sfx.play("jump", null, -9.0, 1.0, 0.06)
		elif air_jumps_left > 0:
			air_jumps_left -= 1
			velocity.y = stats.jump * 0.95
			Fx.ring(global_position, Color(1.0, 0.45, 0.35), 1.2)
			Sfx.play("air_jump", null, -8.0, 1.0, 0.06)
	var fall_speed := -velocity.y
	move_and_slide()
	if is_on_floor():
		if not was_on_floor and air_t > 0.25:
			land_t = clampf(fall_speed / 12.0, 0.4, 1.0)
			Sfx.play("land", null, -9.0 + land_t * 5.0, 1.0, 0.06)
			if fall_speed > 9.0:
				Fx.impact(global_position + Vector3(0, 0.05, 0), Vector3.UP, false)
		air_t = 0.0
	else:
		air_t += delta
	was_on_floor = is_on_floor()

	var want_fire := ((input_enabled and Input.is_action_pressed("fire")) or force_fire) and recover_t <= 0.0 and bash_t <= 0.0
	if want_fire:
		var oc := overclock_t > 0.0 or buff_time("infinite_ammo") > 0.0
		if weapon == "axe":
			melee()
		elif ammo <= 0 and reserve <= 0 and not oc:
			set_weapon("axe")
			if Game.hud:
				Game.hud.toast("Out of ammo  ·  axe drawn", Color(1.0, 0.5, 0.35))
		elif swing_t <= 0.0:
			_try_fire()

	bash_shot_t -= delta
	if bash_t > 0.0:
		bash_t -= delta
		if 1.0 - bash_t / bash_dur >= 0.42 and not bash_hit_done:
			_bash_hit()
	if swing_t > 0.0:
		swing_t -= delta
		var phase := 1.0 - swing_t / swing_dur
		if phase >= 0.42 and not whoosh_played:
			whoosh_played = true
			Sfx.play("swing", null, -2.0, 0.85 if combo == 2 else 1.0, 0.08)
		if phase >= 0.56 and not swing_hit_done:
			_melee_hit()

	# Facing: toward the camera while fighting, else toward movement.
	if aiming or last_shot_t < 0.8 or swing_t > 0.0:
		face_yaw = lerp_angle(face_yaw, yaw, 1.0 - exp(-20.0 * delta))
	elif move.length() > 0.1:
		face_yaw = lerp_angle(face_yaw, atan2(-move.x, -move.z), 1.0 - exp(-10.0 * delta))
	visual.rotation.y = face_yaw
	_roll_pose()

	_update_anim()
	if global_position.y < -40.0:
		take_damage(9999)


func _process(delta: float) -> void:
	recoil = lerpf(recoil, 0.0, 1.0 - exp(-12.0 * delta))
	cam_pivot.rotation.y = yaw
	cam_pitch.rotation.x = pitch + recoil
	var t := 1.0 - exp(-12.0 * delta)
	spring.spring_length = lerpf(spring.spring_length, 1.7 if aiming else 3.6, t)
	spring.position.x = lerpf(spring.position.x, 0.7 if aiming else 0.55, t)
	var fov_target := 52.0 if aiming else (78.0 if dodge_t > 0.0 or slamming else 70.0)
	cam.fov = lerpf(cam.fov, fov_target, t)
	_update_pose(delta)
	shake = maxf(shake - delta * 2.5, 0.0)
	var s := shake * shake
	cam.h_offset = randf_range(-1, 1) * s * 0.3
	cam.v_offset = randf_range(-1, 1) * s * 0.3


func _update_pose(delta: float) -> void:
	var shouldered := aiming or last_shot_t < 0.8
	aim_mod.aim_blend = move_toward(aim_mod.aim_blend, 1.0 if shouldered else 0.0, delta * 7.0)
	aim_mod.aim_point = cam.global_position - cam.global_basis.z * 60.0
	aim_mod.face_yaw = face_yaw
	var swinging := swing_t > 0.0 or slamming
	var axe_out := swinging or weapon == "axe"
	aim_mod.swing = 1.0 if axe_out else 0.0
	aim_mod.swing_phase = 0.15 if slamming else (clampf(1.0 - swing_t / swing_dur, 0.0, 1.0) if swinging else 0.0)
	aim_mod.swing_side = swing_side
	blade.visible = axe_out
	gun.visible = not axe_out
	aim_mod.influence = 1.0
	flinch = maxf(flinch - delta * 4.0, 0.0)
	aim_mod.flinch = sin(flinch * PI) * flinch
	aim_mod.recoil = maxf(aim_mod.recoil - delta * 14.0, 0.0)
	var roll_a := 1.0 - dodge_t / roll_dur if dodge_t > 0.0 else 1.0
	var tucking := air_t > 0.08 or (dodge_t > 0.0 and roll_a < 0.68)
	if dodge_t > 0.0 and roll_a >= 0.68:
		land_t = maxf(land_t, 0.45)
	aim_mod.air = move_toward(aim_mod.air, 1.0 if tucking else 0.0, delta * (14.0 if dodge_t > 0.0 else (6.0 if air_t > 0.08 else 12.0)))
	aim_mod.rise = clampf(velocity.y / 8.0, -1.0, 1.0)
	land_t = maxf(land_t - delta * 4.0, 0.0)
	aim_mod.land = sin(minf(land_t, 1.0) * PI * 0.5)
	var bp := 1.0 - bash_t / bash_dur if bash_t > 0.0 else 1.0
	aim_mod.bash = sin(clampf(bp / 0.45, 0.0, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.5, 1.0, bp)) if bash_t > 0.0 else 0.0
	_update_reload_visuals()


func _update_anim() -> void:
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var want := "Idle"
	var spd := 1.0
	if dodge_t > 0.0:
		want = "Run"
		spd = 2.2
	elif air_t > 0.08:
		want = "Idle"
		spd = 0.6
	elif hspeed > 5.6:
		want = "Run"
		spd = clampf(hspeed / 6.5, 0.8, 1.6)
	elif hspeed > 0.4:
		want = "Walk"
		spd = clampf(hspeed / 2.0, 0.7, 1.8)
	if want != cur_anim:
		anim.play(want, 0.2)
		cur_anim = want
	anim.speed_scale = spd


# ============================================================ movement abilities

func _dodge() -> void:
	if dodge_cd > 0.0 or dead:
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var d := Basis(Vector3.UP, yaw) * Vector3(input_dir.x, 0, input_dir.y)
	if d.length() < 0.1:
		d = Basis(Vector3.UP, yaw) * Vector3.FORWARD
	dodge_dir = d.normalized()
	dodge_t = roll_dur
	invuln = 0.6
	if stats.syn.has("ember_dancer"):
		dancer_t = roll_dur + 2.0
	Sfx.play("roll", null, -4.0, 1.0, 0.05)
	dodge_cd = roll_dur + stats.dodge_cd * 0.6
	dodge_hits.clear()
	face_yaw = atan2(-dodge_dir.x, -dodge_dir.z)
	Fx.impact(global_position + Vector3(0, 0.1, 0), Vector3.UP, false)
	if stats.aegis:
		shield = 40.0
		shield_t = 3.0
		health_changed.emit(hp, stats.max_hp, shield)


func _blade_dash_hits() -> void:
	for e in _enemies_near(global_position, 1.8):
		if e in dodge_hits:
			continue
		dodge_hits.append(e)
		var killed: bool = e.take_damage(stats.melee_damage, e.global_position + Vector3.UP, dodge_dir, false, 4.0)
		hit_enemy.emit(killed, false)
		if killed:
			_on_kill(true)


func _slam_impact() -> void:
	slamming = false
	var meteor: bool = stats.slam
	var r: float = (4.5 if meteor else 2.8) * stats.reach
	var dmg: float = stats.melee_damage * (1.9 if meteor else 1.45) * buff_val("strength")
	_aoe(global_position, r, dmg, 9.0, true)
	Fx.ring(global_position + Vector3(0, 0.15, 0), Color(1.0, 0.45, 0.2), r)
	Fx.combo_text(global_position + Vector3(0, 2.2, 0), "JUMP BASH", Color(1.0, 0.6, 0.3))
	var fx := preload("res://scripts/combat/slam_fx.gd").new()
	fx.max_radius = r
	fx.grow_speed = 16.0
	fx.damage = 0.0
	fx.hit = true
	Game.world.add_child(fx)
	fx.global_position = global_position
	Sfx.play("axe_finisher", global_position, 3.0, 0.9)
	shake = 1.0
	# The price: you're planted for a moment.
	recover_t = 0.3 if meteor else 0.5
	_hitstop(0.06)


# ============================================================ melee

func melee() -> void:
	if melee_cd > 0.0 or swing_t > 0.0 or dead or slamming or recover_t > 0.0 or bash_t > 0.0:
		return
	if not is_on_floor() and air_t > 0.12:
		# Jump bash: plunge into the ground. Meteor makes it bigger.
		slamming = true
		swing_side = 1.0
		return
	var spd: float = stats.attack_speed * (1.0 + 0.1 * frenzy)
	combo = (combo + 1) % 3 if combo_reset_t > 0.0 and stats.combo else 0
	swing_dur = (0.86 if combo == 2 else 0.6) / spd
	swing_t = swing_dur
	melee_cd = swing_dur * 0.9
	combo_reset_t = swing_dur + 0.55
	swing_side = 1.0 if combo % 2 == 0 else -1.0
	aim_mod.heavy = combo == 2
	swing_hit_done = false
	whoosh_played = false
	face_yaw = yaw
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	# Lunge toward the closest enemy in front.
	var lunge_range: float = 3.0 + 2.5 * stats.lunge
	var best: Node3D = null
	var best_d := lunge_range
	for e in _enemies_near(global_position, lunge_range):
		var to: Vector3 = e.global_position - global_position
		to.y = 0
		if to.length() < best_d and fwd.angle_to(to.normalized()) < 0.8:
			best_d = to.length()
			best = e
	lunged = false
	if best and stats.lunge > 0 and best_d > 1.4:
		lunged = true
		var dir := (best.global_position - global_position)
		dir.y = 0
		dir = dir.normalized()
		face_yaw = atan2(-dir.x, -dir.z)
		velocity.x = dir.x * (9.0 + 3.0 * stats.lunge)
		velocity.z = dir.z * (9.0 + 3.0 * stats.lunge)
	else:
		velocity.x += fwd.x * 3.0
		velocity.z += fwd.z * 3.0
	_slash_fx()
	if stats.bladestorm:
		_blade_wave()


func _melee_hit() -> void:
	swing_hit_done = true
	var heavy := combo == 2
	var reach: float = (2.9 if heavy else 2.7) * stats.reach
	var arc: float = deg_to_rad(40.0 if heavy else 70.0) * (1.0 + (stats.reach - 1.0) * 0.5)
	var fwd := Vector3(-sin(face_yaw), 0, -cos(face_yaw))
	var dmg: float = stats.melee_damage * (1.8 if heavy else 1.0) * buff_val("strength")
	var hits := 0
	for e in _enemies_near(global_position, reach + 0.6):
		var to: Vector3 = e.global_position - global_position
		to.y = 0
		var d := to.length()
		if d > 0.7 and fwd.angle_to(to / d) > arc:
			continue
		var crit := randf() < 0.1
		var at: Vector3 = e.global_position + Vector3(0, 1.1, 0)
		var killed: bool = e.take_damage(dmg * (2.0 if crit else 1.0), at, to.normalized(), crit, 16.0 if heavy else 10.0)
		Fx.axe_impact(at, -to.normalized(), heavy)
		if stats.syn.has("molten_edge") and e.has_method("ignite"):
			e.ignite(3.0, stats.melee_damage * 0.12)
		if stats.syn.has("hunters_mark") and lunged:
			e.set_meta("mark_until", Time.get_ticks_msec() + 4000)
			Fx.combo_text(at + Vector3(0, 0.9, 0), "MARKED", Color(1.0, 0.3, 0.3))
		if stats.syn.has("ironclad"):
			shield = minf(shield + 8.0, 40.0)
			shield_t = 4.0
			health_changed.emit(hp, stats.max_hp, shield)
		if stats.syn.has("gunblade") and not empowered:
			empowered = true
			Fx.combo_text(at + Vector3(0, 0.9, 0), "PRIMED", Color(1.0, 0.7, 0.2))
		Sfx.play("axe_finisher" if heavy else "axe_hit", at, 5.0 if heavy else 3.0, 1.0, 0.07)
		hit_enemy.emit(killed, crit)
		if stats.melee_heal > 0.0:
			heal(stats.melee_heal)
		if killed:
			_on_kill(true)
		hits += 1
	if heavy:
		# The finisher bites into the ground: rubble, dust, splash damage.
		var ground := global_position + fwd * 2.0
		ground.y = Game.sample_height(ground.x, ground.z)
		var fx := preload("res://scripts/combat/slam_fx.gd").new()
		fx.max_radius = 3.2
		fx.grow_speed = 14.0
		fx.damage = 0.0
		fx.hit = true
		Game.world.add_child(fx)
		fx.global_position = ground
		Sfx.play("explosion", ground, -4.0, 0.8, 0.05)
		_aoe(ground, 2.8, stats.melee_damage * 0.6, 9.0, true)
		shake = 1.1
	if hits > 0:
		shake = maxf(shake, 0.85 if heavy else 0.65)
		cam.fov += 9.0 if heavy else 6.0
		_hitstop(0.14 if heavy else 0.09)
	elif heavy:
		_hitstop(0.06)


func _blade_wave() -> void:
	var w := preload("res://scripts/combat/blade_wave.gd").new()
	w.damage = stats.melee_damage * 0.7
	w.dir = Vector3(-sin(yaw), 0, -cos(yaw))
	w.side = swing_side
	Game.world.add_child(w)
	w.global_position = global_position + Vector3(0, 1.1, 0) + w.dir * 0.8


func _slash_fx() -> void:
	if _slash_mesh == null:
		_slash_mesh = make_arc_mesh(0.7, 2.5, deg_to_rad(150.0))
	var mi := MeshInstance3D.new()
	mi.mesh = _slash_mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(2.4, 0.9, 0.3, 1.0) if combo < 2 else Color(3.0, 0.7, 0.25, 1.0)
	mi.material_override = mat
	Game.world.add_child(mi)
	var r: float = stats.reach
	mi.global_position = global_position + Vector3(0, 1.15, 0)
	var tilt := PI * 0.5 if combo == 2 else 0.55 * swing_side
	mi.global_basis = Basis(Vector3.UP, face_yaw) * Basis(Vector3.FORWARD, tilt) * Basis.from_scale(Vector3(swing_side * r, 1, r) * 1.1)
	mi.visible = false
	var tw := mi.create_tween()
	# Trail appears as the axe comes down, not during the wind-up.
	tw.tween_interval(swing_dur * 0.46)
	tw.tween_callback(func(): mi.visible = true)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.tween_callback(mi.queue_free)


## Flat arc ribbon in the XZ plane facing -Z; vertex alpha peaks just inside
## the outer edge (soft rim, no hard border) and fades along the trailing side.
## Used for slash trails and blade waves.
static func make_arc_mesh(inner: float, outer: float, sweep: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 32
	var radii := [inner, lerpf(inner, outer, 0.55), lerpf(inner, outer, 0.86), outer]
	var weight := [0.0, 0.45, 1.0, 0.0]
	for i in segs:
		var a0 := -sweep * 0.5 + sweep * i / segs
		var a1 := -sweep * 0.5 + sweep * (i + 1) / segs
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		for band in 3:
			var pts := [
				[Vector3(sin(a0), 0, -cos(a0)) * radii[band], t0, weight[band]],
				[Vector3(sin(a0), 0, -cos(a0)) * radii[band + 1], t0, weight[band + 1]],
				[Vector3(sin(a1), 0, -cos(a1)) * radii[band + 1], t1, weight[band + 1]],
				[Vector3(sin(a1), 0, -cos(a1)) * radii[band], t1, weight[band]],
			]
			for k in [0, 1, 2, 0, 2, 3]:
				var lead: float = pts[k][1]
				var edge: float = pts[k][2]
				var a := edge * (1.0 - pow(lead, 2.2)) * smoothstep(0.0, 0.2, lead + 0.05) * 0.85
				st.set_color(Color(1, 1, 1, a))
				st.add_vertex(pts[k][0])
	return st.commit()


func _hitstop(t: float) -> void:
	Engine.time_scale = 0.05
	get_tree().create_timer(t, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func _enemies_near(pos: Vector3, r: float) -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.state != "dead" and e.global_position.distance_to(pos) <= r:
			out.append(e)
	return out


func _aoe(pos: Vector3, r: float, dmg: float, knock: float, melee_kill: bool) -> void:
	for e in _enemies_near(pos, r):
		var to: Vector3 = e.global_position - pos
		to.y = 0.4
		var killed: bool = e.take_damage(dmg, e.global_position + Vector3(0, 1.2, 0), to.normalized(), false, knock)
		hit_enemy.emit(killed, false)
		if killed:
			_on_kill(melee_kill)


func _on_kill(by_melee: bool) -> void:
	kills += 1
	if by_melee and stats.frenzy:
		frenzy = mini(frenzy + 1, 5)
		frenzy_t = 4.0
	if not by_melee and stats.overclock:
		overclock_t = 3.0


# ============================================================ gun

func _start_reload() -> void:
	if reloading or ammo == stats.mag or reserve <= 0:
		return
	reloading = true
	reload_t = stats.reload_time
	# One recorded reload, stretched to match a faster (Quick Hands) reload.
	Sfx.play("reload", null, -2.0, clampf(1.6 / stats.reload_time, 0.9, 1.7), 0.0)
	ammo_changed.emit(ammo, stats.mag, reserve, true)


func add_ammo(n: int) -> void:
	reserve = mini(reserve + n, stats.max_reserve)
	ammo_changed.emit(ammo, stats.mag, reserve, reloading)
	if ammo == 0:
		_start_reload()


func _try_fire() -> void:
	var oc := overclock_t > 0.0 or buff_time("infinite_ammo") > 0.0
	if (reloading and not oc) or fire_cd > 0.0 or dodge_t > 0.0:
		return
	if ammo <= 0 and not oc:
		_start_reload()
		return
	fire_cd = 1.0 / (stats.fire_rate * (1.6 if oc else 1.0) * (1.4 if dancer_t > 0.0 else 1.0))
	if not oc:
		ammo -= 1
	last_shot_t = 0.0
	shot_count += 1
	ammo_changed.emit(ammo, stats.mag, reserve, reloading)
	if ammo == 0 and not oc:
		_start_reload()

	var spread := 0.004 if aiming else 0.018
	var dmg_mult := 1.6 if (aiming and stats.deadeye) else 1.0
	var boom := empowered
	empowered = false
	var landed := _fire_ray(spread, dmg_mult, boom)
	if stats.hot_streak:
		streak = streak + 1 if landed else 0
		if boom:
			streak = 0
		elif streak >= 4:
			empowered = true
			streak = 0
	Sfx.play("rifle", null, -3.0, 1.0, 0.05)
	if stats.lead_storm and shot_count % 6 == 0:
		for i in 4:
			_fire_ray(0.05, 0.8)
	Fx.muzzle_flash(muzzle)
	aim_mod.recoil = 1.0
	recoil += 0.012 if aiming else 0.02
	shake = minf(shake + 0.12, 0.5)
	fired.emit()


func _fire_ray(spread: float, dmg_mult: float, explosive := false) -> bool:
	var landed := false
	var from := cam.global_position
	var dir := (-cam.global_basis.z + cam.global_basis.x * randf_range(-spread, spread) + cam.global_basis.y * randf_range(-spread, spread)).normalized()
	var to := from + dir * 300.0
	var hit_point := to
	var exclude: Array[RID] = [get_rid()]
	var pierce_left: int = stats.pierce
	var space := get_world_3d().direct_space_state
	var hit_any := false
	for i in 8:
		var q := PhysicsRayQueryParameters3D.create(from, to, Game.L_WORLD | Game.L_ENEMY, exclude)
		var r := space.intersect_ray(q)
		if r.is_empty():
			break
		hit_point = r.position
		hit_any = true
		var col: Object = r.collider
		if col.has_method("take_damage"):
			var crit: bool = randf() < stats.crit_chance or bash_shot_t > 0.0
			if bash_shot_t > 0.0:
				bash_shot_t = 0.0
				Fx.combo_text(r.position + Vector3(0, 0.6, 0), "BASH SHOT", Color(1.0, 0.85, 0.3))
			var dmg: float = stats.gun_damage * dmg_mult * (stats.crit_mult if crit else 1.0)
			if (col as Node).has_meta("mark_until") and Time.get_ticks_msec() < int((col as Node).get_meta("mark_until")):
				dmg *= 1.5
			var killed: bool = col.take_damage(dmg, r.position, dir, crit, 2.5)
			landed = true
			Sfx.play("axe_hit", r.position, -10.0, 1.5, 0.1)
			Fx.impact(r.position, r.normal, true)
			hit_enemy.emit(killed, crit)
			if killed:
				_on_kill(false)
			if pierce_left > 0:
				pierce_left -= 1
				exclude.append(col.get_rid())
				from = r.position
				continue
		else:
			Fx.impact(r.position, r.normal, false)
			Sfx.play("bullet_miss", r.position, -6.0, 1.0, 0.1)
		break
	if hit_any and explosive:
		# Hot Streak round: a big ember blast.
		Fx.explosion(hit_point)
		Fx.ring(hit_point, Color(1.0, 0.6, 0.2), 4.0)
		_aoe(hit_point, 4.0, stats.gun_damage * 5.0, 10.0, false)
		shake = maxf(shake, 0.5)
	elif hit_any and randf() < stats.explode_chance:
		Fx.explosion(hit_point)
		_aoe(hit_point, 2.8, stats.gun_damage * 1.5, 6.0, false)
	Fx.tracer(muzzle.global_position, hit_point)
	return landed


# ============================================================ health / xp

func take_damage(amount: float, source: Node = null, kb := Vector3.ZERO) -> void:
	if invuln > 0.0 or dead:
		return
	# Get knocked back and flinch so hits read clearly.
	velocity += kb
	if kb.length() > 3.0:
		knock_t = 0.4
	flinch = 1.0
	if source and is_instance_valid(source) and Game.hud:
		Game.hud.damage_from(source.global_position)
	if kb.length() > 14.0:
		_hitstop(0.11)
	elif kb.length() > 9.0:
		_hitstop(0.06)
	amount *= 1.0 - minf(stats.armor, 0.6)
	amount *= buff_val("stoneskin")
	if ward_t > 0.0:
		amount *= 0.6
	if stats.ember_ward and ward_cd <= 0.0:
		# Ember Ward: a fire pulse hurls attackers back.
		ward_cd = 6.0
		ward_t = 2.0
		Fx.ring(global_position + Vector3(0, 0.3, 0), Color(1.0, 0.55, 0.2), 5.0)
		Fx.explosion(global_position + Vector3(0, 1.0, 0))
		_aoe(global_position, 5.0, 30.0, 14.0, false)
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
	hp -= amount
	last_hurt_t = 0.0
	var tough := toughness()
	var sting := clampf(amount / stats.max_hp * 3.5 + 0.25, 0.0, 1.0) * tough
	shake = maxf(shake, 0.35 + 0.75 * tough)
	flinch = 0.4 + 0.6 * tough
	if Game.hud:
		Game.hud.hurt_pulse(sting)
	Sfx.play("hurt", null, -11.0 + sting * 5.0, 1.0, 0.08)
	invuln = 0.15
	if source and is_instance_valid(source) and stats.thorns > 0.0 and source.has_method("take_damage"):
		var d: Vector3 = (source.global_position - global_position).normalized()
		source.take_damage(stats.thorns, source.global_position + Vector3(0, 1.2, 0), d, false, 3.0)
	if hp <= 0.0:
		if stats.phoenix and not phoenix_used:
			phoenix_used = true
			hp = stats.max_hp * 0.5
			invuln = 2.0
			Fx.explosion(global_position + Vector3(0, 1, 0))
			Fx.ring(global_position + Vector3(0, 0.2, 0), Color(1.0, 0.6, 0.2), 7.0)
			_aoe(global_position, 7.0, 120.0, 12.0, false)
			Game.hud.show_banner("PHOENIX  —  REBORN")
		else:
			hp = 0.0
			dead = true
			anim.pause()
			aim_mod.influence = 0.0
			Sfx.play("player_death", null, -4.0, 1.0, 0.0)
			# Knees give, then a heavy forward topple and a small settle.
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(visual, "position:y", -0.28, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(visual, "rotation:x", -0.3, 0.28).set_trans(Tween.TRANS_SINE)
			tw.chain().tween_property(visual, "rotation:x", -PI * 0.5 + 0.06, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(visual, "position:y", -0.05, 0.42)
			tw.chain().tween_property(visual, "rotation:x", -PI * 0.5 + 0.1, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.chain().tween_property(visual, "rotation:x", -PI * 0.5 + 0.06, 0.18).set_trans(Tween.TRANS_SINE)
			died.emit()
	health_changed.emit(hp, stats.max_hp, shield)


func heal(amount: float) -> void:
	hp = minf(hp + amount, stats.max_hp)
	health_changed.emit(hp, stats.max_hp, shield)


func add_xp(v: float) -> void:
	# Consecutive embers climb in pitch.
	xp_streak = xp_streak + 1 if xp_streak_t > 0.0 else 0
	xp_streak_t = 0.6
	Sfx.play("xp", null, -10.0, 1.0 + minf(xp_streak, 10) * 0.04, 0.02)
	xp += v
	while xp >= xp_need:
		xp -= xp_need
		level += 1
		xp_need = roundf(xp_need * 1.3 + 10.0)
		recalc()
		heal(15.0)
		Sfx.play("levelup", null, -2.0, 1.0, 0.0)
		leveled_up.emit()
	xp_changed.emit(xp, xp_need, level)


func _update_heat_glow() -> void:
	if gun_trim_mat == null:
		return
	if empowered:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
		gun_trim_mat.emission_energy_multiplier = 10.0 + pulse * 8.0
	elif gun_trim_mat.emission_energy_multiplier > 3.0 + SkillTree.branch_points(ranks, "gun") * 1.6 + 0.5:
		gun_trim_mat.emission_energy_multiplier = lerpf(gun_trim_mat.emission_energy_multiplier, 3.0 + SkillTree.branch_points(ranks, "gun") * 1.6, 0.2)


func _update_reload_visuals() -> void:
	if not reloading:
		aim_mod.reload_phase = -1.0
		mag_node.visible = true
		hand_mag.visible = false
		mag_dropped = false
		return
	var r := clampf(1.0 - reload_t / stats.reload_time, 0.0, 1.0)
	aim_mod.reload_phase = r
	if r >= 0.16 and not mag_dropped:
		mag_dropped = true
		_drop_mag()

	mag_node.visible = r < 0.16 or r > 0.78
	hand_mag.visible = r > 0.44 and r <= 0.78
	if hand_mag.visible:
		hand_mag.global_transform = Transform3D(gun.global_basis, aim_mod.mag_hand_pos)


## The spent magazine falls out and clatters on the ground.
func _drop_mag() -> void:
	var rb := RigidBody3D.new()
	rb.collision_layer = 0
	rb.collision_mask = Game.L_WORLD
	rb.mass = 0.4
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.04, 0.12, 0.05)
	cs.shape = sh
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = hand_mag.mesh
	rb.add_child(mi)
	Game.world.add_child(rb)
	rb.global_transform = mag_node.global_transform
	rb.linear_velocity = velocity * 0.6 - gun.global_basis.y * 1.5 + gun.global_basis.x * 0.4
	rb.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	get_tree().create_timer(0.42).timeout.connect(func(): if is_instance_valid(rb): Sfx.play("mag_drop", rb.global_position, -9.0, 1.0, 0.08))
	get_tree().create_timer(9.0).timeout.connect(rb.queue_free)


## 1.0 = fragile; lower as armor, max health and wards stack up. Scales how
## hard pain hits the screen so tougher builds feel tougher.
func toughness() -> float:
	var t: float = stats.armor * 1.6 + (stats.max_hp - 100.0) / 320.0
	if ward_t > 0.0:
		t += 0.25
	if shield > 0.0:
		t += 0.15
	if buff_time("stoneskin") > 0.0:
		t += 0.3
	return 1.0 - clampf(t, 0.0, 0.65)


# ============================================================ consumables & weapons

func buff_time(n: String) -> float:
	return buffs[n][0] if buffs.has(n) else 0.0


func buff_val(n: String, default := 1.0) -> float:
	return buffs[n][1] if buffs.has(n) else default


func give_item(id: String) -> bool:
	if inventory.size() >= 3:
		return false
	inventory.append(id)
	inventory_changed.emit()
	return true


func use_slot(i: int) -> void:
	if dead or i >= inventory.size():
		return
	var id: String = inventory[i]
	inventory.remove_at(i)
	var it := Consumables.info(id)
	if it.has("heal"):
		heal(it.heal)
	if it.has("buff"):
		buffs[it.buff] = [it.time, it.value]
	var col: Color = it.color
	Sfx.play("potion_use", null, -2.0)
	Fx.ring(global_position + Vector3(0, 0.2, 0), col, 2.5)
	Fx.death_burst(global_position + Vector3(0, 1.2, 0), col)
	if Game.hud:
		Game.hud.toast(it.name + "  ·  " + it.desc, Consumables.RARITY_COLORS[it.rarity])
	inventory_changed.emit()
	if it.get("buff", "") == "infinite_ammo" and reloading:
		reloading = false
		ammo = stats.mag
		ammo_changed.emit(ammo, stats.mag, reserve, false)


func _tick_buffs(delta: float) -> void:
	for n in buffs.keys():
		buffs[n][0] -= delta
		if buffs[n][0] <= 0.0:
			buffs.erase(n)
	if buffs.has("regen"):
		heal(buffs.regen[1] * delta)


func set_weapon(w: String) -> void:
	if w == weapon or dead:
		return
	weapon = w
	if w == "axe":
		Sfx.play("draw", null, -4.0)
	else:
		Sfx.play("draw", null, -12.0, 1.6, 0.05)
	if w == "axe":
		reloading = false
		ammo_changed.emit(ammo, stats.mag, reserve, false)
	weapon_changed.emit(w)


## Combat somersault: a full forward tuck over the first ~70% of the roll,
## then a crouched slide as you come up.
func _roll_pose() -> void:
	visual.position = Vector3.ZERO
	if dodge_t <= 0.0:
		return
	var a := clampf(1.0 - dodge_t / roll_dur, 0.0, 1.0)
	var spin := smoothstep(0.0, 0.72, a) * TAU
	var right := Vector3(cos(face_yaw), 0, -sin(face_yaw))
	var pivot := Vector3(0, 0.62, 0)
	var r := Basis(right, -spin)
	var basis := r * Basis(Vector3.UP, face_yaw)
	var sink := sin(clampf(a / 0.72, 0.0, 1.0) * PI) * 0.35 + smoothstep(0.65, 0.8, a) * (1.0 - smoothstep(0.85, 1.0, a)) * 0.12
	visual.transform = Transform3D(basis, pivot - r * pivot - Vector3(0, sink, 0))


# ============================================================ rifle bash

func rifle_bash() -> void:
	if bash_t > 0.0 or melee_cd > 0.0 or dead or recover_t > 0.0 or dodge_t > 0.0:
		return
	bash_t = bash_dur
	bash_hit_done = false
	melee_cd = bash_dur * 1.1
	face_yaw = yaw
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	velocity.x += fwd.x * 4.0
	velocity.z += fwd.z * 4.0
	Sfx.play("swing", null, -6.0, 1.35, 0.06)


func _bash_hit() -> void:
	bash_hit_done = true
	var fwd := Vector3(-sin(face_yaw), 0, -cos(face_yaw))
	var point_blank := last_shot_t < 0.6
	var dmg: float = stats.gun_damage * 2.2 * (1.6 if point_blank else 1.0)
	var hits := 0
	for e in _enemies_near(global_position, 2.6):
		var to: Vector3 = e.global_position - global_position
		to.y = 0
		if to.length() > 0.7 and fwd.angle_to(to.normalized()) > 1.0:
			continue
		var at: Vector3 = e.global_position + Vector3(0, 1.1, 0)
		var killed: bool = e.take_damage(dmg, at, to.normalized(), point_blank, 9.0)
		Fx.impact(at, -to.normalized(), true)
		Sfx.play("axe_hit", at, -2.0, 1.25, 0.06)
		hit_enemy.emit(killed, point_blank)
		if killed:
			_on_kill(true)
		hits += 1
		if point_blank and hits == 1:
			Fx.combo_text(at + Vector3(0, 0.8, 0), "POINT BLANK", Color(1.0, 0.55, 0.25))
	if hits > 0:
		bash_shot_t = 0.9
		shake = maxf(shake, 0.55)
		_hitstop(0.06)


# ============================================================ boon visuals

## Weapons and body change with your build.
func update_weapon_look() -> void:
	var gp := SkillTree.branch_points(ranks, "gun")
	var bp := SkillTree.branch_points(ranks, "blade")
	var wp := SkillTree.branch_points(ranks, "ward")
	gun_trim_mat.emission = Color(1.0, 0.45, 0.1).lerp(Color(1.0, 0.85, 0.45), clampf(gp / 5.0, 0.0, 1.0))
	gun_trim_mat.emission_energy_multiplier = 3.0 + gp * 1.6
	if gp >= 2 and gun_runes == null:
		gun_runes = Node3D.new()
		gun.add_child(gun_runes)
		for sx in [-1.0, 1.0]:
			for k in 4:
				var rm := BoxMesh.new()
				rm.size = Vector3(0.004, 0.02, 0.03)
				rm.material = gun_trim_mat
				var mi := MeshInstance3D.new()
				mi.mesh = rm
				mi.position = Vector3(0.031 * sx, 0.04, -0.05 - k * 0.06)
				gun_runes.add_child(mi)
	if SkillTree.has_mastery(ranks, "gun") and gun_flame == null:
		gun_flame = _flame(muzzle, 0.03, 18, Color(1.0, 0.5, 0.15))
	axe_edge_mat.emission_energy_multiplier = 4.0 + bp * 2.0
	blade.scale = Vector3.ONE * (1.0 + 0.06 * bp)
	if SkillTree.has_mastery(ranks, "blade") and axe_flame == null:
		var at := Node3D.new()
		at.position = Vector3(0, -0.25, -0.95)
		blade.add_child(at)
		axe_flame = _flame(at, 0.18, 40, Color(1.0, 0.45, 0.1))
	if axe_flame and stats.bladestorm:
		axe_flame.amount = 70
		(axe_flame.process_material as ParticleProcessMaterial).emission_sphere_radius = 0.26
	if wp >= 2 and ward_aura == null:
		var feet := Node3D.new()
		add_child(feet)
		ward_aura = _flame(feet, 0.6, 30, Color(0.4, 0.9, 0.85))
		(ward_aura.process_material as ParticleProcessMaterial).emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		(ward_aura.process_material as ParticleProcessMaterial).emission_ring_radius = 0.6
		(ward_aura.process_material as ParticleProcessMaterial).emission_ring_inner_radius = 0.5
		(ward_aura.process_material as ParticleProcessMaterial).emission_ring_height = 0.05
		(ward_aura.process_material as ParticleProcessMaterial).emission_ring_axis = Vector3.UP
	if ward_aura and SkillTree.has_mastery(ranks, "ward"):
		ward_aura.amount = 60


func _flame(parent: Node3D, radius: float, amount: int, col: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.7
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius
	pm.direction = Vector3.UP
	pm.spread = 15.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3(0, 1.8, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var c := Curve.new()
	c.add_point(Vector2(0, 0.5))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	var g := Gradient.new()
	g.set_color(0, Color(col.r * 3.0, col.g * 3.0, col.b * 3.0, 1))
	g.set_color(1, Color(col.r, col.g * 0.4, col.b * 0.3, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = WorldBuilder._soft_dot()
	q.material = qm
	p.draw_pass_1 = q
	parent.add_child(p)
	return p


## The moment a boon becomes yours: a column of embers in the path's
## colour, a slow-motion beat and the weapon flaring.
func celebrate_boon(id: String) -> void:
	var n := SkillTree.find(id)
	if n.is_empty() or Game.shot_mode and not is_inside_tree():
		return
	var col: Color = SkillTree.BRANCHES[n.branch].color
	var beam := CylinderMesh.new()
	beam.top_radius = 0.08
	beam.bottom_radius = 0.55
	beam.height = 9.0
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/fx/light_beam.gdshader")
	m.set_shader_parameter("color", Color(col.r, col.g, col.b))
	m.set_shader_parameter("alpha", 0.0)
	beam.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = beam
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.world.add_child(mi)
	mi.global_position = global_position + Vector3(0, 4.5, 0)
	mi.scale = Vector3(0.3, 0.2, 0.3)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "shader_parameter/alpha", 0.26, 0.2)
	tw.chain().tween_property(m, "shader_parameter/alpha", 0.0, 0.7)
	tw.chain().tween_callback(mi.queue_free)
	Fx.ring(global_position + Vector3(0, 0.15, 0), col, 5.0)
	Fx.death_burst(global_position + Vector3(0, 1.2, 0), col)
	Fx.combo_text(global_position + Vector3(0, 2.6, 0), String(n.name).to_upper(), col.lightened(0.3))
	shake = maxf(shake, 0.4)
	cam.fov -= 8.0
	var flash_mat: StandardMaterial3D = axe_edge_mat if n.branch == "blade" else gun_trim_mat
	var base_e := flash_mat.emission_energy_multiplier
	var ft := create_tween()
	ft.tween_property(flash_mat, "emission_energy_multiplier", base_e + 14.0, 0.15)
	ft.tween_property(flash_mat, "emission_energy_multiplier", base_e, 0.8)
	Engine.time_scale = 0.35
	get_tree().create_timer(0.45, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
