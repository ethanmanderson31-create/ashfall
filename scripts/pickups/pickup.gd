extends Node3D
## Pickup dropped by creatures: XP embers (teal), ammo cells (amber) or a
## rare potion flask (rarity-coloured). Embers and ammo drift to the player;
## potions sit on the ground until walked over.

var kind := "xp"
var item := ""
var full_warned := false
var value := 3.0
var vel := Vector3.ZERO
var age := 0.0
static var _mats := {}
static var _meshes := {}


func _ready() -> void:
	if _mats.is_empty():
		var xm := StandardMaterial3D.new()
		xm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		xm.albedo_color = Color(0.5, 1.0, 0.9) * 4.0
		var xs := SphereMesh.new()
		xs.radius = 0.09
		xs.height = 0.18
		xs.material = xm
		_meshes["xp"] = xs
		var am := StandardMaterial3D.new()
		am.albedo_color = Color(0.15, 0.12, 0.08)
		am.emission_enabled = true
		am.emission = Color(1.0, 0.7, 0.2)
		am.emission_energy_multiplier = 2.5
		am.metallic = 0.6
		var ab := BoxMesh.new()
		ab.size = Vector3(0.22, 0.14, 0.32)
		ab.material = am
		_meshes["ammo"] = ab
	if kind == "potion":
		_build_flask()
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[kind]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 1.0, 0.85) if kind == "xp" else Color(1.0, 0.7, 0.25)
	l.light_energy = 0.8
	l.omni_range = 2.0
	add_child(l)
	vel = Vector3(randf_range(-2, 2), randf_range(3, 5), randf_range(-2, 2))


func _build_flask() -> void:
	var it := Consumables.info(item)
	var col: Color = it.color
	var rc: Color = Consumables.RARITY_COLORS[it.rarity]
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(col.r, col.g, col.b, 0.85)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.emission_enabled = true
	glass.emission = col
	glass.emission_energy_multiplier = 2.5
	glass.roughness = 0.1
	var body := SphereMesh.new()
	body.radius = 0.13
	body.height = 0.26
	body.material = glass
	var neck := CylinderMesh.new()
	neck.top_radius = 0.035
	neck.bottom_radius = 0.045
	neck.height = 0.12
	neck.material = glass
	var cork := CylinderMesh.new()
	cork.top_radius = 0.04
	cork.bottom_radius = 0.04
	cork.height = 0.05
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.35, 0.22, 0.12)
	cork.material = cm
	var holder := Node3D.new()
	holder.name = "Flask"
	add_child(holder)
	for m in [[body, 0.0], [neck, 0.17], [cork, 0.25]]:
		var mi := MeshInstance3D.new()
		mi.mesh = m[0]
		mi.position.y = m[1]
		holder.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = rc
	l.light_energy = 1.5 + it.rarity * 0.8
	l.omni_range = 3.0 + it.rarity
	add_child(l)
	if it.rarity >= 2:
		var beam := CylinderMesh.new()
		beam.top_radius = 0.05
		beam.bottom_radius = 0.25
		beam.height = 14.0 if it.rarity == 3 else 6.0
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		bm.albedo_color = Color(rc.r, rc.g, rc.b, 0.35)
		beam.material = bm
		var bmi := MeshInstance3D.new()
		bmi.mesh = beam
		bmi.position.y = beam.height * 0.5
		bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bmi)
	vel = Vector3(randf_range(-1.5, 1.5), 4.0, randf_range(-1.5, 1.5))
	if Game.hud and it.rarity >= 2:
		Game.hud.toast("%s potion dropped!" % Consumables.RARITY_NAMES[it.rarity], rc)


func _process_potion(delta: float) -> void:
	var p := Game.player
	var floor_y := Game.sample_height(global_position.x, global_position.z) + 0.35
	vel.y -= 12.0 * delta
	vel.x *= 0.95
	vel.z *= 0.95
	global_position += vel * delta
	if global_position.y < floor_y:
		global_position.y = floor_y
		vel = Vector3.ZERO
	var flask: Node3D = get_node("Flask")
	flask.rotation.y += delta * 1.5
	flask.position.y = sin(age * 2.5) * 0.06 + 0.1
	var d := (p.global_position + Vector3(0, 0.5, 0)).distance_to(global_position)
	if d < 1.5 and age > 0.6 and not p.dead:
		if p.give_item(item):
			var it := Consumables.info(item)
			Sfx.play("potion_get", null, -2.0)
			Game.hud.toast("Picked up %s  ·  %s" % [it.name, it.desc], Consumables.RARITY_COLORS[it.rarity])
			Fx.ring(global_position, it.color, 1.5)
			Game.hud.set_interact("")
			queue_free()
		elif not full_warned:
			full_warned = true
			Game.hud.set_interact("Satchel full  ·  drink a potion (1, 2, 3) to make room")
	elif full_warned and d > 2.5:
		full_warned = false
		Game.hud.set_interact("")


func _process(delta: float) -> void:
	age += delta
	if kind == "potion":
		_process_potion(delta)
		return
	var p := Game.player
	if kind == "ammo":
		rotate_y(delta * 2.0)
	var target := p.global_position + Vector3(0, 1.0, 0)
	var d := target - global_position
	var radius: float = p.stats.pickup_radius * (0.6 if kind == "ammo" else 1.0)
	var full: bool = kind == "ammo" and p.reserve >= p.stats.max_reserve
	if age > 0.5 and not full and (d.length() < radius or (kind == "xp" and age > 6.0)):
		vel = vel.lerp(d.normalized() * 14.0, 1.0 - exp(-6.0 * delta))
	else:
		vel.y -= 9.0 * delta
		vel.x *= 0.97
		vel.z *= 0.97
		var floor_y := Game.sample_height(global_position.x, global_position.z) + 0.5
		if global_position.y < floor_y:
			global_position.y = floor_y
			vel.y = absf(vel.y) * 0.3
	global_position += vel * delta
	if d.length() < 0.7 and not p.dead and not full:
		if kind == "xp":
			p.add_xp(value)
		else:
			p.add_ammo(int(value))
			Sfx.play("draw", null, -14.0, 1.9, 0.05)
			Game.hud.toast("+%d ammo" % int(value), Color(1.0, 0.75, 0.3))
		queue_free()
