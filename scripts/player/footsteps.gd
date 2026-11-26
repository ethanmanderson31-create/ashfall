class_name Footsteps
extends Node
## The soldier's footfalls: boots on dry ground, sloshing steps when wading
## (with a little splash), silent while swimming or airborne.

var p: CharacterBody3D
var _dist := 0.0


func _physics_process(_delta: float) -> void:
	if p == null or p.dead or p.swim.swimming or not p.is_on_floor() or p.dodge_t > 0.0:
		_dist = 0.0
		return
	var hs := Vector2(p.velocity.x, p.velocity.z).length()
	if hs < 0.6:
		return
	_dist += hs * get_physics_process_delta_time()
	var stride := 1.55 if hs > 5.6 else 0.95
	if _dist < stride:
		return
	_dist = 0.0
	var run := hs > 5.6
	var wade: float = Game.WATER_LEVEL - p.global_position.y
	if wade > 0.08:
		Sfx.play("wade", null, -13.0 + (3.0 if run else 0.0), 1.0, 0.1)
		WaterFx.splash(p.global_position, 0.12 + (0.12 if run else 0.0))
	else:
		Sfx.play("footstep", null, -17.0 + (3.0 if run else 0.0), 1.0, 0.1)
