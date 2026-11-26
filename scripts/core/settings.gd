extends Node
## Graphics quality presets (F1 cycles them in game). The choice is saved to
## user://settings.cfg so the exported app remembers it between launches.

const PRESETS := ["Low", "Medium", "High", "Ultra"]
const PATH := "user://settings.cfg"

var quality := 2
var show_fps := true
var sensitivity := 1.0
var invert_y := false
var vol_master := 0.8
var vol_effects := 0.9
var vol_creatures := 0.7
var vol_ambience := 0.6
var fullscreen := false
var bindings := {}                 ## action -> [{"k": keycode} | {"m": button}]
var _defaults := {}

const REBINDABLE := [
	["move_forward", "Move forward"], ["move_back", "Move back"], ["move_left", "Move left"], ["move_right", "Move right"],
	["sprint", "Sprint"], ["jump", "Jump"], ["dodge", "Dodge"], ["fire", "Fire / swing"], ["aim", "Aim"],
	["melee", "Quick axe swing"], ["reload", "Reload"], ["interact", "Interact"],
	["use_1", "Potion slot 1"], ["use_2", "Potion slot 2"], ["use_3", "Potion slot 3"],
]


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		quality = clampi(int(cfg.get_value("graphics", "quality", quality)), 0, PRESETS.size() - 1)
		show_fps = bool(cfg.get_value("graphics", "show_fps", show_fps))
		fullscreen = bool(cfg.get_value("graphics", "fullscreen", fullscreen))
		sensitivity = float(cfg.get_value("controls", "sensitivity", sensitivity))
		invert_y = bool(cfg.get_value("controls", "invert_y", invert_y))
		vol_master = float(cfg.get_value("audio", "master", vol_master))
		vol_effects = float(cfg.get_value("audio", "effects", vol_effects))
		vol_creatures = float(cfg.get_value("audio", "creatures", vol_creatures))
		vol_ambience = float(cfg.get_value("audio", "ambience", vol_ambience))
		bindings = cfg.get_value("controls", "bindings", {})


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "quality", quality)
	cfg.set_value("graphics", "show_fps", show_fps)
	cfg.set_value("graphics", "fullscreen", fullscreen)
	cfg.set_value("controls", "sensitivity", sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("audio", "master", vol_master)
	cfg.set_value("audio", "effects", vol_effects)
	cfg.set_value("audio", "creatures", vol_creatures)
	cfg.set_value("audio", "ambience", vol_ambience)
	cfg.set_value("controls", "bindings", bindings)
	cfg.save(PATH)


func cycle() -> void:
	quality = (quality + 1) % PRESETS.size()
	apply()
	save()


func set_quality(q: int) -> void:
	quality = clampi(q, 0, PRESETS.size() - 1)
	apply()


func preset_name() -> String:
	return PRESETS[quality]


## Applies the current preset to the live world (environment, sun, grass,
## render resolution). Safe to call any time after the world is built.
func apply() -> void:
	var vp := get_viewport()
	var env: Environment = Game.env
	var sun: DirectionalLight3D = Game.sun
	if env == null or sun == null:
		return
	var q := quality
	# Retina screens render at 2x pixels; scale 3D down and let FSR upscale.
	var hidpi := DisplayServer.screen_get_scale() > 1.5
	var scales := [0.5, 0.6, 0.75, 1.0] if hidpi else [0.67, 0.8, 1.0, 1.0]
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scales[q] < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = scales[q]
	vp.fsr_sharpness = 0.4
	vp.use_taa = q >= 2
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q < 2 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.msaa_3d = Viewport.MSAA_DISABLED

	env.sdfgi_enabled = q >= 3
	env.ssil_enabled = q >= 3
	env.ssao_enabled = q >= 1
	env.volumetric_fog_enabled = q >= 2
	env.fog_density = 0.0012 if q >= 2 else 0.0022
	env.glow_enabled = true
	env.ambient_light_energy = 0.65 if q >= 3 else 0.85

	var shadow_sizes := [2048, 4096, 4096, 8192]
	RenderingServer.directional_shadow_atlas_set_size(shadow_sizes[q], true)
	sun.directional_shadow_max_distance = [70.0, 100.0, 130.0, 140.0][q]
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q == 0 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.light_angular_distance = 0.8 if q >= 2 else 0.0
	RenderingServer.directional_soft_shadow_filter_set_quality(
		[RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][q])

	for l in get_tree().get_nodes_in_group("fire_lights"):
		(l as OmniLight3D).shadow_enabled = q >= 3
	var grass_range: float = [32.0, 48.0, 65.0, 75.0][q]
	if Game.grass_holder:
		for c in Game.grass_holder.get_children():
			(c as GeometryInstance3D).visibility_range_end = grass_range


# ------------------------------------------------------------ input bindings

static func ser(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"k": (ev as InputEventKey).physical_keycode}
	if ev is InputEventMouseButton:
		return {"m": (ev as InputEventMouseButton).button_index}
	return {}


static func deser(d: Dictionary) -> InputEvent:
	if d.has("k"):
		var e := InputEventKey.new()
		e.physical_keycode = int(d.k)
		return e
	var m := InputEventMouseButton.new()
	m.button_index = int(d.m)
	return m


static func event_name(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	if ev is InputEventMouseButton:
		var names := {1: "Left mouse", 2: "Right mouse", 3: "Middle mouse", 4: "Wheel up", 5: "Wheel down", 8: "Mouse 4", 9: "Mouse 5"}
		return names.get((ev as InputEventMouseButton).button_index, "Mouse")
	return "?"


func action_label(action: String) -> String:
	var evs := InputMap.action_get_events(action)
	var parts: Array[String] = []
	for e in evs:
		parts.append(event_name(e))
	return " / ".join(parts) if not parts.is_empty() else "unbound"


## Call once after the default input map is built.
func apply_bindings() -> void:
	if _defaults.is_empty():
		for r in REBINDABLE:
			var arr := []
			for e in InputMap.action_get_events(r[0]):
				arr.append(ser(e))
			_defaults[r[0]] = arr
	for action in bindings:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
			for d in bindings[action]:
				InputMap.action_add_event(action, deser(d))


func rebind(action: String, ev: InputEvent) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, ev)
	bindings[action] = [ser(ev)]
	save()


func reset_bindings() -> void:
	bindings.clear()
	for action in _defaults:
		InputMap.action_erase_events(action)
		for d in _defaults[action]:
			InputMap.action_add_event(action, deser(d))
	save()


func apply_window() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
