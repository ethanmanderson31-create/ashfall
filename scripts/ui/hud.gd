extends CanvasLayer
## Heads-up display: crosshair, health/shield, ammo economy, XP, objective,
## boon offers, the build tree screen (Tab) and the end-of-run summary.

var font: SystemFont
var font_bold: SystemFont
var root: Control
var hp_fill: ColorRect
var hp_ghost: ColorRect
var shield_fill: ColorRect
var hp_label: Label
var ammo_label: Label
var reserve_label: Label
var empty_label: Label
var buff_label: Label
var build_label: RichTextLabel
var xp_fill: ColorRect
var level_label: Label
var objective_label: Label
var act_label: Label
var vignette: ColorRect
var crosshair: Control
var offer_root: Control
var offer_title: Label
var tree_root: Control
var tree_cols: HBoxContainer
var death_root: Control
var death_summary: Label
var banner: Label
var toast_box: VBoxContainer
var fps_label: Label
var overlay: Control
var dmg_marks: Array = []          ## [world_pos, alpha]
var marker_pos := Vector3.ZERO
var marker_on := false
var marker_text := ""
var marker_color := Color(1.0, 0.6, 0.25)
var boss_root: Control
var boss_fill: ColorRect
var boss_name: Label
var prompt_label: Label
var interact_label: Label
var flash_rect: ColorRect
var satchel: HBoxContainer
var weapon_label: Label
var pause_menu: Control

var hp_ratio := 1.0
var ghost_ratio := 1.0
var hurt := 0.0
var beat_t := 0.0
var hitmarker := 0.0
var hit_kill := false
var spread_kick := 0.0
var offer_queue: Array[String] = []
var boon_menu: BoonMenu

const BAR_W := 340.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Arial"])
	font_bold = SystemFont.new()
	font_bold.font_names = font.font_names
	font_bold.font_weight = 700
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vs := Shader.new()
	vs.code = """
shader_type canvas_item;
uniform float hurt = 0.0;
void fragment() {
	float d = length(UV - 0.5) * 1.4;
	float v = smoothstep(0.45, 1.0, d);
	COLOR = mix(vec4(0.0, 0.0, 0.0, v * 0.45), vec4(0.6, 0.0, 0.0, v * 0.9), hurt);
}
"""
	var vm := ShaderMaterial.new()
	vm.shader = vs
	vignette.material = vm
	root.add_child(vignette)

	crosshair = Control.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.draw.connect(_draw_crosshair)
	root.add_child(crosshair)

	act_label = _label(root, "ACT I  ·  THE VERDANT RUINS", 15, true)
	act_label.position = Vector2(36, 28)
	act_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.45))
	objective_label = _label(root, "", 20, false)
	objective_label.position = Vector2(36, 52)
	build_label = RichTextLabel.new()
	build_label.bbcode_enabled = true
	build_label.fit_content = true
	build_label.scroll_active = false
	build_label.position = Vector2(36, 84)
	build_label.size = Vector2(520, 30)
	build_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_label.add_theme_font_override("normal_font", font_bold)
	build_label.add_theme_font_size_override("normal_font_size", 14)
	root.add_child(build_label)

	var xp_bg := ColorRect.new()
	xp_bg.color = Color(0, 0, 0, 0.45)
	xp_bg.size = Vector2(420, 6)
	xp_bg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	xp_bg.position = Vector2(-210, 30)
	root.add_child(xp_bg)
	xp_fill = ColorRect.new()
	xp_fill.color = Color(0.45, 1.0, 0.88)
	xp_fill.size = Vector2(0, 6)
	xp_bg.add_child(xp_fill)
	level_label = _label(xp_bg, "LV 1", 16, true)
	level_label.size = Vector2(420, 20)
	level_label.position = Vector2(0, 10)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Bottom-left: health + shield + buffs.
	var hp_box := Control.new()
	hp_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hp_box.position = Vector2(36, -78)
	root.add_child(hp_box)
	buff_label = _label(hp_box, "", 15, true)
	buff_label.position = Vector2(0, -26)
	buff_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.45))
	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.5)
	hp_bg.size = Vector2(BAR_W, 14)
	hp_bg.position = Vector2(0, 30)
	hp_box.add_child(hp_bg)
	hp_ghost = ColorRect.new()
	hp_ghost.color = Color(1.0, 0.85, 0.7, 0.7)
	hp_ghost.size = Vector2(BAR_W, 14)
	hp_bg.add_child(hp_ghost)
	hp_fill = ColorRect.new()
	hp_fill.color = Color(0.85, 0.22, 0.18)
	hp_fill.size = Vector2(BAR_W, 14)
	hp_bg.add_child(hp_fill)
	shield_fill = ColorRect.new()
	shield_fill.color = Color(0.45, 0.85, 1.0, 0.85)
	shield_fill.size = Vector2(0, 5)
	shield_fill.position = Vector2(0, -7)
	hp_bg.add_child(shield_fill)
	hp_label = _label(hp_box, "100 / 100", 18, true)

	# Bottom-right: magazine + reserve.
	var ammo_box := Control.new()
	ammo_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_box.position = Vector2(-260, -100)
	root.add_child(ammo_box)
	ammo_label = _label(ammo_box, "30", 52, true)
	ammo_label.size = Vector2(150, 60)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reserve_label = _label(ammo_box, "/ 90", 22, true)
	reserve_label.position = Vector2(156, 26)
	reserve_label.size = Vector2(80, 30)
	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(-120, -150)
	toast_box.size = Vector2(350, 110)
	toast_box.alignment = BoxContainer.ALIGNMENT_END
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_box.add_child(toast_box)

	empty_label = _label(root, "OUT OF AMMO  ·  SCROLL DOWN FOR THE AXE", 20, true)
	_hband(empty_label, 0.5, 70, 30)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	empty_label.visible = false

	banner = _label(root, "", 42, true)
	_hband(banner, 0.5, -220, 60)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
	banner.modulate.a = 0.0

	var hint := _label(root, "TAB  arcana      SCROLL  weapon      F  axe      1 2 3  potions      C  dodge      ESC  menu", 13, true)
	_hband(hint, 1.0, -34, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))

	fps_label = _label(root, "", 13, true)
	fps_label.anchor_left = 1.0
	fps_label.anchor_right = 1.0
	fps_label.offset_left = -260
	fps_label.offset_right = -24
	fps_label.offset_top = 22
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))

	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	root.add_child(overlay)
	root.move_child(overlay, 1)

	prompt_label = _label(root, "", 22, true)
	_hband(prompt_label, 0.5, 150, 30)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	prompt_label.modulate.a = 0.0
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 1, 1, 0)
	root.add_child(flash_rect)
	interact_label = _label(root, "", 22, true)
	_hband(interact_label, 0.5, 90, 30)
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.48))

	boss_root = Control.new()
	boss_root.anchor_left = 0.5
	boss_root.anchor_right = 0.5
	boss_root.anchor_top = 0.0
	boss_root.anchor_bottom = 0.0
	boss_root.offset_left = -380
	boss_root.offset_right = 380
	boss_root.offset_top = 74
	boss_root.offset_bottom = 114
	boss_root.visible = false
	root.add_child(boss_root)
	boss_name = _label(boss_root, "", 18, true)
	boss_name.size = Vector2(760, 24)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	var bbg := ColorRect.new()
	bbg.color = Color(0, 0, 0, 0.55)
	bbg.position = Vector2(0, 28)
	bbg.size = Vector2(760, 12)
	boss_root.add_child(bbg)
	boss_fill = ColorRect.new()
	boss_fill.color = Color(1.0, 0.38, 0.12)
	boss_fill.size = Vector2(760, 12)
	bbg.add_child(boss_fill)

	satchel = HBoxContainer.new()
	satchel.anchor_left = 0.5
	satchel.anchor_right = 0.5
	satchel.anchor_top = 1.0
	satchel.anchor_bottom = 1.0
	satchel.offset_left = -380
	satchel.offset_right = 380
	satchel.offset_top = -150
	satchel.offset_bottom = -56
	satchel.alignment = BoxContainer.ALIGNMENT_CENTER
	satchel.add_theme_constant_override("separation", 12)
	satchel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(satchel)
	weapon_label = _label(ammo_box, "", 14, true)
	weapon_label.position = Vector2(0, -24)
	weapon_label.size = Vector2(236, 20)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_label.add_theme_color_override("font_color", Color(1, 0.85, 0.6, 0.75))

	_build_offer()
	_build_tree()
	_build_death()


## Full-width text band anchored at a vertical fraction of the screen.
func _hband(c: Control, anchor_y: float, y: float, h: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = anchor_y
	c.anchor_bottom = anchor_y
	c.offset_left = 0.0
	c.offset_right = 0.0
	c.offset_top = y
	c.offset_bottom = y + h


func _label(parent: Node, text: String, size: int, bold: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_bold if bold else font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func bind(p: Node) -> void:
	p.health_changed.connect(_on_health)
	p.ammo_changed.connect(_on_ammo)
	p.xp_changed.connect(_on_xp)
	p.leveled_up.connect(func():
		toast("LEVEL %d  ·  +6 max health  ·  +4%% damage" % p.level, Color(0.5, 1.0, 0.9)))
	p.hit_enemy.connect(func(killed, _crit):
		hitmarker = 1.0
		hit_kill = killed)
	p.fired.connect(func(): spread_kick = minf(spread_kick + 4.0, 14.0))
	p.died.connect(_on_died)
	p.inventory_changed.connect(_refresh_satchel)
	p.weapon_changed.connect(func(_w): _on_ammo(p.ammo, p.stats.mag, p.reserve, p.reloading))
	_refresh_satchel()
	_on_health(p.hp, p.stats.max_hp, 0.0)
	_on_ammo(p.ammo, p.stats.mag, p.reserve, false)
	_on_xp(0, p.xp_need, 1)
	_refresh_build()


func set_objective(text: String) -> void:
	objective_label.text = text


func show_banner(text: String) -> void:
	banner.text = text
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.2)
	tw.tween_property(banner, "modulate:a", 0.0, 0.8)


func toast(text: String, color: Color) -> void:
	var l := _label(toast_box, text, 16, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_color_override("font_color", color)
	var tw := l.create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func _on_health(cur: float, maxv: float, shield: float) -> void:
	var r := cur / maxv
	hp_ratio = r
	shield_fill.size.x = BAR_W * clampf(shield / 25.0, 0.0, 1.0)
	hp_label.text = "%d / %d" % [roundi(cur), roundi(maxv)]


func _on_ammo(mag: int, _mag_max: int, reserve: int, reloading: bool) -> void:
	var p := Game.player
	if p and p.weapon == "axe":
		ammo_label.text = "AXE"
		reserve_label.text = "%d · %d" % [mag, reserve]
		weapon_label.text = "SCROLL UP  ·  RIFLE"
		ammo_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
		empty_label.visible = false
		return
	weapon_label.text = "SCROLL DOWN  ·  AXE"
	ammo_label.text = str(mag)
	reserve_label.text = "RELOAD" if reloading else "/ %d" % reserve
	var low := reserve < 20
	reserve_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35) if low else Color(0.75, 0.75, 0.75))
	ammo_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35) if mag == 0 else Color(1, 1, 1))
	empty_label.visible = mag == 0 and reserve == 0


func _on_xp(xp: float, need: float, lvl: int) -> void:
	xp_fill.size.x = 420.0 * clampf(xp / need, 0.0, 1.0)
	level_label.text = "LV %d" % lvl


func _refresh_build() -> void:
	var p := Game.player
	if p == null:
		return
	var parts: Array[String] = []
	for b in SkillTree.BRANCH_ORDER:
		var info: Dictionary = SkillTree.BRANCHES[b]
		var pts := SkillTree.branch_points(p.ranks, b)
		parts.append("[color=#%s]%s %d[/color]" % [info.color.to_html(false), info.name.to_upper(), pts])
	build_label.text = "   ".join(parts)


func _process(delta: float) -> void:
	ghost_ratio = move_toward(ghost_ratio, hp_ratio, delta * 0.5) if ghost_ratio > hp_ratio else hp_ratio
	hp_fill.size.x = BAR_W * hp_ratio
	hp_ghost.size.x = BAR_W * ghost_ratio
	# Low health: a slow heartbeat of red at the edges.
	var beat := 0.0
	if hp_ratio < 0.35 and Game.player and not Game.player.dead:
		beat = (0.25 + 0.2 * pow(maxf(sin(Time.get_ticks_msec() * 0.0075), 0.0), 6.0)) * (1.0 - hp_ratio / 0.35) * Game.player.toughness()
	hurt = maxf(hurt - delta * 1.6, beat)
	if beat > 0.0:
		beat_t -= delta
		if beat_t <= 0.0:
			beat_t = 0.84
			Sfx.play("heartbeat", null, -8.0 + beat * 10.0, 1.0, 0.0)
	(vignette.material as ShaderMaterial).set_shader_parameter("hurt", hurt)
	hitmarker = maxf(hitmarker - delta * 5.0, 0.0)
	spread_kick = lerpf(spread_kick, 0.0, 1.0 - exp(-10.0 * delta))
	crosshair.queue_redraw()
	for m in dmg_marks:
		m[1] -= delta * 1.4
	dmg_marks = dmg_marks.filter(func(m): return m[1] > 0.0)
	overlay.queue_redraw()
	fps_label.visible = Settings.show_fps
	satchel.visible = not tree_root.visible and not offer_root.visible
	fps_label.text = "%d FPS  ·  %s  (F1)" % [Engine.get_frames_per_second(), Settings.preset_name()]
	var p := Game.player
	if p:
		var buffs: Array[String] = []
		if p.frenzy > 0:
			buffs.append("FRENZY x%d" % p.frenzy)
		if p.overclock_t > 0.0:
			buffs.append("OVERCLOCK %.1fs" % p.overclock_t)
		if p.shield > 0.0:
			buffs.append("AEGIS")
		if p.stats.phoenix and not p.phoenix_used:
			buffs.append("PHOENIX READY")
		for n in p.buffs:
			var label: String = {"strength": "STRENGTH", "infinite_ammo": "ENDLESS AMMO", "speed": "SPEED", "stoneskin": "STONESKIN", "regen": "REGEN"}.get(n, n.to_upper())
			buffs.append("%s %ds" % [label, ceili(p.buffs[n][0])])
		if p.empowered:
			buffs.append("HOT STREAK ROUND")
		buff_label.text = "   ".join(buffs)
		empty_label.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)


func _draw_crosshair() -> void:
	var p := Game.player
	var gap := 7.0 + spread_kick + (0.0 if p != null and p.aiming else 6.0)
	var c := Color(1, 1, 1, 0.9)
	var sh := Color(0, 0, 0, 0.5)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		crosshair.draw_line(d * gap + Vector2(1, 1), d * (gap + 9.0) + Vector2(1, 1), sh, 2.0)
		crosshair.draw_line(d * gap, d * (gap + 9.0), c, 2.0)
	crosshair.draw_circle(Vector2.ZERO, 1.5, c)
	if hitmarker > 0.0:
		var hc := Color(1.0, 0.3, 0.2, hitmarker) if hit_kill else Color(1, 1, 1, hitmarker)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			crosshair.draw_line(d.normalized() * 10.0, d.normalized() * 18.0, hc, 2.5)


func _style(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


# ------------------------------------------------------------ boon offers

func _build_offer() -> void:
	offer_root = Control.new()
	offer_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	offer_root.visible = false
	root.add_child(offer_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	offer_root.add_child(dim)
	offer_title = _label(offer_root, "", 30, true)
	_hband(offer_title, 0.5, -250, 40)
	offer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	offer_title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.9))
	var hint := _label(offer_root, "TAB  view your build tree", 15, true)
	hint.z_index = 2
	_hband(hint, 1.0, -64, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))


func offer_boons(title: String, force := false) -> void:
	if Game.shot_mode and not force:
		return
	offer_queue.append(title)
	if not offer_root.visible:
		_show_offer()


func _show_offer() -> void:
	var p := Game.player
	var picks := SkillTree.roll(p.ranks, 3)
	if picks.is_empty():
		offer_queue.clear()
		return
	offer_title.text = ""
	if boon_menu == null:
		boon_menu = BoonMenu.new()
		boon_menu.picked.connect(_pick)
		offer_root.get_child(0).visible = false
		offer_root.add_child(boon_menu)
		offer_root.move_child(boon_menu, offer_root.get_child_count() - 2)
	boon_menu.open(offer_queue[0], picks, p.ranks)
	offer_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _pick(id: String) -> void:
	Game.player.apply_boon(id)
	_refresh_build()
	var n := SkillTree.find(id)
	if n.get("keystone", false):
		show_banner("KEYSTONE  ·  " + String(n.name).to_upper())
	offer_queue.pop_front()
	if not offer_queue.is_empty():
		_show_offer()
		return
	offer_root.visible = false
	if not tree_root.visible:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ------------------------------------------------------------ build tree

func _build_tree() -> void:
	tree_root = Control.new()
	tree_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	tree_root.visible = false
	root.add_child(tree_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	tree_root.add_child(dim)
	var t := _label(tree_root, "The Ember Arcana", 40, false)
	t.add_theme_font_override("font", _tarot_font(["Luminari", "Georgia"]))
	t.add_theme_color_override("font_color", Color(1.0, 0.82, 0.48))
	_hband(t, 0.0, 40, 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(tree_root, "Each Ember Codex deals three cards from the unsealed arcana. Your third card in a path awakens its mastery.", 15, false)
	_hband(sub, 0.0, 84, 24)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	tree_cols = HBoxContainer.new()
	tree_cols.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tree_cols.position = Vector2(-735, 126)
	tree_cols.add_theme_constant_override("separation", 30)
	tree_root.add_child(tree_cols)


func _tarot_font(names: Array, italic := false) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_italic = italic
	return f


func _refresh_tree() -> void:
	for c in tree_cols.get_children():
		c.queue_free()
	var f_title := _tarot_font(["Luminari", "Georgia"])
	var f_body := _tarot_font(["Iowan Old Style", "Baskerville", "Georgia"])
	var gold := Color(1.0, 0.82, 0.48)
	var ranks: Dictionary = Game.player.ranks
	for b in SkillTree.BRANCH_ORDER:
		var info: Dictionary = SkillTree.BRANCHES[b]
		var col: Color = info.color
		var pts := SkillTree.branch_points(ranks, b)
		var v := VBoxContainer.new()
		v.custom_minimum_size = Vector2(470, 0)
		v.add_theme_constant_override("separation", 5)
		tree_cols.add_child(v)
		var h := _label(v, "%s   ·   %d" % [info.name, pts], 30, false)
		h.add_theme_font_override("font", f_title)
		h.add_theme_color_override("font_color", col)
		var m: Dictionary = SkillTree.MASTERY[b]
		var awake := pts >= SkillTree.MASTERY_AT
		var ml := _label(v, ("✦ Mastery awakened: %s" if awake else "Mastery at %d boons: %%s" % SkillTree.MASTERY_AT) % m.name, 15, false)
		ml.add_theme_font_override("font", f_body)
		ml.add_theme_color_override("font_color", gold if awake else Color(1, 0.9, 0.75, 0.55))
		var md := _label(v, m.desc, 13, false)
		md.add_theme_font_override("font", f_body)
		md.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
		for tier in range(1, 5):
			var open: bool = pts >= SkillTree.TIER_REQ[tier]
			var th := _label(v, "Arcana %s%s" % [SkillTree.TIER_NAMES[tier], "" if open else "   ·   sealed until %d boons" % SkillTree.TIER_REQ[tier]], 13, false)
			th.add_theme_font_override("font", f_body)
			th.add_theme_color_override("font_color", Color(gold.r, gold.g, gold.b, 0.75 if open else 0.3))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 7)
			v.add_child(row)
			for n in SkillTree.NODES:
				if n.branch != b or n.tier != tier:
					continue
				var have := int(ranks.get(n.id, 0))
				var avail := SkillTree.is_available(ranks, n)
				var card := Control.new()
				card.custom_minimum_size = Vector2(150, 64)
				card.tooltip_text = n.desc
				row.add_child(card)
				var fr := ColorRect.new()
				fr.size = Vector2(150, 64)
				fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var mat := ShaderMaterial.new()
				mat.shader = load("res://shaders/ui/card_frame.gdshader")
				mat.set_shader_parameter("size", Vector2(150, 64))
				mat.set_shader_parameter("accent", col)
				mat.set_shader_parameter("hover", 1.0 if have > 0 else 0.0)
				mat.set_shader_parameter("dim", 0.0 if (have > 0 or avail) else 0.7)
				fr.material = mat
				card.add_child(fr)
				var alpha := 1.0 if have > 0 else (0.85 if avail else 0.35)
				var nm := _label(card, n.name, 15, false)
				nm.add_theme_font_override("font", f_title)
				nm.add_theme_color_override("font_color", Color(1.0, 0.93, 0.8, alpha))
				nm.position = Vector2(12, 10)
				nm.size = Vector2(126, 24)
				nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				var tag := "KEYSTONE" if n.get("keystone", false) else ("%d / %d" % [have, n.max])
				var rk := _label(card, tag, 12, false)
				rk.add_theme_font_override("font", f_body)
				rk.add_theme_color_override("font_color", Color(col.r, col.g, col.b, alpha))
				rk.position = Vector2(12, 36)
				rk.size = Vector2(126, 20)
				rk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _synergy_row() -> void:
	var f_title := _tarot_font(["Luminari", "Georgia"])
	var f_body := _tarot_font(["Iowan Old Style", "Baskerville", "Georgia"])
	var ranks: Dictionary = Game.player.ranks
	var active := SkillTree.active_synergies(ranks).map(func(s): return s.id)
	var old := tree_root.get_node_or_null("Synergies")
	if old:
		old.queue_free()
	var box := VBoxContainer.new()
	box.name = "Synergies"
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -735
	box.offset_right = 735
	box.offset_top = -170
	box.offset_bottom = -40
	tree_root.add_child(box)
	var h := _label(box, "Synergies", 24, false)
	h.add_theme_font_override("font", f_title)
	h.add_theme_color_override("font_color", Color(1.0, 0.82, 0.48))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for sy in SkillTree.SYNERGIES:
		var on: bool = active.has(sy.id)
		var needs: Array = []
		for nd in sy.needs:
			needs.append(String(SkillTree.MASTERY[nd.substr(2)].name) + " mastery" if String(nd).begins_with("m:") else String(SkillTree.find(nd).name))
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(285, 0)
		row.add_child(card)
		var nm := _label(card, ("✦ " if on else "") + String(sy.name), 17, false)
		nm.add_theme_font_override("font", f_title)
		nm.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5) if on else Color(1, 1, 1, 0.5))
		var d := _label(card, sy.desc, 13, false)
		d.add_theme_font_override("font", f_body)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD
		d.custom_minimum_size.x = 280
		d.add_theme_color_override("font_color", Color(1, 1, 1, 0.75 if on else 0.4))
		var r := _label(card, " + ".join(needs), 12, false)
		r.add_theme_font_override("font", f_body)
		r.add_theme_color_override("font_color", Color(1.0, 0.82, 0.48, 0.7 if on else 0.35))


func toggle_tree() -> void:
	tree_root.visible = not tree_root.visible
	if tree_root.visible:
		Sfx.play("arcana", null, -8.0, 1.0, 0.03)
		_refresh_tree()
		_synergy_row()
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not offer_root.visible:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ------------------------------------------------------------ death

func _build_death() -> void:
	death_root = Control.new()
	death_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_root.visible = false
	root.add_child(death_root)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.0, 0.0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_root.add_child(dim)
	var t := _label(death_root, "YOU FELL", 64, true)
	_hband(t, 0.5, -160, 80)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_color", Color(0.9, 0.25, 0.2))
	death_summary = _label(death_root, "", 19, false)
	_hband(death_summary, 0.5, -70, 160)
	death_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var s := _label(death_root, "Press ENTER to begin a new run  ·  new world, new boons", 20, true)
	_hband(s, 0.5, 110, 30)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))


func _on_died() -> void:
	var p := Game.player
	var main := SkillTree.main_branch(p.ranks)
	var build_name := "Unaligned" if main == "" else String(SkillTree.BRANCHES[main].name)
	var keystones: Array[String] = []
	for n in SkillTree.NODES:
		if n.get("keystone", false) and int(p.ranks.get(n.id, 0)) > 0:
			keystones.append(n.name)
	death_summary.text = "Run %d  ·  Level %d  ·  %d husks destroyed\nCamps purged: %d\nBuild: %s%s" % [
		Game.run_count, p.level, p.kills, Game.world.camps_cleared, build_name,
		"" if keystones.is_empty() else "  ·  " + ", ".join(keystones)]
	await get_tree().create_timer(1.2).timeout
	death_root.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if death_root.visible and event.keycode == KEY_ENTER:
		get_tree().paused = false
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
	elif event.keycode == KEY_TAB and not death_root.visible:
		toggle_tree()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------ combat overlay

func damage_from(world_pos: Vector3) -> void:
	dmg_marks.append([world_pos, 1.0])


func set_marker(on: bool, pos := Vector3.ZERO, text := "", color := Color(1.0, 0.6, 0.25)) -> void:
	marker_on = on
	marker_pos = pos
	marker_text = text
	marker_color = color


func prompt(text: String, hold := 4.0) -> void:
	prompt_label.text = text
	var tw := create_tween()
	tw.tween_property(prompt_label, "modulate:a", 1.0, 0.3)
	tw.tween_interval(hold)
	tw.tween_property(prompt_label, "modulate:a", 0.0, 0.6)


func show_boss(n: String) -> void:
	boss_name.text = n
	boss_fill.size.x = 760
	boss_root.visible = true


func set_boss(ratio: float) -> void:
	boss_fill.size.x = 760.0 * clampf(ratio, 0.0, 1.0)


func hide_boss() -> void:
	boss_root.visible = false


func _draw_overlay() -> void:
	var p := Game.player
	if p == null:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var size := overlay.size
	var center := size * 0.5
	# Damage direction arcs around the crosshair.
	for m in dmg_marks:
		var to: Vector3 = m[0] - p.global_position
		var local := cam.global_basis.inverse() * to
		var ang := atan2(local.x, -local.z)
		var a: float = m[1]
		var r := 150.0
		var pts := PackedVector2Array()
		for k in 13:
			var t := ang - 0.35 + 0.7 * k / 12.0
			pts.append(center + Vector2(sin(t), -cos(t)) * r)
		overlay.draw_polyline(pts, Color(1.0, 0.15, 0.1, a * 0.9), 7.0, true)
	# Objective beacon marker.
	if marker_on:
		var behind := cam.is_position_behind(marker_pos)
		var sp := cam.unproject_position(marker_pos)
		if behind:
			sp = size - sp
		var margin := 60.0
		var off := not Rect2(Vector2(margin, margin), size - Vector2(margin, margin) * 2.0).has_point(sp) or behind
		if off:
			var d := (sp - center).normalized()
			if behind:
				d.y = absf(d.y)
			var k := minf((size.x * 0.5 - margin) / maxf(absf(d.x), 0.001), (size.y * 0.5 - margin) / maxf(absf(d.y), 0.001))
			sp = center + d * k
		var s := 11.0
		var dia := PackedVector2Array([sp + Vector2(0, -s), sp + Vector2(s, 0), sp + Vector2(0, s), sp + Vector2(-s, 0)])
		overlay.draw_colored_polygon(dia, Color(0, 0, 0, 0.5))
		overlay.draw_polyline(dia + PackedVector2Array([dia[0]]), marker_color, 2.5, true)
		overlay.draw_circle(sp, 3.0, marker_color)
		var dist := p.global_position.distance_to(marker_pos)
		var txt := "%s  %dm" % [marker_text, roundi(dist)]
		overlay.draw_string(font_bold, sp + Vector2(-80, 30), txt, HORIZONTAL_ALIGNMENT_CENTER, 160, 14, Color(1, 1, 1, 0.9))


func set_interact(text: String) -> void:
	interact_label.text = text


func flash(c: Color, a: float) -> void:
	flash_rect.color = Color(c.r, c.g, c.b, a)
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.35)


## A hit: red edges, a red wash over the whole screen, scaled by how much it hurt.
func hurt_pulse(intensity: float) -> void:
	hurt = maxf(hurt, 0.4 + 0.6 * intensity)
	flash(Color(0.7, 0.03, 0.02), 0.12 + 0.3 * intensity)


# ------------------------------------------------------------ satchel

func _refresh_satchel() -> void:
	for c in satchel.get_children():
		c.queue_free()
	var p := Game.player
	if p == null:
		return
	var f_title := _tarot_font(["Luminari", "Georgia"])
	var f_body := _tarot_font(["Iowan Old Style", "Baskerville", "Georgia"])
	const W := 240.0
	const H := 94.0
	for i in 3:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(W, H)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.clip_contents = true
		satchel.add_child(slot)
		var fr := ColorRect.new()
		fr.size = Vector2(W, H)
		fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/ui/card_frame.gdshader")
		mat.set_shader_parameter("size", Vector2(W, H))
		var has: bool = i < p.inventory.size()
		var it: Dictionary = Consumables.info(p.inventory[i]) if has else {}
		var rc: Color = Consumables.RARITY_COLORS[it.rarity] if has else Color(0.5, 0.45, 0.4)
		mat.set_shader_parameter("accent", rc)
		mat.set_shader_parameter("hover", 0.6 if has else 0.0)
		mat.set_shader_parameter("dim", 0.0 if has else 0.55)
		fr.material = mat
		slot.add_child(fr)
		if not has:
			var e := _fit_label(slot, "%d  ·  Empty" % (i + 1), f_body, 14, Color(1, 1, 1, 0.3), Rect2(0, 37, W, 20))
			e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			continue
		var flask := Control.new()
		flask.position = Vector2(24, 26)
		flask.size = Vector2(30, 42)
		flask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col: Color = it.color
		flask.draw.connect(func():
			flask.draw_circle(Vector2(15, 27), 14, Color(col.r, col.g, col.b, 0.3))
			flask.draw_circle(Vector2(15, 27), 11, col)
			flask.draw_rect(Rect2(11, 5, 8, 12), col)
			flask.draw_rect(Rect2(10, 1, 10, 5), Color(0.4, 0.25, 0.12)))
		slot.add_child(flask)
		# Three fixed lines inside the card: category, name, effect.
		var tx := 66.0
		var tw := W - tx - 24.0
		_fit_label(slot, "%d  ·  %s  ·  %s" % [i + 1, String(it.tag).to_upper(), String(Consumables.RARITY_NAMES[it.rarity]).to_upper()], f_body, 10, Color(rc.r, rc.g, rc.b, 0.9), Rect2(tx, 22, tw, 14))
		_fit_label(slot, it.name, f_title, 16, rc.lightened(0.15), Rect2(tx, 36, tw, 22))
		_fit_label(slot, it.desc, f_body, 13, Color(0.95, 0.9, 0.8, 0.9), Rect2(tx, 58, tw, 16))


## Single-line label that shrinks its font until the text fits its box.
func _fit_label(parent: Control, text: String, f: Font, size: int, col: Color, rect: Rect2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = rect.position
	l.size = rect.size
	l.clip_text = true
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var fs := size
	while fs > 8 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > rect.size.x:
		fs -= 1
	l.add_theme_font_size_override("font_size", fs)
	parent.add_child(l)
	return l


# ------------------------------------------------------------ pause

func on_escape() -> void:
	if tree_root.visible:
		toggle_tree()
	elif offer_root.visible or death_root.visible:
		return
	elif pause_menu and pause_menu.visible:
		pause_menu.close()
	else:
		if pause_menu == null:
			pause_menu = preload("res://scripts/ui/pause_menu.gd").new()
			root.add_child(pause_menu)
		pause_menu.open()
