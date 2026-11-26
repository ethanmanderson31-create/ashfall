extends Control
## Esc menu: graphics, mouse and keybind settings in the tarot style.

var f_title: SystemFont
var f_body: SystemFont
var waiting_action := ""
var waiting_button: Button
var bind_buttons := {}
var sens_label: Label
var quality_buttons: Array[Button] = []

const GOLD := Color(1.0, 0.82, 0.48)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	f_title = SystemFont.new()
	f_title.font_names = PackedStringArray(["Luminari", "Georgia"])
	f_body = SystemFont.new()
	f_body.font_names = PackedStringArray(["Iowan Old Style", "Baskerville", "Georgia"])


func open() -> void:
	for c in get_children():
		c.queue_free()
	bind_buttons.clear()
	quality_buttons.clear()
	_build()
	Sfx.play("ui", null, -4.0)
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	waiting_action = ""
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _lbl(parent: Node, text: String, f: Font, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _btn(parent: Node, text: String, cb: Callable, w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", f_body)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	for st in [["normal", 0.08, 0.35], ["hover", 0.14, 0.8], ["pressed", 0.18, 1.0]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(st[1], st[1] * 0.8, st[1] * 0.7, 0.95)
		sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, st[2])
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		b.add_theme_stylebox_override(st[0], sb)
	if w > 0.0:
		b.custom_minimum_size.x = w
	b.pressed.connect(func(): Sfx.play("ui", null, -4.0))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _section(parent: Node, text: String) -> void:
	var sp := Control.new()
	sp.custom_minimum_size.y = 10
	parent.add_child(sp)
	_lbl(parent, text, f_title, 24, GOLD)
	var rule := ColorRect.new()
	rule.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.35)
	rule.custom_minimum_size = Vector2(0, 1)
	parent.add_child(rule)


func _row(parent: Node, label: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	parent.add_child(h)
	var l := _lbl(h, label, f_body, 17, Color(0.9, 0.86, 0.78))
	l.custom_minimum_size.x = 220
	return h


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.015, 0.01, 0.82)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -440
	panel.offset_right = 440
	panel.offset_top = -380
	panel.offset_bottom = 380
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.05, 0.97)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)
	var title := _lbl(outer, "Paused", f_title, 44, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(800, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)

	_section(v, "Graphics")
	var q := _row(v, "Quality")
	for i in Settings.PRESETS.size():
		var idx := i
		var b := _btn(q, Settings.PRESETS[i], func():
			Settings.set_quality(idx)
			Settings.save()
			_mark_quality(), 100)
		quality_buttons.append(b)
	_mark_quality()
	var fs := _row(v, "Fullscreen")
	var fsb := CheckButton.new()
	fsb.button_pressed = Settings.fullscreen
	fsb.focus_mode = Control.FOCUS_NONE
	fsb.toggled.connect(func(on):
		Settings.fullscreen = on
		Settings.apply_window()
		Settings.save())
	fs.add_child(fsb)
	var fp := _row(v, "Show FPS")
	var fpb := CheckButton.new()
	fpb.button_pressed = Settings.show_fps
	fpb.focus_mode = Control.FOCUS_NONE
	fpb.toggled.connect(func(on):
		Settings.show_fps = on
		Settings.save())
	fp.add_child(fpb)

	_section(v, "Audio")
	for a in [["Master volume", "vol_master"], ["Effects", "vol_effects"], ["Creatures", "vol_creatures"], ["Ambience", "vol_ambience"]]:
		var key: String = a[1]
		var row := _row(v, a[0])
		var sl2 := HSlider.new()
		sl2.min_value = 0.0
		sl2.max_value = 1.0
		sl2.step = 0.01
		sl2.value = Settings.get(key)
		sl2.custom_minimum_size = Vector2(340, 24)
		sl2.focus_mode = Control.FOCUS_NONE
		row.add_child(sl2)
		var pct := _lbl(row, "%d%%" % roundi(Settings.get(key) * 100.0), f_body, 17, GOLD)
		sl2.value_changed.connect(func(val):
			Settings.set(key, val)
			pct.text = "%d%%" % roundi(val * 100.0)
			Sfx.apply_volumes()
			Settings.save())
		sl2.drag_ended.connect(func(_c): Sfx.play("ui"))

	_section(v, "Controls")
	var sr := _row(v, "Mouse sensitivity")
	var sl := HSlider.new()
	sl.min_value = 0.2
	sl.max_value = 3.0
	sl.step = 0.05
	sl.value = Settings.sensitivity
	sl.custom_minimum_size = Vector2(340, 24)
	sl.focus_mode = Control.FOCUS_NONE
	sr.add_child(sl)
	sens_label = _lbl(sr, "%.2fx" % Settings.sensitivity, f_body, 17, GOLD)
	sl.value_changed.connect(func(val):
		Settings.sensitivity = val
		sens_label.text = "%.2fx" % val
		Settings.save())
	var iy := _row(v, "Invert vertical look")
	var iyb := CheckButton.new()
	iyb.button_pressed = Settings.invert_y
	iyb.focus_mode = Control.FOCUS_NONE
	iyb.toggled.connect(func(on):
		Settings.invert_y = on
		Settings.save())
	iy.add_child(iyb)

	_section(v, "Keybinds")
	_lbl(v, "Click a binding, then press the new key or mouse button. Esc cancels.", f_body, 14, Color(1, 1, 1, 0.5))
	for r in Settings.REBINDABLE:
		var action: String = r[0]
		var row := _row(v, r[1])
		var b: Button
		b = _btn(row, Settings.action_label(action), func(): _start_rebind(action, b), 260)
		bind_buttons[action] = b
	var rb := HBoxContainer.new()
	v.add_child(rb)
	_btn(rb, "Reset keybinds to defaults", func():
		Settings.reset_bindings()
		_refresh_binds())

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 16)
	outer.add_child(bottom)
	_btn(bottom, "Resume", close, 160)
	_btn(bottom, "New run", func():
		get_tree().paused = false
		Engine.time_scale = 1.0
		get_tree().reload_current_scene(), 160)
	_btn(bottom, "Quit to desktop", func(): get_tree().quit(), 180)


func _mark_quality() -> void:
	for i in quality_buttons.size():
		var b := quality_buttons[i]
		b.add_theme_color_override("font_color", GOLD if i == Settings.quality else Color(0.95, 0.9, 0.8, 0.6))
		b.text = ("✦ " if i == Settings.quality else "") + Settings.PRESETS[i]


func _start_rebind(action: String, b: Button) -> void:
	waiting_action = action
	waiting_button = b
	b.text = "Press a key…"


func _refresh_binds() -> void:
	for a in bind_buttons:
		(bind_buttons[a] as Button).text = Settings.action_label(a)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if waiting_action == "":
		if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		return
	var ok := false
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			waiting_action = ""
			_refresh_binds()
			get_viewport().set_input_as_handled()
			return
		ok = true
	elif event is InputEventMouseButton and event.pressed:
		ok = true
	if ok:
		Settings.rebind(waiting_action, event)
		waiting_action = ""
		_refresh_binds()
		get_viewport().set_input_as_handled()
