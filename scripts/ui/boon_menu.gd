class_name BoonMenu
extends Control
## Fantasy boon chooser: three gilded "Tarot of Embers" cards with glowing
## branch sigils that lift and brighten on hover. Emits `picked(id)`.

signal picked(id: String)

const SIGIL := {"gun": 0, "blade": 1, "ward": 2}

var f_title: SystemFont
var f_body: SystemFont
var f_italic: SystemFont
var items: Array[Control] = []
var hover_amt := {}
var claiming := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	f_title = _font(["Luminari", "Papyrus", "Georgia"], 400)
	f_body = _font(["Iowan Old Style", "Baskerville", "Georgia"], 400)
	f_italic = _font(["Iowan Old Style", "Baskerville", "Georgia"], 400, true)


func _font(names: Array, weight: int, italic := false) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	f.font_italic = italic
	return f


func _lbl(parent: Control, text: String, f: Font, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _shader_rect(parent: Control, path: String, pos: Vector2, size: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load(path)
	r.material = m
	parent.add_child(r)
	return r


func _sigil(parent: Control, branch: String, pos: Vector2, s: float) -> ColorRect:
	var r := _shader_rect(parent, "res://shaders/ui/sigil.gdshader", pos, Vector2(s, s))
	var m := r.material as ShaderMaterial
	m.set_shader_parameter("kind", SIGIL[branch])
	m.set_shader_parameter("col", SkillTree.BRANCHES[branch].color)
	m.set_shader_parameter("intensity", 0.4)
	return r


func open(title: String, picks: Array, ranks: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	items.clear()
	hover_amt.clear()
	claiming = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.015, 0.01, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var stage := Control.new()
	stage.anchor_left = 0.5
	stage.anchor_right = 0.5
	stage.anchor_top = 0.5
	stage.anchor_bottom = 0.5
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	_build_tarot(stage, title, picks, ranks)
	visible = true


func _rank_text(n: Dictionary, ranks: Dictionary) -> String:
	if n.get("keystone", false):
		return "KEYSTONE"
	var have := int(ranks.get(n.id, 0))
	return "Newly awakened" if have == 0 else "Rank %d  →  %d of %d" % [have, have + 1, n.max]


func _clicker(parent: Control, n: Dictionary, pos: Vector2, size: Vector2) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = size
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	var id: String = n.id
	b.pressed.connect(func(): _claim(b, id))
	b.mouse_entered.connect(func():
		if not b.get_meta("dealing", false) and not claiming:
			Sfx.play("hover", null, -6.0, 1.0, 0.04)
		hover_amt[b] = 1.0)
	b.mouse_exited.connect(func(): hover_amt[b] = 0.0)
	parent.add_child(b)
	items.append(b)
	hover_amt[b] = 0.0
	return b


## Debug/preview: pretend the mouse rests on card i.
func force_hover(i: int) -> void:
	if i < items.size():
		hover_amt[items[i]] = 1.0


# ------------------------------------------------------------ Tarot

func _build_tarot(stage: Control, title: String, picks: Array, ranks: Dictionary) -> void:
	var t := _lbl(stage, title.capitalize(), f_title, 48, Color(1.0, 0.82, 0.48))
	t.position = Vector2(-500, -370)
	t.size = Vector2(1000, 64)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	t.add_theme_constant_override("shadow_offset_y", 3)
	var sub := _lbl(stage, "Draw one fate from the embers", f_italic, 20, Color(1, 0.9, 0.75, 0.6))
	sub.position = Vector2(-500, -306)
	sub.size = Vector2(1000, 30)
	var cw := 300.0
	var ch := 470.0
	for i in picks.size():
		var n: Dictionary = picks[i]
		var info: Dictionary = SkillTree.BRANCHES[n.branch]
		var x := (i - (picks.size() - 1) * 0.5) * (cw + 40.0) - cw * 0.5
		var c := _clicker(stage, n, Vector2(x, -ch * 0.5 + 20), Vector2(cw, ch))
		c.pivot_offset = Vector2(cw * 0.5, ch)
		c.rotation = deg_to_rad((i - (picks.size() - 1) * 0.5) * 4.0)
		c.set_meta("base_y", c.position.y)
		var frame := _shader_rect(c, "res://shaders/ui/card_frame.gdshader", Vector2.ZERO, Vector2(cw, ch))
		frame.name = "Frame"
		(frame.material as ShaderMaterial).set_shader_parameter("accent", info.color)
		(frame.material as ShaderMaterial).set_shader_parameter("size", Vector2(cw, ch))
		var head := _lbl(c, "%s  ·  %s" % [String(info.name).to_upper(), SkillTree.TIER_NAMES[n.tier]], f_body, 14, Color(1.0, 0.82, 0.48))
		head.position = Vector2(0, 32)
		head.size = Vector2(cw, 20)
		var sg := _sigil(c, n.branch, Vector2(cw * 0.5 - 80, 66), 160)
		sg.name = "Sigil"
		var nm := _lbl(c, n.name, f_title, 30, Color(1.0, 0.93, 0.8))
		nm.position = Vector2(16, 244)
		nm.size = Vector2(cw - 32, 44)
		var rule := ColorRect.new()
		rule.color = Color(0.8, 0.6, 0.3, 0.6)
		rule.position = Vector2(70, 296)
		rule.size = Vector2(cw - 140, 1)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(rule)
		var d := _lbl(c, n.desc, f_body, 19, Color(0.92, 0.86, 0.76))
		d.position = Vector2(30, 310)
		d.size = Vector2(cw - 60, 90)
		var rk := _lbl(c, _rank_text(n, ranks), f_italic, 15, info.color if n.get("keystone", false) else Color(1, 0.85, 0.6, 0.6))
		rk.position = Vector2(0, ch - 78)
		rk.size = Vector2(cw, 22)
		var pts := SkillTree.branch_points(ranks, n.branch)
		var m: Dictionary = SkillTree.MASTERY[n.branch]
		var mtxt := ""
		if pts + 1 == SkillTree.MASTERY_AT:
			mtxt = "Awakens mastery: %s" % m.name
		elif pts + 1 < SkillTree.MASTERY_AT:
			mtxt = "%d / %d toward %s" % [pts + 1, SkillTree.MASTERY_AT, m.name]
		var syn := SkillTree.completes(ranks, n.id)
		var mcol: Color = info.color.lightened(0.2)
		if not syn.is_empty():
			mtxt = "✦ Completes synergy: %s" % syn[0].name
			mcol = Color(1.0, 0.85, 0.5)
		if mtxt != "":
			var ml := _lbl(c, mtxt, f_body, 14, mcol)
			ml.position = Vector2(0, ch - 56)
			ml.size = Vector2(cw, 22)
		# Card back, flipped away as the card is dealt.
		var back := _shader_rect(c, "res://shaders/ui/card_frame.gdshader", Vector2.ZERO, Vector2(cw, ch))
		back.name = "Back"
		(back.material as ShaderMaterial).set_shader_parameter("size", Vector2(cw, ch))
		(back.material as ShaderMaterial).set_shader_parameter("back", true)
		(back.material as ShaderMaterial).set_shader_parameter("accent", Color(1.0, 0.6, 0.25))
		_deal(c, i)


func _deal(c: Control, i: int) -> void:
	var target_pos := c.position
	var target_rot := c.rotation
	c.set_meta("dealing", true)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = Vector2(-c.size.x * 0.5, 420.0)
	c.rotation = 0.0
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_interval(0.08 + i * 0.16)
	tw.tween_callback(func(): Sfx.play("deal", null, -4.0, 1.0, 0.08, 0))
	tw.set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.15)
	tw.tween_property(c, "position", target_pos, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "rotation", target_rot, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_interval(0.05 + i * 0.08)
	tw.tween_property(c, "scale:x", 0.0, 0.11).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		c.get_node("Back").visible = false
		Sfx.play("deal", null, -5.0, 1.0 + i * 0.06, 0.03, 1))
	tw.tween_property(c, "scale:x", 1.0, 0.13).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		c.set_meta("dealing", false)
		c.mouse_filter = Control.MOUSE_FILTER_STOP)


## The reward moment: the other cards burn to ash while yours rises,
## flares gold and bursts into sparks; then the boon is granted.
func _claim(chosen: Button, id: String) -> void:
	if claiming:
		return
	claiming = true
	Sfx.play("choose", null, -9.0, 1.0, 0.0)
	for b in items:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.set_meta("dealing", true)
		var fr: ColorRect = b.get_node("Frame")
		var mat := fr.material as ShaderMaterial
		var tw := b.create_tween()
		tw.set_parallel(true)
		if b == chosen:
			b.z_index = 5
			b.pivot_offset = b.size * 0.5
			tw.tween_property(b, "rotation", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(b, "scale", Vector2.ONE * 1.18, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(b, "position:y", b.position.y - 40.0, 0.35).set_ease(Tween.EASE_OUT)
			tw.tween_method(func(v): mat.set_shader_parameter("flare", v), 0.0, 1.0, 0.25)
			tw.chain().tween_method(func(v): mat.set_shader_parameter("flare", v), 1.0, 0.25, 0.5)
			var sg: ColorRect = b.get_node_or_null("Sigil")
			if sg:
				(sg.material as ShaderMaterial).set_shader_parameter("intensity", 2.2)
			_sparks(b.position + b.size * 0.5)
		else:
			tw.tween_method(func(v): mat.set_shader_parameter("burn", v), 0.0, 1.0, 0.85).set_ease(Tween.EASE_IN)
			for ch in b.get_children():
				if ch is Label or ch.name == "Sigil":
					tw.tween_property(ch, "modulate:a", 0.0, 0.45)
			tw.tween_property(b, "position:y", b.position.y + 30.0, 0.85).set_ease(Tween.EASE_IN)
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1.0, 0.75, 0.35, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var ft := flash.create_tween()
	ft.tween_property(flash, "color:a", 0.35, 0.12)
	ft.tween_property(flash, "color:a", 0.0, 0.6)
	await get_tree().create_timer(1.05, true, false, true).timeout
	picked.emit(id)


func _sparks(at: Vector2) -> void:
	var stage: Control = items[0].get_parent()
	for k in 2:
		var p := CPUParticles2D.new()
		p.one_shot = true
		p.emitting = false
		p.amount = 90 if k == 0 else 40
		p.lifetime = 1.1
		p.explosiveness = 0.95
		p.spread = 180.0
		p.initial_velocity_min = 160.0 if k == 0 else 40.0
		p.initial_velocity_max = 520.0 if k == 0 else 160.0
		p.gravity = Vector2(0, 260.0 if k == 0 else -60.0)
		p.damping_min = 40.0
		p.damping_max = 120.0
		p.scale_amount_min = 2.0
		p.scale_amount_max = 5.0
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
		g.set_color(1, Color(1.0, 0.4, 0.1, 0.0))
		p.color_ramp = g
		p.position = at
		p.z_index = 6
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		stage.add_child(p)
		p.emitting = true


# ------------------------------------------------------------ hover animation

func _process(delta: float) -> void:
	for b in items:
		if not is_instance_valid(b) or b.get_meta("dealing", false):
			continue
		var target: float = hover_amt.get(b, 0.0)
		var cur: float = b.get_meta("h", 0.0)
		cur = move_toward(cur, target, delta * 6.0)
		b.set_meta("h", cur)
		var e := ease(cur, -2.0)
		var sg: ColorRect = b.get_node_or_null("Sigil")
		if sg:
			(sg.material as ShaderMaterial).set_shader_parameter("intensity", 0.4 + e * 1.4 + sin(Time.get_ticks_msec() * 0.004) * 0.1 * e)
		var fr: ColorRect = b.get_node_or_null("Frame")
		if fr:
			(fr.material as ShaderMaterial).set_shader_parameter("hover", e)
		if b.has_meta("base_y"):
			b.position.y = b.get_meta("base_y") - 18.0 * e
			b.scale = Vector2.ONE * (1.0 + 0.04 * e)
