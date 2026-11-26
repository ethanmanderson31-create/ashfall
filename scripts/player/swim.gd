class_name SwimController
extends Node
## Swimming. Over water deeper than the soldier can stand in, he floats at
## the surface, holsters both weapons and swims: front crawl while moving,
## treading water while still. Drives the procedural swim pose in
## AimModifier, the stroke splashes/ripples and the water sounds.

const ENTER_DEPTH := 1.3     ## feet this far under the surface over deep water → swim
const EXIT_DEPTH := 1.0      ## pushed up by the shore this far → back on foot
const FLOAT_DEPTH := 1.4     ## how far below the surface the feet hang
const PIVOT := 1.3           ## chest height the body tips forward around

var p: CharacterBody3D
var swimming := false
var tilt := 0.0              ## radians the body lies forward (0 upright)
var move_blend := 0.0        ## 0 treading water .. 1 front crawl
var cycles := 0.0            ## stroke cycles since entering the water
var _half := 0
var _t := 0.0
var _wake_t := 0.0


func depth() -> float:
	return Game.WATER_LEVEL - p.global_position.y


func _deep_here() -> bool:
	return Game.WATER_LEVEL - Game.sample_height(p.global_position.x, p.global_position.z) > ENTER_DEPTH


## Called from the player's physics step before normal movement. Returns
## true when it handled movement this frame (the player skips the rest).
func physics(delta: float, move: Vector3, sprint: bool) -> bool:
	if not swimming:
		if depth() > ENTER_DEPTH and _deep_here():
			_enter()
		else:
			return false
	elif depth() < EXIT_DEPTH:
		_exit()
		return false
	_t += delta
	# Nothing combat-related carries on in the water.
	p.aiming = false
	p.air_t = 0.0
	p.land_t = 0.0
	p.dodge_t = 0.0
	p.swing_t = 0.0
	p.bash_t = 0.0
	p.slamming = false

	var spd: float = p.stats.move_speed * (0.66 if sprint else 0.46) * p.buff_val("speed")
	var target := move * spd
	var k := 1.0 - exp(-2.2 * delta)
	p.velocity.x = lerpf(p.velocity.x, target.x, k)
	p.velocity.z = lerpf(p.velocity.z, target.z, k)
	var hs := Vector2(p.velocity.x, p.velocity.z).length()
	# Buoyancy: a soft spring to the float line, with a gentle bob when still.
	# Lying flat in a crawl the body rides higher (back at the surface).
	var want_y := Game.WATER_LEVEL - FLOAT_DEPTH + 0.22 * move_blend + sin(_t * 1.7) * 0.05 * (1.0 - move_blend)
	p.velocity.y = lerpf(p.velocity.y, (want_y - p.global_position.y) * 3.5, 1.0 - exp(-2.5 * delta))
	if p.is_on_wall() and move.length() > 0.1:
		p.velocity.y = maxf(p.velocity.y, 2.6)   # haul out onto a steep bank
	p.move_and_slide()

	if move.length() > 0.1:
		p.face_yaw = lerp_angle(p.face_yaw, atan2(-move.x, -move.z), 1.0 - exp(-5.0 * delta))
	move_blend = move_toward(move_blend, clampf((hs - 0.3) / 1.8, 0.0, 1.0), delta * 1.6)
	tilt = lerpf(tilt, lerpf(0.16, 1.42, move_blend), 1.0 - exp(-4.0 * delta))
	cycles += delta * lerpf(0.42, 0.5 + hs * 0.08, move_blend)
	var half := int(cycles * 2.0)
	if half != _half:
		_half = half
		_stroke(1.0 if half % 2 == 0 else -1.0)
	_wake_t -= delta
	if hs > 0.8 and _wake_t <= 0.0:
		_wake_t = 0.5
		WaterFx.ripple(p.global_position - Vector3(p.velocity.x, 0, p.velocity.z).normalized() * 0.6, 1.1, 1.0)

	if p.cur_anim != "Idle":
		p.anim.play("Idle", 0.3)
		p.cur_anim = "Idle"
	p.anim.speed_scale = 0.5
	return true


func _enter() -> void:
	swimming = true
	cycles = 0.0
	_half = 0
	var fall := maxf(-p.velocity.y, 0.0)
	var hs := Vector2(p.velocity.x, p.velocity.z).length()
	var strength := clampf(fall / 7.0 + hs / 12.0, 0.45, 1.8)
	p.velocity.y *= 0.3
	WaterFx.splash(p.global_position, strength)
	Sfx.play("water_splash", null, -12.0 + strength * 5.0, 1.15 - strength * 0.12, 0.06)


func _exit() -> void:
	swimming = false
	Sfx.play("water_exit", null, -9.0, 1.0, 0.08)
	WaterFx.ripple(p.global_position, 1.4, 1.0)


func _stroke(side: float) -> void:
	var fwd := Vector3(-sin(p.face_yaw), 0, -cos(p.face_yaw))
	var right := Vector3(cos(p.face_yaw), 0, -sin(p.face_yaw))
	if move_blend > 0.4:
		var hand := p.global_position + fwd * 0.95 + right * side * 0.28
		WaterFx.splash(hand, 0.22 + move_blend * 0.12, fwd * 0.3)
		Sfx.play("swim_stroke", null, -9.0 + move_blend * 2.0, 1.0, 0.08)
	else:
		WaterFx.ripple(p.global_position + fwd * 0.35 + right * side * 0.35, 0.9, 1.0)
		Sfx.play("swim_tread", null, -15.0, 1.0, 0.08)


func _physics_process(delta: float) -> void:
	# Runs after the player's own step: lay the body over in the water and
	# ease it upright again after climbing out.
	if p == null or p.dead:
		return
	if not swimming:
		if tilt <= 0.001:
			return
		tilt = move_toward(tilt, 0.0, delta * 3.5)
		move_blend = move_toward(move_blend, 0.0, delta * 3.5)
	var b := Basis(Vector3.UP, p.face_yaw) * Basis(Vector3.RIGHT, -tilt)
	var piv := Vector3(0, PIVOT, 0)
	p.visual.transform = Transform3D(b, piv - b * piv)


func _process(delta: float) -> void:
	# Runs after the player's _process: override the weapon pose with the swim pose.
	if p == null:
		return
	var w := 1.0 if swimming else 0.0
	p.aim_mod.swim = w
	p.aim_mod.swim_move = move_blend
	p.aim_mod.swim_phase = fmod(cycles, 1.0)
	p.aim_mod.swim_tilt = tilt
	if swimming:
		p.gun.visible = false
		p.blade.visible = false
		p.pitch = minf(p.pitch, 0.1)   # keep the camera above the surface
	p.cam_pivot.position.y = lerpf(p.cam_pivot.position.y, 1.55 + 0.45 * w, 1.0 - exp(-4.0 * delta))
