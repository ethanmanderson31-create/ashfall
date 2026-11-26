extends Node3D
## Boots Act I: builds the world, then directs the act: a route of ambush
## sites marked by an ember beacon, escalating from 2 creatures to mixed
## packs with elites and second waves, ending in the Colossus arena.

const PlayerScript := preload("res://scripts/player/player.gd")
const EnemyScript := preload("res://scripts/enemies/enemy.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const LoadingScript := preload("res://scripts/ui/loading_screen.gd")
const BossScript := preload("res://scripts/enemies/boss_colossus.gd")
const AmbienceScript := preload("res://scripts/world/ambience.gd")

## Encounters along the route: [kind, elite]. Later sites send a second wave.
const ENCOUNTERS := [
	[["ghoul", false], ["ghoul", false]],
	[["ghoul", false], ["ghoul", false], ["hound", false]],
	[["ghoul", false], ["hound", false], ["ghoul", false], ["hound", false]],
	[["ghoul", false], ["ghoul", false], ["hound", false], ["ghoul", true]],
	[["hound", false], ["hound", false], ["ghoul", false], ["ghoul", false], ["hound", true]],
]
const SECOND_WAVES := {
	2: [["ghoul", false], ["ghoul", false]],
	3: [["hound", false], ["ghoul", false]],
	4: [["ghoul", false], ["ghoul", true], ["hound", false]],
}

var player: CharacterBody3D
var hud: CanvasLayer
var route: Array[Vector3] = []
var camps_cleared := 0
var enc_index := 0
var enc_active := false
var enc_alive := 0
var wave2_sent := false
var boss: CharacterBody3D
var beacon: Node3D
var act_done := false
var tut_t := 0.0
var tut_step := 0
var waygate_ring: Node3D
var motes: GPUParticles3D


func _ready() -> void:
	Game.world = self
	Game.shot_mode = "--shots" in OS.get_cmdline_user_args()
	Game.new_run(Game.shot_mode)
	Game.player = null
	_setup_input()
	Settings.apply_bindings()
	if Settings.fullscreen and not Game.shot_mode:
		Settings.apply_window()
	var loading := LoadingScript.new()
	add_child(loading)
	var t0 := Time.get_ticks_msec()
	await loading.step("Kindling the sky", 0.05)
	WorldBuilder.build_environment(self)
	await loading.step("Raising the land", 0.15)
	Game.heights = PackedFloat32Array()
	Game.bake_heights()
	route = WorldBuilder.plan_route()
	WorldBuilder.build_terrain(self)
	WorldBuilder.build_water(self)
	await loading.step("Sowing the meadows", 0.35)
	WorldBuilder.build_grass(self)
	await loading.step("Growing the forests", 0.55)
	WorldBuilder.build_trees(self)
	WorldBuilder.build_rocks(self)
	await loading.step("Raising the ruins", 0.75)
	WorldBuilder.build_ruins(self, route.slice(0, route.size() - 1))
	WorldBuilder.build_arena(self, route[route.size() - 1])
	waygate_ring = WorldBuilder.build_waygate(self, Vector3(0, Game.sample_height(0, -14), -14))
	print("world built in ", Time.get_ticks_msec() - t0, " ms")
	Settings.apply()
	await loading.step("Waking the husks", 0.9)

	player = PlayerScript.new()
	player.name = "Player"
	add_child(player)
	player.global_position = Vector3(0, Game.sample_height(0, 6) + 0.5, 6)
	player.yaw = PI
	Game.player = player

	hud = HudScript.new()
	add_child(hud)
	Game.hud = hud
	hud.bind(player)

	_build_motes()
	_build_beacon()
	Sfx.loop("wind", self, -8.0)
	add_child(AmbienceScript.new())
	var arena := route[route.size() - 1]
	boss = BossScript.new()
	add_child(boss)
	boss.global_position = arena + Vector3(0, 0.3, 0)
	boss.summon_cb = _boss_summon
	boss.health_changed.connect(func(r): hud.set_boss(r))
	boss.died_at.connect(func(_p): _on_boss_dead())
	_update_objective()
	# Let shaders and GI settle behind the card before revealing the world.
	await loading.step("Ready", 1.0)
	if Game.shot_mode:
		await _shot("00_loading")
		loading.queue_free()
	else:
		await get_tree().create_timer(1.2).timeout
		loading.finish()

	if "--creatures" in OS.get_cmdline_user_args():
		_run_creature_showcase()
	elif "--bench" in OS.get_cmdline_user_args():
		_run_bench()
	elif Game.shot_mode and "--swim" in OS.get_cmdline_user_args():
		SwimTour.run(self)
	elif Game.shot_mode:
		_run_shots()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		hud.show_banner("RUN %d  ·  ACT I  —  THE VERDANT RUINS" % Game.run_count)


func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
		"sprint": [KEY_SHIFT], "jump": [KEY_SPACE], "dodge": [KEY_C, KEY_CTRL, KEY_ALT],
		"reload": [KEY_R], "interact": [KEY_E], "melee": [KEY_F, KEY_V],
		"use_1": [KEY_1], "use_2": [KEY_2], "use_3": [KEY_3],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	for pair in [["fire", MOUSE_BUTTON_LEFT], ["aim", MOUSE_BUTTON_RIGHT], ["weapon_gun", MOUSE_BUTTON_WHEEL_UP], ["weapon_axe", MOUSE_BUTTON_WHEEL_DOWN]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
		var mb := InputEventMouseButton.new()
		mb.button_index = pair[1]
		InputMap.action_add_event(pair[0], mb)


func _spawn(kind: String, elite: bool, lvl: int, pos: Vector3) -> CharacterBody3D:
	var e := EnemyScript.new()
	e.setup(kind, elite, lvl)
	pos.y = Game.sample_height(pos.x, pos.z) + 0.2
	add_child(e)
	e.global_position = pos
	e.home = pos
	return e


func _start_encounter(i: int, group: Array) -> void:
	var c := route[i]
	var to_player := player.global_position - c
	to_player.y = 0
	var base_a := atan2(to_player.z, to_player.x)
	for k in group.size():
		# Erupt in a loose arc on the near side of the clearing.
		var a := base_a + (k - (group.size() - 1) * 0.5) * 0.7 + randf_range(-0.2, 0.2)
		var pos := c + Vector3(cos(a), 0, sin(a)) * randf_range(3.0, 8.0)
		var e := _spawn(group[k][0], group[k][1], i, pos)
		enc_alive += 1
		e.died_at.connect(func(_p): _on_enemy_died(i))


func _on_enemy_died(i: int) -> void:
	if i != enc_index:
		return
	enc_alive -= 1
	if enc_alive <= 1 and not wave2_sent and SECOND_WAVES.has(i):
		wave2_sent = true
		hud.prompt("More are coming!", 1.5)
		get_tree().create_timer(1.2).timeout.connect(func(): _start_encounter(i, SECOND_WAVES[i]))
		return
	if enc_alive <= 0:
		enc_active = false
		camps_cleared += 1
		enc_index += 1
		var tome := preload("res://scripts/pickups/ember_tome.gd").new()
		add_child(tome)
		var tp := route[i]
		tp.y = Game.sample_height(tp.x, tp.z)
		tome.global_position = tp
		hud.show_banner("AMBUSH CLEARED  %d / %d" % [camps_cleared, ENCOUNTERS.size()])
		hud.prompt("An Ember Codex rises at the heart of the ruins", 3.0)
		_update_objective()


func _boss_summon(n: int) -> void:
	for k in n:
		var a := TAU * k / n + randf()
		var pos := boss.global_position + Vector3(cos(a), 0, sin(a)) * 7.0
		_spawn("ghoul" if k % 2 == 0 else "hound", false, 4, pos)


func _on_boss_dead() -> void:
	act_done = true
	var tome := preload("res://scripts/pickups/ember_tome.gd").new()
	add_child(tome)
	var ap := route[route.size() - 1]
	ap.y = Game.sample_height(ap.x, ap.z)
	tome.global_position = ap
	hud.hide_boss()
	hud.show_banner("ACT I COMPLETE")
	player.heal(999.0)
	_update_objective()


func _update_objective() -> void:
	if act_done:
		hud.set_objective("The Colossus has fallen. Act II is coming soon.")
		hud.set_marker(false)
		beacon.visible = false
	elif enc_index < ENCOUNTERS.size():
		hud.set_objective("Follow the ember beacon  ·  ambush %d / %d" % [enc_index + 1, ENCOUNTERS.size()])
		_place_beacon(route[enc_index], Color(1.0, 0.55, 0.2))
		hud.set_marker(true, route[enc_index] + Vector3(0, 2, 0), "AMBUSH SITE", Color(1.0, 0.6, 0.25))
	else:
		hud.set_objective("Enter the arena and face the Ashen Colossus")
		var a := route[route.size() - 1]
		_place_beacon(a, Color(1.0, 0.2, 0.1))
		hud.set_marker(true, a + Vector3(0, 3, 0), "THE COLOSSUS", Color(1.0, 0.3, 0.2))


func _build_beacon() -> void:
	beacon = Node3D.new()
	add_child(beacon)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.9
	cyl.height = 70.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.5, 0.2, 0.35)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Fade out up close so standing at the site doesn't fill the screen.
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 3.0
	m.distance_fade_max_distance = 16.0
	cyl.material = m
	var mi := MeshInstance3D.new()
	mi.name = "Pillar"
	mi.mesh = cyl
	mi.position.y = 35.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.add_child(mi)
	var l := OmniLight3D.new()
	l.name = "Light"
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 3.0
	l.omni_range = 14.0
	l.position.y = 2.0
	beacon.add_child(l)
	Sfx.loop("beacon", beacon, -4.0, 3.0, 40.0)


func _place_beacon(at: Vector3, col: Color) -> void:
	beacon.visible = true
	beacon.global_position = at
	var mi: MeshInstance3D = beacon.get_node("Pillar")
	(mi.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color = Color(col.r, col.g, col.b, 0.35)
	(beacon.get_node("Light") as OmniLight3D).light_color = col


func _direct(delta: float) -> void:
	if player == null or player.dead or Game.shot_mode:
		return
	# Light tutorial while walking to the first site.
	tut_t += delta
	if tut_step == 0 and tut_t > 1.5:
		tut_step = 1
		hud.prompt("WASD  move     SHIFT  sprint     SPACE  jump", 4.5)
	elif tut_step == 1 and tut_t > 7.5:
		tut_step = 2
		hud.prompt("RMB  aim     LMB  fire     F  blade     C  dodge", 4.5)
	elif tut_step == 2 and tut_t > 13.5:
		tut_step = 3
		hud.prompt("Follow the ember beacon", 3.5)
	if act_done:
		return
	if enc_index < ENCOUNTERS.size():
		if not enc_active and player.global_position.distance_to(route[enc_index]) < 22.0:
			enc_active = true
			enc_alive = 0
			wave2_sent = false
			beacon.visible = false
			hud.set_marker(false)
			hud.set_objective("Survive the ambush")
			hud.prompt("Ash creatures emerge!", 1.5)
			_start_encounter(enc_index, ENCOUNTERS[enc_index])
	elif boss.state == "dormant" and player.global_position.distance_to(boss.global_position) < 20.0:
		boss.awaken()
		beacon.visible = false
		hud.set_marker(false)
		hud.show_boss("THE ASHEN COLOSSUS")
		hud.set_objective("Defeat the Ashen Colossus")
		hud.show_banner("THE ASHEN COLOSSUS")


func _build_motes() -> void:
	motes = GPUParticles3D.new()
	motes.amount = 220
	motes.lifetime = 8.0
	motes.preprocess = 8.0
	motes.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 20, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(25, 6, 25)
	pm.gravity = Vector3(0, 0.05, 0)
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.4
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.5, 0))
	grad.add_point(0.2, Color(1.0, 0.85, 0.5, 1))
	grad.add_point(0.8, Color(1.0, 0.85, 0.5, 1))
	grad.set_color(grad.get_point_count() - 1, Color(1.0, 0.85, 0.5, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	motes.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = WorldBuilder._soft_dot()
	qm.albedo_color = Color(2, 2, 2)
	q.material = qm
	motes.draw_pass_1 = q
	add_child(motes)


func _process(delta: float) -> void:
	_direct(delta)
	if beacon and beacon.visible:
		beacon.rotate_y(delta * 0.5)
	if motes and player:
		motes.global_position = player.global_position
	if waygate_ring:
		waygate_ring.rotate_object_local(Vector3.UP, delta * 0.4)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE:
			hud.on_escape()
		KEY_F1:
			Settings.cycle()
			hud.toast("Graphics: " + Settings.preset_name(), Color(0.6, 0.9, 1.0))
		KEY_F3:
			Settings.show_fps = not Settings.show_fps
			Settings.save()
		KEY_F11:
			Settings.fullscreen = not Settings.fullscreen
			Settings.apply_window()
			Settings.save()


# ------------------------------------------------------------ screenshots

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://screenshots/")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir + file + ".png")
	print("saved ", file)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _face_player_to(target: Vector3) -> void:
	var d := target - player.global_position
	player.yaw = atan2(-d.x, -d.z)
	player.face_yaw = player.yaw


func _teleport(pos: Vector3) -> void:
	pos.y = Game.sample_height(pos.x, pos.z) + 0.3
	player.global_position = pos
	player.velocity = Vector3.ZERO


func _run_shots() -> void:
	var args := OS.get_cmdline_user_args()
	player.input_enabled = false
	# 1. Start: the beacon marks the first ambush site.
	_face_player_to(route[0])
	player.pitch = -0.05
	hud.prompt("Follow the ember beacon", 3.0)
	await _wait(1.0)
	await _shot("01_start_beacon")

	# 2. Firing: recoil, muzzle flash, smoke, shell.
	player.force_aim = true
	await _wait(0.5)
	player.force_fire = true
	await _wait(0.25)
	while player.last_shot_t > 0.0:
		await get_tree().process_frame
	await _shot("02_fire_flash")
	player.force_fire = false
	player.force_aim = false
	player.last_shot_t = 5.0

	# 2b. Reload: the spent magazine drops, a fresh one comes from the pouch.
	var rc := Camera3D.new()
	rc.fov = 40.0
	add_child(rc)
	var rr := Vector3(cos(player.face_yaw), 0, -sin(player.face_yaw))
	var rf := Vector3(-sin(player.face_yaw), 0, -cos(player.face_yaw))
	player.ammo = 3
	player._start_reload()
	rc.global_position = player.global_position + rr * 1.6 + rf * 1.3 + Vector3(0, 1.5, 0)
	rc.look_at(player.global_position + Vector3(0, 1.15, 0) + rf * 0.3)
	rc.current = true
	await _wait(player.stats.reload_time * 0.3)
	await _shot("02b_reload_drop")
	await _wait(player.stats.reload_time * 0.32)
	await _shot("02c_reload_new_mag")
	await _wait(player.stats.reload_time * 0.5)
	player.cam.current = true

	# 2d. Battle axe: wind-up and the heavy finisher.
	rc.global_position = player.global_position + rr * 3.2 + rf * 1.0 + Vector3(0, 1.3, 0)
	rc.look_at(player.global_position + Vector3(0, 1.2, 0) + rf * 0.8)
	rc.current = true
	player.combo_reset_t = 0.0
	player.melee()
	await _wait(player.swing_dur * 0.38)
	await _shot("02d_axe_windup")
	await _wait(player.swing_dur * 0.75)
	player.melee()
	await _wait(player.swing_t + 0.05)
	player.melee()
	await _wait(player.swing_dur * 0.6)
	await _shot("02e_axe_finisher")
	await _wait(0.8)
	player.cam.current = true
	rc.queue_free()

	# 3. Jump tuck, seen from the side.
	var side_cam := Camera3D.new()
	side_cam.fov = 45.0
	add_child(side_cam)
	await _wait(0.5)
	player.velocity.y = player.stats.jump
	await _wait(0.22)
	var r := Vector3(cos(player.face_yaw), 0, -sin(player.face_yaw))
	side_cam.global_position = player.global_position + r * 4.0 + Vector3(0, 1.4, 0)
	side_cam.look_at(player.global_position + Vector3(0, 1.0, 0))
	side_cam.current = true
	await _shot("03_jump")
	await _wait(1.0)
	var rr2 := Vector3(cos(player.face_yaw), 0, -sin(player.face_yaw))
	var rf2 := Vector3(-sin(player.face_yaw), 0, -cos(player.face_yaw))
	side_cam.global_position = player.global_position + rf2 * 2.7 + rr2 * 4.0 + Vector3(0, 1.2, 0)
	side_cam.look_at(player.global_position + rf2 * 2.7 + Vector3(0, 0.7, 0))
	player.dodge_cd = 0.0
	player._dodge()
	await _wait(0.3)
	await _shot("03b_roll_mid")
	await _wait(0.3)
	await _shot("03c_roll_slide")
	await _wait(0.6)
	player.cam.current = true

	# 4. First ambush: two ghouls erupt and close in.
	var site := route[0]
	var approach := (player.global_position - site)
	approach.y = 0
	_teleport(site + approach.normalized() * 11.0)
	_face_player_to(site)
	await _wait(0.3)
	enc_index = 0
	enc_active = true
	_start_encounter(0, ENCOUNTERS[0])
	await _wait(0.6)
	await _shot("04_ambush_emerge")
	await _wait(2.6)
	player.heal(999.0)
	await _shot("05_ghouls_close")
	for k in 30:
		await _wait(0.1)
		if player.flinch > 0.6:
			break
	await _shot("06_ghoul_hit")
	player.heal(999.0)

	# 4b. The site's Ember Codex and the tarot boon cards.
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != boss:
			e.queue_free()
	var tome := preload("res://scripts/pickups/ember_tome.gd").new()
	add_child(tome)
	var tp := site
	tp.y = Game.sample_height(tp.x, tp.z)
	tome.global_position = tp
	_teleport(site + approach.normalized() * 3.2)
	_face_player_to(site)
	player.pitch = -0.2
	await _wait(1.4)
	await _shot("06b_ember_tome")
	tome._take()
	hud.offer_boons("Ember Codex  ·  Choose a boon", true)
	await _wait(0.42)
	await _shot("06c0_cards_dealing")
	await _wait(0.9)
	hud.boon_menu.force_hover(1)
	await _wait(0.4)
	await _shot("06c_tarot_cards")
	hud.boon_menu._claim(hud.boon_menu.items[1], SkillTree.find("b_dmg").id if false else hud.boon_menu.items[1].get_meta("id", ""))
	await _wait(0.4)
	await _shot("06c2_card_claimed")
	await _wait(1.0)
	hud.offer_root.visible = false
	hud.offer_queue.clear()
	get_tree().paused = false
	for id in ["b_dmg", "b_speed", "b_leap", "s_hp", "g_dmg", "g_explode", "g_rate"]:
		player.apply_boon(id)
	Engine.time_scale = 1.0
	hud.toggle_tree()
	await _wait(0.3)
	await _shot("06e_arcana")
	hud.toggle_tree()
	for id in ["skin_r", "ammo_e", "str_l"]:
		player.give_item(id)
	player.set_weapon("axe")
	await _wait(0.5)
	await _shot("06d_satchel_axe")
	var wc := Camera3D.new()
	wc.fov = 40.0
	add_child(wc)
	var wr := Vector3(cos(player.face_yaw), 0, -sin(player.face_yaw))
	var wf := Vector3(-sin(player.face_yaw), 0, -cos(player.face_yaw))
	wc.global_position = player.global_position + wr * 2.0 + wf * 1.6 + Vector3(0, 1.5, 0)
	wc.look_at(player.global_position + Vector3(0, 1.1, 0) + wf * 0.3)
	wc.current = true
	await _wait(0.4)
	await _shot("06g_flaming_axe")
	player.set_weapon("gun")
	player.empowered = true
	await _wait(0.4)
	await _shot("06h_hot_rifle")
	player.empowered = false
	player.cam.current = true
	wc.queue_free()
	player.set_weapon("gun")
	hud.on_escape()
	await _wait(0.4)
	await _shot("06f_pause_menu")
	hud.pause_menu.close()

	# 5. Hounds circling.
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != boss:
			e.queue_free()
	_start_encounter(0, [["hound", false], ["hound", false], ["ghoul", false]])
	await _wait(3.2)
	player.heal(999.0)
	await _shot("07_hounds")
	var bite_side := Camera3D.new()
	bite_side.fov = 50.0
	add_child(bite_side)
	for k in 60:
		await _wait(0.05)
		var biter = null
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.kind == "hound" and e.state in ["bite_windup", "attack", "pounce"]:
				biter = e
		if biter:
			var mid: Vector3 = (biter.global_position + player.global_position) * 0.5
			var sd: Vector3 = (biter.global_position - player.global_position).cross(Vector3.UP).normalized()
			bite_side.global_position = mid + sd * 4.5 + Vector3(0, 1.6, 0)
			bite_side.look_at(mid + Vector3(0, 0.8, 0))
			bite_side.current = true
			await _wait(0.15)
			await _shot("07b_hound_attack")
			break
	player.cam.current = true
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != boss:
			e.queue_free()

	# 6. Boss arena.
	var arena := route[route.size() - 1]
	var ap := player.global_position - arena
	ap.y = 0
	_teleport(arena + ap.normalized() * 15.0)
	_face_player_to(arena)
	player.pitch = 0.05
	boss.awaken()
	hud.show_boss("THE ASHEN COLOSSUS")
	await _wait(2.0)
	await _shot("08_boss_emerge")
	await _wait(3.0)
	boss.attack_cd = 99.0
	boss._slam()
	await _wait(0.45)
	player.heal(999.0)
	await _shot("09_boss_slam_warning")
	await _wait(0.75)
	await _shot("09b_boss_wavefront")
	await _wait(1.6)
	player.heal(999.0)
	await _shot("09_boss_fight")
	var bc := Camera3D.new()
	bc.fov = 50.0
	add_child(bc)
	bc.global_position = player.global_position + Vector3(0, 3.5, 0) - (arena - player.global_position).normalized() * 6.0
	bc.look_at(boss.global_position + Vector3(0, 3.0, 0))
	bc.current = true
	hud.visible = false
	await _wait(1.0)
	await _shot("10_boss_wide")
	if "--hold" not in args:
		get_tree().quit()


func _spawn_pack(dist: float) -> Array:
	var fwd := Vector3(-sin(player.yaw), 0, -cos(player.yaw))
	var side := fwd.cross(Vector3.UP)
	var pack: Array = []
	for k in 5:
		var e := EnemyScript.new()
		e.setup("hound" if k % 2 == 1 else "ghoul", k == 2, 0)
		var p := player.global_position + fwd * (dist + (k % 2) * 2.5) + side * (k - 2) * 2.0
		p.y = Game.sample_height(p.x, p.z) + 0.3
		add_child(e)
		e.global_position = p
		e.home = p
		pack.append(e)
	return pack


## Measures average FPS for every preset with a fight on screen, then quits.
## With "--probe", also isolates individual features at Medium.
func _run_bench() -> void:
	player.input_enabled = false
	player.invuln = 9999.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var pack := _spawn_pack(12.0)
	for q in Settings.PRESETS.size():
		Settings.set_quality(q)
		print("BENCH %s: %.1f fps" % [Settings.PRESETS[q], await _measure()])
	if "--probe" in OS.get_cmdline_user_args():
		Settings.set_quality(1)
		print("PROBE medium baseline: %.1f" % await _measure())
		for l in get_tree().get_nodes_in_group("fire_lights"):
			l.shadow_enabled = false
		print("PROBE  - fire light shadows: %.1f" % await _measure())
		for t in get_tree().get_nodes_in_group("trees"):
			t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		print("PROBE  - tree shadows: %.1f" % await _measure())
		Game.grass_holder.visible = false
		print("PROBE  - grass: %.1f" % await _measure())
		Game.env.ssao_enabled = false
		print("PROBE  - ssao: %.1f" % await _measure())
		for t in get_tree().get_nodes_in_group("trees"):
			t.visible = false
		print("PROBE  - trees entirely: %.1f" % await _measure())
	get_tree().quit()


func _measure() -> float:
	await _wait(1.5)
	var frames := 0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < 3000000:
		player.yaw += 0.004
		await get_tree().process_frame
		frames += 1
	return frames / ((Time.get_ticks_usec() - t0) / 1000000.0)


# ------------------------------------------------------------ creature showcase

func _spawn_creature(k: String, pos: Vector3, yaw: float, sc := 1.0) -> Creature:
	var c := Creature.new()
	c.setup(k)
	add_child(c)
	pos.y = Game.sample_height(pos.x, pos.z)
	c.global_position = pos
	c.rotation.y = yaw
	c.scale = Vector3.ONE * sc
	return c


func _stage_cam(cam: Camera3D, target: Vector3, offset: Vector3, fov := 40.0) -> void:
	target.y = Game.sample_height(target.x, target.z) + target.y
	cam.global_position = target + offset
	cam.fov = fov
	cam.look_at(target)


func _run_creature_showcase() -> void:
	var tag := "creature_"
	player.input_enabled = false
	player.visible = false
	hud.visible = false
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	var cam := Camera3D.new()
	cam.far = 900.0
	add_child(cam)
	cam.current = true
	var z0 := 4.0
	# Lineup.
	var roster := [["ghoul", -4.2, 1.0], ["hound", -1.6, 1.0], ["brute", 1.3, 1.0], ["spitter", 4.2, 1.0]]
	var lineup: Array = []
	for r in roster:
		lineup.append(_spawn_creature(r[0], Vector3(r[1], 0, z0), PI, r[2]))
	var boss := _spawn_creature("colossus", Vector3(0, 0, z0 - 7.0), PI, 2.3)
	_stage_cam(cam, Vector3(0, 1.6, z0 - 1.5), Vector3(0, 0.6, 9.5), 46.0)
	await _wait(2.0)
	await _shot(tag + "c01_lineup")
	for c in lineup:
		c.visible = false
	boss.visible = false

	var shots := [
		["ghoul", "swipe_r", 0.44, "c02_ghoul_windup", Vector3(1.6, 0.4, 2.6)],
		["ghoul", "swipe_r", 0.56, "c03_ghoul_strike", Vector3(-1.4, 0.4, 2.7)],
		["hound", "pounce", 0.47, "c04_hound_pounce", Vector3(2.4, 0.3, 1.6)],
		["brute", "shove", 0.52, "c05_brute_shove", Vector3(2.6, 0.6, 3.0)],
		["brute", "slam", 0.44, "c06_brute_slam_windup", Vector3(-2.8, 0.6, 3.2)],
		["spitter", "spit", 0.46, "c07_spitter_spit", Vector3(2.2, 0.5, 2.2)],
	]
	for sh in shots:
		var c := _spawn_creature(sh[0], Vector3(0, 0, z0), PI)
		c.attack(sh[1])
		c.freeze_a = sh[2]
		_stage_cam(cam, Vector3(0, 1.0 if sh[0] != "spitter" else 0.5, z0), sh[4], 42.0)
		await _wait(0.5)
		await _shot(tag + sh[3])
		c.queue_free()

	# Running pack.
	var runners: Array = []
	for r in [["ghoul", -1.2, 0.0], ["hound", 1.4, -1.0], ["ghoul", 0.4, 1.6]]:
		var c := _spawn_creature(r[0], Vector3(r[1], 0, z0 + r[2]), PI)
		c.speed = c.run_speed
		runners.append(c)
	_stage_cam(cam, Vector3(0, 1.0, z0), Vector3(3.5, 0.5, 5.5), 44.0)
	await _wait(0.73)
	await _shot(tag + "c08_running")
	for c in runners:
		c.queue_free()

	# Death dissolve.
	var dying := _spawn_creature("ghoul", Vector3(0, 0, z0), PI)
	await _wait(0.2)
	dying.die()
	_stage_cam(cam, Vector3(0, 0.8, z0), Vector3(2.0, 0.6, 2.6), 42.0)
	await _wait(1.25)
	await _shot(tag + "c09_death")

	# Boss close-up.
	boss.visible = true
	_stage_cam(cam, Vector3(0, 2.6, z0 - 7.0), Vector3(-4.5, 0.2, 9.0), 48.0)
	await _wait(0.5)
	await _shot(tag + "c10_boss")
	get_tree().quit()
