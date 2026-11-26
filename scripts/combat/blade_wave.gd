extends Node3D
## Bladestorm keystone: a crescent of fire that flies forward and cuts
## every husk it passes through once.

var damage := 20.0
var dir := Vector3.FORWARD
var side := 1.0
var life := 0.75
var hit: Array = []
var mat: StandardMaterial3D
static var _mesh: ArrayMesh


func _ready() -> void:
	if _mesh == null:
		_mesh = preload("res://scripts/player/player.gd").make_arc_mesh(0.9, 1.6, deg_to_rad(110.0))
	mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(2.5, 0.9, 0.4)
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = -Vector3(0, 0, -1.0)
	add_child(mi)
	basis = Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.FORWARD, 0.35 * side)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.2)
	l.light_energy = 2.0
	l.omni_range = 4.0
	add_child(l)


func _physics_process(delta: float) -> void:
	life -= delta
	global_position += dir * 22.0 * delta
	mat.albedo_color.a = clampf(life / 0.3, 0.0, 1.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.state == "dead" or e in hit:
			continue
		var to: Vector3 = e.global_position + Vector3(0, 1.0, 0) - global_position
		if Vector2(to.x, to.z).length() < 1.8 and absf(to.y) < 1.8:
			hit.append(e)
			var killed: bool = e.take_damage(damage, e.global_position + Vector3(0, 1.2, 0), dir, false, 5.0)
			Game.player.hit_enemy.emit(killed, false)
			if killed:
				Game.player._on_kill(true)
	if life <= 0.0:
		queue_free()
