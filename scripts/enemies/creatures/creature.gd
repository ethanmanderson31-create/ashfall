class_name Creature
extends Node3D
## A procedurally built ash creature: a skeleton of Node3D joints dressed in
## organic meshes, animated by code (locomotion cycles + keyframed attack
## clips + hit reactions + death dissolve). AI drives it through `speed`,
## `look_at_point`, attack() and die(); `attack_impact` fires on the exact
## frame a blow lands so damage lines up with the animation.

signal attack_impact(clip: String)

const P := preload("res://scripts/enemies/creatures/creature_parts.gd")

var kind := "ghoul"
var speed := 0.0
var run_speed := 5.0
var look_at_point := Vector3.ZERO
var has_look := false
var phase := 0.0
var t := 0.0
var hit := 0.0
var hit_side := 1.0
var dead := false
var death_t := 0.0
var freeze_a := -1.0          ## debug: hold an attack clip at this progress
var crouch := 0.0             ## 0..1 snarling crouch before a bite
var _step_half := 0

var j := {}                   ## joints by name
var rest := {}                ## name -> [rotation, position, scale]
var flesh_mat: ShaderMaterial
var glow_mat: ShaderMaterial
var clip_name := ""
var clip: Dictionary = {}
var attack_a := -1.0
var impact_fired := false
var base_h := 1.0


# ============================================================ clips
# Each clip: duration (s), impact (0..1), channels "joint:axis" -> keys
# [[time, value], ...]. Axes x/y/z add rotation, py adds to position.y,
# s sets uniform scale. Values are offsets from the locomotion pose.

const CLIPS := {
	"ghoul": {
		"swipe_r": {"dur": 0.95, "impact": 0.52, "ch": {
			"shoulder_R:x": [[0, 0], [0.42, -2.6], [0.55, 1.3], [0.75, 1.0], [1, 0]],
			"shoulder_R:z": [[0, 0], [0.42, 0.55], [0.55, -0.7], [1, 0]],
			"elbow_R:x": [[0, 0], [0.42, 1.5], [0.55, 0.1], [1, 0]],
			"chest:y": [[0, 0], [0.42, 0.6], [0.55, -0.55], [1, 0]],
			"spine:x": [[0, 0], [0.42, 0.2], [0.55, -0.4], [1, 0]],
			"jaw:x": [[0, 0], [0.42, -0.55], [0.65, -0.1], [1, 0]]}},
		"swipe_l": {"dur": 0.95, "impact": 0.52, "ch": {
			"shoulder_L:x": [[0, 0], [0.42, -2.6], [0.55, 1.3], [0.75, 1.0], [1, 0]],
			"shoulder_L:z": [[0, 0], [0.42, -0.55], [0.55, 0.7], [1, 0]],
			"elbow_L:x": [[0, 0], [0.42, 1.5], [0.55, 0.1], [1, 0]],
			"chest:y": [[0, 0], [0.42, -0.6], [0.55, 0.55], [1, 0]],
			"spine:x": [[0, 0], [0.42, 0.2], [0.55, -0.4], [1, 0]],
			"jaw:x": [[0, 0], [0.42, -0.55], [0.65, -0.1], [1, 0]]}},
	},
	"brute": {
		"shove": {"dur": 1.15, "impact": 0.5, "ch": {
			"shoulder_L:x": [[0, 0], [0.4, -0.9], [0.5, 1.5], [0.7, 1.5], [1, 0]],
			"shoulder_R:x": [[0, 0], [0.4, -0.9], [0.5, 1.5], [0.7, 1.5], [1, 0]],
			"elbow_L:x": [[0, 0], [0.4, 1.7], [0.5, 0.05], [1, 0]],
			"elbow_R:x": [[0, 0], [0.4, 1.7], [0.5, 0.05], [1, 0]],
			"spine:x": [[0, 0], [0.4, 0.3], [0.5, -0.45], [0.7, -0.35], [1, 0]],
			"hips:py": [[0, 0], [0.4, -0.15], [0.5, 0.0], [1, 0]],
			"jaw:x": [[0, 0], [0.45, -0.5], [0.7, -0.4], [1, 0]]}},
		"slam": {"dur": 1.5, "impact": 0.56, "ch": {
			"shoulder_L:x": [[0, 0], [0.45, -3.0], [0.56, 0.7], [0.8, 0.7], [1, 0]],
			"shoulder_R:x": [[0, 0], [0.45, -3.0], [0.56, 0.7], [0.8, 0.7], [1, 0]],
			"shoulder_L:z": [[0, 0], [0.45, -0.3], [0.56, 0.15], [1, 0]],
			"shoulder_R:z": [[0, 0], [0.45, 0.3], [0.56, -0.15], [1, 0]],
			"elbow_L:x": [[0, 0], [0.45, 0.7], [0.56, 0.0], [1, 0]],
			"elbow_R:x": [[0, 0], [0.45, 0.7], [0.56, 0.0], [1, 0]],
			"spine:x": [[0, 0], [0.45, 0.45], [0.56, -0.7], [0.8, -0.6], [1, 0]],
			"hips:py": [[0, 0], [0.45, 0.08], [0.56, -0.3], [0.8, -0.25], [1, 0]],
			"jaw:x": [[0, 0], [0.45, -0.6], [1, 0]]}},
	},
	"hound": {
		"pounce": {"dur": 1.0, "impact": 0.5, "ch": {
			"body:x": [[0, 0], [0.35, 0.22], [0.46, -0.4], [0.62, 0.15], [1, 0]],
			"body:py": [[0, 0], [0.35, -0.22], [0.46, 0.35], [0.62, 0.0], [1, 0]],
			"leg_FL:x": [[0, 0], [0.35, -0.5], [0.46, 1.3], [0.62, 0.4], [1, 0]],
			"leg_FR:x": [[0, 0], [0.35, -0.5], [0.46, 1.3], [0.62, 0.4], [1, 0]],
			"leg_BL:x": [[0, 0], [0.35, 0.6], [0.46, -1.1], [0.62, -0.2], [1, 0]],
			"leg_BR:x": [[0, 0], [0.35, 0.6], [0.46, -1.1], [0.62, -0.2], [1, 0]],
			"neck:x": [[0, 0], [0.35, 0.3], [0.5, -0.3], [1, 0]],
			"jaw:x": [[0, 0], [0.3, -0.2], [0.46, -0.9], [0.55, 0.0], [1, 0]]}},
		"bite": {"dur": 0.6, "impact": 0.42, "ch": {
			"neck:x": [[0, 0], [0.3, 0.35], [0.45, -0.45], [1, 0]],
			"body:x": [[0, 0], [0.3, 0.1], [0.45, -0.1], [1, 0]],
			"jaw:x": [[0, 0], [0.3, -0.9], [0.45, 0.0], [1, 0]]}},
	},
	"spitter": {
		"spit": {"dur": 1.25, "impact": 0.56, "ch": {
			"body:x": [[0, 0], [0.45, -0.55], [0.58, -0.15], [1, 0]],
			"body:py": [[0, 0], [0.45, 0.18], [0.6, 0.0], [1, 0]],
			"sac:s": [[0, 1], [0.45, 1.25], [0.58, 0.88], [0.8, 1.0], [1, 1]],
			"head:x": [[0, 0], [0.45, -0.35], [0.58, 0.3], [1, 0]],
			"jaw:y": [[0, 0], [0.45, 0.5], [0.6, 0.1], [1, 0]]}},
	},
}


func setup(k: String) -> void:
	kind = k


func _ready() -> void:
	flesh_mat = _new_flesh(0.55)
	match kind:
		"ghoul":
			_build_ghoul()
		"hound":
			_build_hound()
		"brute", "colossus":
			_build_brute(kind == "colossus")
		"spitter":
			_build_spitter()
	for n in j:
		var node: Node3D = j[n]
		rest[n] = [node.rotation, node.position, node.scale]
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	phase = randf() * TAU
	t = randf() * 10.0


func _new_flesh(crack: float, energy := 5.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/creatures/ember_flesh.gdshader")
	m.set_shader_parameter("crack_amount", crack)
	m.set_shader_parameter("ember_energy", energy)
	return m


func _j(parent: Node3D, n: String, pos: Vector3, rot := Vector3.ZERO) -> Node3D:
	var node := P.joint(parent, n, pos, rot)
	j[n] = node
	return node


func _eyes(head: Node3D, pos: Vector3, r: float, spread: float) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	for side in [-1.0, 1.0]:
		P.part(head, s, P.eye(), pos + Vector3(spread * side, 0, 0))


# ============================================================ builds

func _build_ghoul() -> void:
	run_speed = 5.5
	base_h = 1.02
	var hips := _j(self, "hips", Vector3(0, base_h, 0))
	P.part(hips, P.blob(Vector3(0.2, 0.15, 0.15), 1), flesh_mat)
	var spine := _j(hips, "spine", Vector3(0, 0.06, 0), Vector3(-0.45, 0, 0))
	P.part(spine, P.blob(Vector3(0.15, 0.3, 0.12), 2, 0.22), flesh_mat, Vector3(0, 0.26, 0))
	var chest := _j(spine, "chest", Vector3(0, 0.5, 0))
	P.part(chest, P.blob(Vector3(0.27, 0.2, 0.18), 3, 0.2), flesh_mat, Vector3(0, 0.08, 0))
	for i in 4:
		P.part(spine if i < 2 else chest, P.horn(0.16 - i * 0.015, 0.03, 0.0, 40 + i), P.bone(),
			Vector3(0, 0.15 + i * 0.16 - (0.5 if i >= 2 else 0.0), 0.13), Vector3(-2.1, 0, 0))
	var neck := _j(chest, "neck", Vector3(0, 0.24, -0.04), Vector3(0.75, 0, 0))
	P.part(neck, P.limb(0.2, 0.065, 0.06, 5, 0.1), flesh_mat, Vector3.ZERO, Vector3(PI, 0, 0))
	var head := _j(neck, "head", Vector3(0, 0.2, 0), Vector3(-0.3, 0, 0))
	P.part(head, P.blob(Vector3(0.12, 0.13, 0.17), 6, 0.18), flesh_mat, Vector3(0, 0.05, -0.04))
	P.part(head, P.blob(Vector3(0.11, 0.04, 0.06), 7, 0.1), P.bone(), Vector3(0, 0.1, -0.13))
	_eyes(head, Vector3(0, 0.075, -0.175), 0.012, 0.045)
	var jaw := _j(head, "jaw", Vector3(0, -0.01, -0.02))
	P.part(jaw, P.blob(Vector3(0.09, 0.045, 0.14), 8, 0.12), flesh_mat, Vector3(0, -0.05, -0.1))
	for i in 5:
		P.part(jaw, P.horn(0.05, 0.012, 0.0, 60 + i), P.bone(), Vector3(-0.06 + i * 0.03, -0.02, -0.2 + absf(i - 2) * 0.03), Vector3(PI, 0, 0))
	for side in [-1.0, 1.0]:
		var s := "R" if side > 0 else "L"
		var sh := _j(chest, "shoulder_" + s, Vector3(0.28 * side, 0.13, 0), Vector3(0.25, 0, 0.1 * side))
		P.part(sh, P.blob(Vector3(0.1, 0.09, 0.1), 9), flesh_mat)
		P.part(sh, P.limb(0.5, 0.075, 0.048, 10 + int(side), 0.35), flesh_mat)
		var el := _j(sh, "elbow_" + s, Vector3(0, -0.5, 0), Vector3(0.35, 0, 0))
		P.part(el, P.limb(0.48, 0.055, 0.035, 12 + int(side), 0.2), flesh_mat)
		var hand := _j(el, "hand_" + s, Vector3(0, -0.48, 0))
		P.part(hand, P.blob(Vector3(0.05, 0.07, 0.035), 14), flesh_mat, Vector3(0, -0.04, 0))
		for c in 3:
			P.part(hand, P.horn(0.24, 0.016, -0.35, 70 + c), P.bone(), Vector3(-0.03 + c * 0.03, -0.09, -0.01), Vector3(0.1, 0, 0))
		var th := _j(hips, "thigh_" + s, Vector3(0.12 * side, -0.02, 0))
		P.part(th, P.limb(0.5, 0.085, 0.055, 16, 0.3), flesh_mat)
		var kn := _j(th, "knee_" + s, Vector3(0, -0.5, 0))
		P.part(kn, P.limb(0.47, 0.058, 0.038, 18, 0.2), flesh_mat)
		var an := _j(kn, "ankle_" + s, Vector3(0, -0.47, 0))
		P.part(an, P.blob(Vector3(0.055, 0.035, 0.12), 19), flesh_mat, Vector3(0, -0.02, -0.06))


func _build_brute(colossus: bool) -> void:
	run_speed = 3.6
	base_h = 1.12
	flesh_mat = _new_flesh(0.75 if colossus else 0.45, 6.0 if colossus else 5.0)
	var hips := _j(self, "hips", Vector3(0, base_h, 0))
	P.part(hips, P.blob(Vector3(0.32, 0.22, 0.25), 21), flesh_mat)
	var spine := _j(hips, "spine", Vector3(0, 0.1, 0), Vector3(-0.55, 0, 0))
	P.part(spine, P.blob(Vector3(0.36, 0.32, 0.3), 22, 0.18), flesh_mat, Vector3(0, 0.3, 0))
	var chest := _j(spine, "chest", Vector3(0, 0.6, 0))
	P.part(chest, P.blob(Vector3(0.56, 0.38, 0.38), 23, 0.2), flesh_mat, Vector3(0, 0.1, 0))
	for side in [-1.0, 1.0]:
		P.part(chest, P.blob(Vector3(0.26, 0.09, 0.28), 24, 0.3), P.bone(), Vector3(0.48 * side, 0.36, 0.02), Vector3(0, 0, 0.45 * side))
	for i in 5:
		P.part(chest if i < 3 else spine, P.horn(0.3 - i * 0.03, 0.06, 0.0, 80 + i), P.bone(),
			Vector3((i % 2 - 0.5) * 0.25, 0.4 - i * 0.18 + (0.6 if i >= 3 else 0.0), 0.28), Vector3(-2.2, 0, 0))
	var neck := _j(chest, "neck", Vector3(0, 0.3, -0.22), Vector3(0.9, 0, 0))
	var head := _j(neck, "head", Vector3(0, 0.1, -0.05), Vector3(-0.2, 0, 0))
	P.part(head, P.blob(Vector3(0.17, 0.16, 0.19), 25, 0.15), flesh_mat, Vector3(0, 0.05, -0.05))
	P.part(head, P.blob(Vector3(0.17, 0.05, 0.08), 26), P.bone(), Vector3(0, 0.13, -0.15))
	_eyes(head, Vector3(0, 0.09, -0.2), 0.016, 0.065)
	for side in [-1.0, 1.0]:
		P.part(head, P.horn(0.28 if colossus else 0.18, 0.04, 0.4, 27), P.bone(), Vector3(0.12 * side, 0.15, -0.05), Vector3(-2.6, 0, -0.5 * side))
	var jaw := _j(head, "jaw", Vector3(0, -0.02, -0.02))
	P.part(jaw, P.blob(Vector3(0.15, 0.07, 0.16), 28, 0.12), flesh_mat, Vector3(0, -0.07, -0.1))
	for i in 2:
		P.part(jaw, P.horn(0.1, 0.022, -0.2, 29), P.bone(), Vector3(-0.08 + i * 0.16, -0.04, -0.2), Vector3(PI, 0, 0))
	for side in [-1.0, 1.0]:
		var s := "R" if side > 0 else "L"
		var sh := _j(chest, "shoulder_" + s, Vector3(0.6 * side, 0.18, 0), Vector3(0.5, 0, 0.22 * side))
		P.part(sh, P.blob(Vector3(0.2, 0.2, 0.2), 30), flesh_mat)
		P.part(sh, P.limb(0.62, 0.16, 0.12, 31, 0.45), flesh_mat)
		var el := _j(sh, "elbow_" + s, Vector3(0, -0.62, 0), Vector3(0.35, 0, 0))
		P.part(el, P.limb(0.62, 0.15, 0.13, 32, 0.4), flesh_mat)
		var hand := _j(el, "hand_" + s, Vector3(0, -0.62, 0))
		P.part(hand, P.blob(Vector3(0.16, 0.14, 0.17), 33, 0.2), flesh_mat, Vector3(0, -0.08, 0))
		var th := _j(hips, "thigh_" + s, Vector3(0.22 * side, -0.05, 0), Vector3(0.25, 0, 0))
		P.part(th, P.limb(0.48, 0.17, 0.12, 34, 0.35), flesh_mat)
		var kn := _j(th, "knee_" + s, Vector3(0, -0.48, 0), Vector3(-0.45, 0, 0))
		P.part(kn, P.limb(0.46, 0.12, 0.09, 35, 0.25), flesh_mat)
		var an := _j(kn, "ankle_" + s, Vector3(0, -0.46, 0), Vector3(0.2, 0, 0))
		P.part(an, P.blob(Vector3(0.12, 0.06, 0.2), 36), flesh_mat, Vector3(0, -0.03, -0.08))
	if colossus:
		var crown := _j(head, "crown", Vector3(0, 0.2, 0))
		for i in 5:
			P.part(crown, P.horn(0.35, 0.035, 0.2, 90 + i), P.bone(), Vector3(-0.16 + i * 0.08, 0, 0.02), Vector3(-PI + 0.25, 0, (i - 2) * 0.25))
		glow_mat = _new_flesh(1.4, 9.0)
		P.part(chest, P.blob(Vector3(0.18, 0.18, 0.12), 99, 0.25), glow_mat, Vector3(0, 0.12, -0.34))


func _build_hound() -> void:
	run_speed = 9.0
	base_h = 0.84
	var body := _j(self, "body", Vector3(0, base_h, 0))
	P.part(body, P.blob(Vector3(0.2, 0.21, 0.5), 41, 0.18), flesh_mat, Vector3(0, 0.02, 0.02))
	P.part(body, P.blob(Vector3(0.24, 0.27, 0.3), 42, 0.2), flesh_mat, Vector3(0, 0.06, -0.33))
	P.part(body, P.blob(Vector3(0.19, 0.2, 0.25), 43, 0.15), flesh_mat, Vector3(0, 0.03, 0.36))
	for i in 6:
		P.part(body, P.horn(0.17 - i * 0.015, 0.03, 0.0, 44 + i), P.bone(), Vector3(0, 0.26 - absf(i - 2) * 0.02, -0.42 + i * 0.15), Vector3(-2.3, 0, 0))
	var neck := _j(body, "neck", Vector3(0, 0.16, -0.55), Vector3(0, 0, 0))
	P.part(neck, P.limb(0.34, 0.11, 0.085, 46, 0.2), flesh_mat, Vector3.ZERO, Vector3(2.15, 0, 0))
	var head := _j(neck, "head", Vector3(0, 0.15, -0.28), Vector3(0.15, 0, 0))
	P.part(head, P.blob(Vector3(0.12, 0.11, 0.16), 47, 0.15), flesh_mat, Vector3(0, 0, -0.04))
	P.part(head, P.blob(Vector3(0.065, 0.06, 0.15), 48, 0.12), flesh_mat, Vector3(0, -0.02, -0.25))
	_eyes(head, Vector3(0, 0.045, -0.15), 0.013, 0.07)
	for side in [-1.0, 1.0]:
		P.part(head, P.horn(0.26, 0.03, 0.55, 49), P.bone(), Vector3(0.07 * side, 0.08, 0.02), Vector3(-2.5, 0, -0.35 * side))
	var jaw := _j(head, "jaw", Vector3(0, -0.06, -0.08))
	P.part(jaw, P.blob(Vector3(0.055, 0.032, 0.17), 50, 0.1), flesh_mat, Vector3(0, -0.02, -0.15))
	for i in 4:
		P.part(jaw, P.horn(0.045, 0.01, 0.0, 51 + i), P.bone(), Vector3(-0.035 + (i % 2) * 0.07, 0.0, -0.22 + int(i / 2) * 0.08), Vector3(PI, 0, 0))
	var legs := {"FL": Vector3(-0.15, -0.04, -0.4), "FR": Vector3(0.15, -0.04, -0.4), "BL": Vector3(-0.14, -0.02, 0.4), "BR": Vector3(0.14, -0.02, 0.4)}
	for n in legs:
		var front: bool = n.begins_with("F")
		var up := _j(body, "leg_" + n, legs[n], Vector3(0.05 if front else 0.55, 0, 0))
		P.part(up, P.limb(0.36, 0.085 if front else 0.11, 0.05, 55, 0.35), flesh_mat)
		var lo := _j(up, "low_" + n, Vector3(0, -0.36, 0), Vector3(-0.05 if front else -1.0, 0, 0))
		P.part(lo, P.limb(0.38, 0.048, 0.032, 56, 0.15), flesh_mat)
		var paw := _j(lo, "paw_" + n, Vector3(0, -0.38, 0), Vector3(0 if front else 0.45, 0, 0))
		P.part(paw, P.blob(Vector3(0.05, 0.03, 0.08), 57), flesh_mat, Vector3(0, -0.01, -0.04))
		for c in 3:
			P.part(paw, P.horn(0.06, 0.01, -0.3, 58), P.bone(), Vector3(-0.03 + c * 0.03, -0.01, -0.1), Vector3(1.4, 0, 0))
	var tail := body
	for i in 5:
		tail = _j(tail, "tail_%d" % i, Vector3(0, 0.05, 0.58) if i == 0 else Vector3(0, -0.16, 0), Vector3(-1.9, 0, 0) if i == 0 else Vector3(0.18, 0, 0))
		P.part(tail, P.limb(0.17, 0.06 - i * 0.01, 0.05 - i * 0.01, 60 + i, 0.1), flesh_mat)


func _build_spitter() -> void:
	run_speed = 3.2
	base_h = 0.62
	glow_mat = _new_flesh(1.6, 8.0)
	var body := _j(self, "body", Vector3(0, base_h, 0))
	P.part(body, P.blob(Vector3(0.27, 0.19, 0.32), 71, 0.2), flesh_mat, Vector3(0, 0, -0.08))
	var sac := _j(body, "sac", Vector3(0, 0.12, 0.38))
	P.part(sac, P.blob(Vector3(0.38, 0.34, 0.46), 72, 0.22, 2.0), glow_mat, Vector3(0, 0.05, 0.12))
	for i in 5:
		P.part(sac, P.horn(0.14, 0.025, 0.0, 73 + i), P.bone(), Vector3((i - 2) * 0.13, 0.35 - absf(i - 2) * 0.05, 0.1), Vector3(-2.6, 0, (i - 2) * 0.3))
	var head := _j(body, "head", Vector3(0, 0.03, -0.4))
	P.part(head, P.blob(Vector3(0.15, 0.12, 0.16), 74, 0.15), flesh_mat, Vector3(0, 0, -0.06))
	_eyes(head, Vector3(0, 0.07, -0.18), 0.018, 0.05)
	_eyes(head, Vector3(0, 0.03, -0.2), 0.014, 0.09)
	var jaw := _j(head, "jaw", Vector3(0, -0.04, -0.15))
	for side in [-1.0, 1.0]:
		P.part(jaw, P.horn(0.2, 0.03, 0.25, 75), P.bone(), Vector3(0.06 * side, 0, -0.02), Vector3(-1.7, 0.35 * side, 0))
	var legs := [[-0.28, 0.65], [-0.06, 0.0], [0.16, -0.6]]
	var li := 0
	for side in [-1.0, 1.0]:
		for L in legs:
			var n := "%s%d" % ["R" if side > 0 else "L", li % 3]
			var hip := _j(body, "hip_" + n, Vector3(0.2 * side, -0.02, L[0]), Vector3(0, L[1] * side, 0))
			var fem := _j(hip, "fem_" + n, Vector3.ZERO, Vector3(0, 0, 2.27 * side))
			P.part(fem, P.limb(0.44, 0.06, 0.04, 76, 0.3), flesh_mat)
			var tib := _j(fem, "tib_" + n, Vector3(0, -0.44, 0), Vector3(0, 0, -1.97 * side))
			P.part(tib, P.limb(0.78, 0.04, 0.012, 77, 0.15), flesh_mat)
			li += 1


# ============================================================ animation

func attack(n: String) -> bool:
	if dead or attack_a >= 0.0 or not CLIPS.get(_clip_kind(), {}).has(n):
		return false
	clip_name = n
	clip = CLIPS[_clip_kind()][n]
	attack_a = 0.0
	impact_fired = false
	return true


func is_attacking() -> bool:
	return attack_a >= 0.0


func clip_progress() -> float:
	return attack_a


func _clip_kind() -> String:
	return "brute" if kind == "colossus" else kind


func hit_react(from_dir: Vector3) -> void:
	hit = 1.0
	hit_side = 1.0 if from_dir.dot(global_basis.x) > 0.0 else -1.0
	flesh_mat.set_shader_parameter("hit_flash", 1.0)


func die() -> void:
	dead = true
	death_t = 0.0
	attack_a = -1.0


func _reset_pose() -> void:
	for n in rest:
		var node: Node3D = j[n]
		node.rotation = rest[n][0]
		node.position = rest[n][1]
		node.scale = rest[n][2]


func _kf(a: float, keys: Array) -> float:
	if a <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		if a <= keys[i][0]:
			var k0: Array = keys[i - 1]
			var k1: Array = keys[i]
			var u: float = (a - k0[0]) / maxf(k1[0] - k0[0], 0.0001)
			return lerpf(k0[1], k1[1], smoothstep(0.0, 1.0, u))
	return keys[keys.size() - 1][1]


func _rot(n: String, axis: int, v: float) -> void:
	if j.has(n):
		var node: Node3D = j[n]
		node.rotation[axis] += v


func _process(delta: float) -> void:
	t += delta
	_reset_pose()
	var stride := clampf(speed / run_speed, 0.0, 1.4)
	phase += delta * (1.6 + speed * (2.2 if kind == "hound" else 1.7) / maxf(run_speed / 5.0, 0.6))
	_footsteps(stride)
	match kind:
		"ghoul", "brute", "colossus":
			_anim_biped(stride)
		"hound":
			_anim_hound(stride)
		"spitter":
			_anim_spitter(stride)

	if crouch > 0.0:
		var root: Node3D = j.get("hips", j.get("body"))
		root.position.y -= 0.16 * crouch * (1.0 if kind == "hound" else 0.6)
		_rot("neck", 0, 0.4 * crouch)
		_rot("body", 0, 0.12 * crouch)
		_rot("spine", 0, -0.25 * crouch)
		_rot("jaw", 0, -0.55 * crouch * (0.7 + 0.3 * sin(t * 30.0)))
	if attack_a >= 0.0:
		attack_a = freeze_a if freeze_a >= 0.0 else attack_a + delta / clip.dur
		if not impact_fired and attack_a >= clip.impact:
			impact_fired = true
			attack_impact.emit(clip_name)
		if attack_a >= 1.0 and freeze_a < 0.0:
			attack_a = -1.0
		else:
			for ch in clip.ch:
				var parts: PackedStringArray = ch.split(":")
				var v := _kf(attack_a, clip.ch[ch])
				var node: Node3D = j.get(parts[0])
				if node == null:
					continue
				match parts[1]:
					"x": node.rotation.x += v
					"y": node.rotation.y += v
					"z": node.rotation.z += v
					"py": node.position.y += v
					"s": node.scale = Vector3.ONE * v

	if hit > 0.0:
		hit = maxf(hit - delta * 5.0, 0.0)
		var h := sin(hit * PI) * hit
		for n in ["spine", "body"]:
			_rot(n, 0, 0.45 * h)
			_rot(n, 2, 0.25 * h * hit_side)
		_rot("head", 0, 0.5 * h)
		flesh_mat.set_shader_parameter("hit_flash", hit * hit)

	if dead:
		_anim_death(delta)

	if has_look and not dead:
		var head: Node3D = j.get("head")
		if head:
			var local := to_local(look_at_point)
			var yaw := clampf(atan2(-local.x, -local.z), -0.9, 0.9)
			head.rotation.y += yaw * 0.6


func _anim_biped(stride: float) -> void:
	var s := sin(phase)
	var c := cos(phase)
	var brute := kind != "ghoul"
	var amp := 0.75 if not brute else 0.55
	for side in [-1.0, 1.0]:
		var n := "R" if side > 0 else "L"
		var sp: float = s * side
		var cp: float = c * side
		var thigh: float = amp * stride * sp
		var knee: float = -(0.12 + 1.15 * stride * maxf(0.0, cp))
		_rot("thigh_" + n, 0, thigh)
		_rot("knee_" + n, 0, knee)
		_rot("ankle_" + n, 0, -(thigh + knee) * 0.6)
		_rot("shoulder_" + n, 0, -0.65 * stride * sp - 0.15 * stride)
		_rot("elbow_" + n, 0, 0.35 * stride + 0.25 * stride * maxf(0.0, -sp))
		# Idle: arms hang and twitch, claws flex.
		_rot("shoulder_" + n, 2, sin(t * 1.3 + side) * 0.04 * (1.0 - stride))
	var bob := absf(s) * 0.07 * stride
	j.hips.position.y -= bob + 0.05 * stride
	_rot("hips", 2, 0.06 * stride * s)
	_rot("hips", 1, 0.12 * stride * s)
	_rot("spine", 0, -0.25 * stride + sin(t * 1.8) * 0.03 * (1.0 - stride))
	_rot("chest", 1, -0.15 * stride * s)
	var breathe := 1.0 + sin(t * (2.0 if brute else 2.6)) * 0.025
	j.chest.scale = Vector3(breathe, breathe, breathe)
	_rot("head", 1, sin(t * 0.7) * 0.3 * (1.0 - stride))
	_rot("head", 0, sin(t * 3.1) * 0.03)
	_rot("jaw", 0, -absf(sin(t * 0.9)) * 0.12)


func _anim_hound(stride: float) -> void:
	var gallop := stride > 0.6
	var offs := {"FL": 0.0, "BR": 0.0, "FR": PI, "BL": PI}
	if gallop:
		offs = {"FL": 0.0, "FR": 0.35, "BL": PI, "BR": PI + 0.35}
	for n in offs:
		var ph: float = phase + offs[n]
		var front: bool = n.begins_with("F")
		var sw := sin(ph)
		_rot("leg_" + n, 0, (0.55 if front else 0.5) * stride * sw)
		_rot("low_" + n, 0, (-0.9 if front else -0.6) * stride * maxf(0.0, cos(ph)) * (1.0 if front else -0.8))
	j.body.position.y += sin(phase * 2.0) * 0.04 * stride + (sin(t * 2.4) * 0.01) - 0.04 * stride
	_rot("body", 0, (sin(phase) * 0.12 if gallop else 0.0) * stride - 0.05 * stride)
	_rot("neck", 0, -sin(phase * 2.0) * 0.08 * stride + sin(t * 0.8) * 0.05 * (1.0 - stride))
	_rot("neck", 1, sin(t * 0.6) * 0.25 * (1.0 - stride))
	_rot("jaw", 0, -(0.15 + 0.15 * sin(t * 8.0)) * stride - absf(sin(t * 1.1)) * 0.1)
	for i in 5:
		_rot("tail_%d" % i, 1, sin(t * 3.0 + i * 0.7) * 0.15 * (1.0 + stride))
		_rot("tail_%d" % i, 0, -0.06 * stride)


func _anim_spitter(stride: float) -> void:
	var li := 0
	for side in ["R", "L"]:
		for k in 3:
			var n := "%s%d" % [side, k]
			var group := (k + (0 if side == "R" else 1)) % 2
			var ph: float = phase * 1.5 + group * PI
			var sgn := 1.0 if side == "R" else -1.0
			_rot("hip_" + n, 1, 0.3 * stride * cos(ph) * sgn)
			_rot("fem_" + n, 2, 0.35 * maxf(0.0, sin(ph)) * stride * sgn + sin(t * 1.5 + li) * 0.03)
			li += 1
	j.body.position.y += sin(phase * 3.0) * 0.025 * stride + sin(t * 1.4) * 0.015
	var pulse := 1.0 + sin(t * 3.0) * 0.05
	j.sac.scale = Vector3(pulse, pulse * 0.97, pulse)
	_rot("head", 1, sin(t * 0.9) * 0.3 * (1.0 - stride))
	_rot("jaw", 1, absf(sin(t * 5.0)) * 0.15)


func _anim_death(delta: float) -> void:
	death_t += delta
	var w := smoothstep(0.0, 0.55, death_t)
	var root: Node3D = j.get("hips", j.get("body"))
	root.position.y = lerpf(root.position.y, base_h * 0.25, w)
	_rot("spine", 0, 0.9 * w)
	_rot("body", 2, 0.5 * w)
	_rot("head", 0, 0.6 * w)
	_rot("jaw", 0, -0.6 * w)
	for n in ["shoulder_L", "shoulder_R"]:
		_rot(n, 0, -0.8 * w)
	for n in ["thigh_L", "thigh_R"]:
		_rot(n, 0, 1.0 * w)
	for n in ["knee_L", "knee_R"]:
		_rot(n, 0, -1.4 * w)
	var d := clampf((death_t - 0.7) / 1.4, 0.0, 1.0)
	flesh_mat.set_shader_parameter("dissolve", d)
	flesh_mat.set_shader_parameter("heat", 1.0 + w * 1.5)
	if glow_mat:
		glow_mat.set_shader_parameter("dissolve", d)
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mi.material_override == P.bone() or mi.material_override == P.eye():
			mi.visible = d < 0.6


func death_done() -> bool:
	return dead and death_t > 2.2


## A quiet footfall each time a foot plants (the Colossus has its own steps).
func _footsteps(stride: float) -> void:
	var half := int(floor(phase / PI))
	if half == _step_half:
		return
	_step_half = half
	if dead or stride < 0.2 or kind == "colossus":
		return
	var heavy := kind == "ghoul" or kind == "brute"
	var p := Sfx.play("creature_step", global_position, (-14.0 if heavy else -19.0) + stride * 4.0, 0.8 if heavy else 1.15, 0.1)
	if p is AudioStreamPlayer3D:
		(p as AudioStreamPlayer3D).max_distance = 24.0
		(p as AudioStreamPlayer3D).unit_size = 3.0
