extends CanvasLayer
## Title card shown while a run's world is generated and shaders warm up.

const TIPS := [
	"Out of ammo? Your blade never runs dry. Press F, or keep holding fire.",
	"Invest 2 points in a branch to open its next tier. Keystones wait at tier IV.",
	"Clearing a husk camp opens an Ember Cache: a free boon, ammo and health.",
	"Dodging (C) makes you briefly untouchable. Time it on a husk's wind-up glow.",
	"Every run builds a new world and offers different boons. No two builds alike.",
	"Elites glow violet. They hit hard but drop a full ammo crate.",
	"Blademasters can double jump, then press F midair to slam the ground.",
]

var bar: ColorRect
var step_label: Label
var bg: ColorRect
const BAR_W := 520.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fb := SystemFont.new()
	fb.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Arial"])
	fb.font_weight = 700
	var fr := SystemFont.new()
	fr.font_names = fb.font_names

	bg = ColorRect.new()
	bg.color = Color(0.035, 0.03, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var glow := ColorRect.new()
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	float d = length((UV - vec2(0.5, 0.62)) * vec2(1.6, 1.0));
	float flicker = 0.9 + 0.1 * sin(TIME * 3.0) * sin(TIME * 1.7);
	COLOR = vec4(1.0, 0.38, 0.1, (1.0 - smoothstep(0.0, 0.6, d)) * 0.22 * flicker);
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	glow.material = sm
	bg.add_child(glow)

	var title := _label(bg, "ASHFALL", 96, fb, Color(1.0, 0.72, 0.4))
	_band(title, 0.5, -170, 110)
	var sub := _label(bg, "RUN %d   ·   ACT I  —  THE VERDANT RUINS" % Game.run_count, 18, fb, Color(1, 1, 1, 0.7))
	_band(sub, 0.5, -50, 26)

	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.1)
	track.anchor_left = 0.5
	track.anchor_right = 0.5
	track.anchor_top = 0.5
	track.anchor_bottom = 0.5
	track.offset_left = -BAR_W * 0.5
	track.offset_right = BAR_W * 0.5
	track.offset_top = 20
	track.offset_bottom = 24
	bg.add_child(track)
	bar = ColorRect.new()
	bar.color = Color(1.0, 0.55, 0.2)
	bar.size = Vector2(0, 4)
	track.add_child(bar)
	step_label = _label(bg, "", 14, fb, Color(1, 1, 1, 0.5))
	_band(step_label, 0.5, 34, 20)

	var tip := _label(bg, "TIP   " + TIPS[randi() % TIPS.size()], 16, fr, Color(1, 1, 1, 0.6))
	_band(tip, 1.0, -80, 24)


func _label(parent: Node, text: String, size: int, f: Font, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _band(c: Control, ay: float, y: float, h: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_top = y
	c.offset_bottom = y + h


func step(text: String, progress: float) -> void:
	step_label.text = text.to_upper()
	bar.size.x = BAR_W * progress
	# Two frames so the card actually redraws before the next heavy step.
	await get_tree().process_frame
	await get_tree().process_frame


func finish() -> void:
	var tw := create_tween()
	tw.tween_property(bg, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)
