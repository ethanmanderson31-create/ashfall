class_name AimModifier
extends SkeletonModifier3D
## Procedural upper-body pose layered on top of the walk/run animations:
## - bends the spine toward the aim point when shouldering the rifle
## - places the rifle at the right shoulder (aim) or low-ready (relaxed)
## - two-bone IK puts both hands on the rifle (grip + handguard)

var aim_point := Vector3.ZERO      ## world-space point the crosshair is on
var aim_blend := 0.0               ## 0 = low ready, 1 = shouldered aim
var face_yaw := 0.0                ## body facing (radians)
var gun: Node3D                    ## rifle node, positioned here each frame
var gun_xform := Transform3D()
var blade: Node3D                  ## melee blade, positioned during swings
var swing := 0.0                   ## 0 = rifle pose, 1 = sword swing
var swing_phase := 0.0             ## 0..1 through the slash
var swing_side := 1.0              ## +1 right-to-left, -1 left-to-right
var heavy := false                 ## overhead finisher
var reload_phase := -1.0           ## 0..1 through a reload, -1 when not reloading
var mag_hand_pos := Vector3.ZERO   ## world position of the fresh magazine in hand
var recoil := 0.0                  ## 1 on a shot, decays: kicks the rifle
var flinch := 0.0                  ## hit reaction: rocks the torso back
var air := 0.0                     ## 0 grounded .. 1 airborne: tuck legs
var rise := 0.0                    ## vertical velocity sign/size in the air
var land := 0.0                    ## landing compression
var bash := 0.0                    ## rifle jab, 0..1 envelope
var swim := 0.0                    ## 1 while swimming (replaces the weapon pose)
var swim_move := 0.0               ## 0 treading water .. 1 front crawl
var swim_phase := 0.0              ## stroke cycle 0..1
var swim_tilt := 0.0               ## radians the body lies forward

var _b := {}


func _find(skel: Skeleton3D, suffix: String) -> int:
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).ends_with(suffix):
			return i
	return -1


func _init_bones(skel: Skeleton3D) -> void:
	for key in ["Hips", "Spine", "Spine1", "Spine2", "RightArm", "RightForeArm", "RightHand", "LeftArm", "LeftForeArm", "LeftHand", "RightUpLeg", "RightLeg", "LeftUpLeg", "LeftLeg", "Neck", "Head"]:
		_b[key] = _find(skel, key)


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	if _b.is_empty():
		_init_bones(skel)
	var sx := skel.global_transform
	var inv := sx.affine_inverse()
	var fwd := Vector3(-sin(face_yaw), 0, -cos(face_yaw))
	var right := Vector3(cos(face_yaw), 0, -sin(face_yaw))
	if swim > 0.5:
		_swim_pose(skel, sx, inv, fwd, right)
		return

	# 0. Legs: jump tuck, landing compression.
	if air > 0.001 or land > 0.001:
		var axis_r := (inv.basis * right).normalized()
		var up_s := inv.basis * Vector3.UP
		if land > 0.001:
			var hp := skel.get_bone_global_pose(_b.Hips)
			hp.origin -= up_s * 0.16 * land
			skel.set_bone_global_pose(_b.Hips, hp)
		for side in [["RightUpLeg", "RightLeg", 1.0], ["LeftUpLeg", "LeftLeg", 0.65]]:
			# Rising: knees drawn up; falling: legs reach down for the ground.
			var tuck: float = air * lerpf(0.35, 1.0, clampf(rise * 0.5 + 0.5, 0.0, 1.0)) * side[2]
			var thigh := tuck * 1.05 + land * 0.75
			var shin := tuck * 1.9 + land * 1.35
			var gu := skel.get_bone_global_pose(_b[side[0]])
			gu.basis = Basis(axis_r, thigh) * gu.basis
			skel.set_bone_global_pose(_b[side[0]], gu)
			var gl := skel.get_bone_global_pose(_b[side[1]])
			gl.basis = Basis(axis_r, -shin) * gl.basis
			skel.set_bone_global_pose(_b[side[1]], gl)

	# 1. Spine: lean into the aim (pitch), split across three bones.
	var chest_w := sx * skel.get_bone_global_pose(_b.Spine2).origin
	var to_aim := (aim_point - chest_w).normalized()
	var pitch := asin(clampf(to_aim.y, -0.9, 0.9)) * aim_blend - 0.3 * bash + 0.45 * flinch - 0.12 * land + 0.04 * recoil * aim_blend
	var axis := (inv.basis * right).normalized()
	for key in ["Spine", "Spine1", "Spine2"]:
		var gp := skel.get_bone_global_pose(_b[key])
		gp.basis = Basis(axis, pitch / 3.0) * gp.basis
		skel.set_bone_global_pose(_b[key], gp)

	# 2. Rifle placement in world space.
	var shoulder_w := sx * skel.get_bone_global_pose(_b.RightArm).origin
	var aim_dir := (aim_point - shoulder_w).normalized()
	var ready_dir := (fwd * 0.75 + Vector3.DOWN * 0.55 - right * 0.35).normalized()
	var dir := ready_dir.slerp(aim_dir, aim_blend).normalized()
	var gb := Basis.looking_at(dir, Vector3.UP)
	gb = Basis(gb.x, 0.14 * recoil + 0.25 * bash) * gb
	var rl := 0.0
	if reload_phase >= 0.0:
		# Cant the rifle and bring it in to work the magazine.
		rl = sin(clampf(reload_phase / 0.92, 0.0, 1.0) * PI)
		gb = Basis(gb.z, -0.55 * rl) * Basis(gb.x, 0.25 * rl) * gb
	var aim_off := Vector3(-0.07, -0.13, -0.24)
	var ready_off := Vector3(-0.12, -0.2, -0.2)
	var grip := shoulder_w + gb * (ready_off.lerp(aim_off, aim_blend) + Vector3(0, 0.012, 0.075) * recoil + Vector3(0.05, -0.06, 0.06) * rl + Vector3(-0.04, 0.06, -0.38) * bash)
	gun_xform = Transform3D(gb, grip)
	if gun:
		gun.global_transform = gun_xform

	var up := Vector3.UP
	if swing > 0.5:
		_axe_pose(skel, inv, chest_w, shoulder_w, fwd, right, up)
		return

	# 3. Arms: IK both hands onto the rifle.
	var r_target := grip + gb * Vector3(0.0, -0.05, 0.03)
	var l_target := grip + gb * Vector3(-0.0, -0.035, -0.3)
	if reload_phase >= 0.0:
		l_target = _reload_hand(skel, sx, grip, gb, l_target, fwd, right)
	var l_shoulder_w := sx * skel.get_bone_global_pose(_b.LeftArm).origin
	var r_pole := shoulder_w + right * 0.45 - up * 0.45 - fwd * 0.1
	var l_pole := l_shoulder_w - right * 0.1 - up * 0.6 + fwd * 0.1
	_two_bone(skel, _b.RightArm, _b.RightForeArm, _b.RightHand, inv * r_target, inv * r_pole)
	_two_bone(skel, _b.LeftArm, _b.LeftForeArm, _b.LeftHand, inv * l_target, inv * l_pole)
	# Hands: fingers wrap the grip (right) and under the handguard (left).
	_point_bone_y(skel, _b.RightHand, inv.basis * (gb * Vector3(-0.55, -0.75, -0.35)))
	_point_bone_y(skel, _b.LeftHand, inv.basis * (gb * Vector3(0.6, 0.25, -0.75)))


func _two_bone(skel: Skeleton3D, upper: int, lower: int, end: int, target: Vector3, pole: Vector3) -> void:
	var gu := skel.get_bone_global_pose(upper)
	var gl := skel.get_bone_global_pose(lower)
	var ge := skel.get_bone_global_pose(end)
	var a := gu.origin
	var b := gl.origin
	var c := ge.origin
	var la := a.distance_to(b)
	var lb := b.distance_to(c)
	var to_t := target - a
	var d := clampf(to_t.length(), 0.001, (la + lb) * 0.999)
	var dir := to_t.normalized()
	var cos_a := clampf((la * la + d * d - lb * lb) / (2.0 * la * d), -1.0, 1.0)
	var sin_a := sqrt(1.0 - cos_a * cos_a)
	var pv := pole - a
	var perp := (pv - dir * pv.dot(dir)).normalized()
	var elbow := a + dir * cos_a * la + perp * sin_a * la
	var t_reach := a + dir * d

	gu.basis = Basis(Quaternion((b - a).normalized(), (elbow - a).normalized())) * gu.basis
	skel.set_bone_global_pose(upper, gu)
	gl = skel.get_bone_global_pose(lower)
	var cur_c := skel.get_bone_global_pose(end).origin
	gl.basis = Basis(Quaternion((cur_c - gl.origin).normalized(), (t_reach - gl.origin).normalized())) * gl.basis
	skel.set_bone_global_pose(lower, gl)


func _point_bone_y(skel: Skeleton3D, bone: int, want: Vector3) -> void:
	var gp := skel.get_bone_global_pose(bone)
	var cur := gp.basis.y.normalized()
	gp.basis = Basis(Quaternion(cur, want.normalized())) * gp.basis
	skel.set_bone_global_pose(bone, gp)


## Two-handed battle-axe chop: wind up over the shoulder, then drive it
## down through the target. Hands slide along the haft; the torso twists.
func _axe_pose(skel: Skeleton3D, inv: Transform3D, chest_w: Vector3, shoulder_w: Vector3, fwd: Vector3, right: Vector3, up: Vector3) -> void:
	var s := swing_side
	var ready_c := chest_w + fwd * 0.32 - up * 0.3 + right * 0.08
	var ready_d := (fwd * 0.6 + up * 0.55 - right * 0.15).normalized()
	var raise_c: Vector3
	var raise_d: Vector3
	var hit_c: Vector3
	var hit_d: Vector3
	if heavy:
		raise_c = chest_w + up * 0.62 - fwd * 0.02
		raise_d = (up * 0.55 - fwd * 0.85).normalized()
		hit_c = chest_w + fwd * 0.62 - up * 0.55
		hit_d = (fwd * 0.45 - up * 0.9).normalized()
	else:
		raise_c = chest_w + up * 0.45 + right * 0.3 * s - fwd * 0.08
		raise_d = (up * 0.55 - fwd * 0.6 + right * 0.35 * s).normalized()
		hit_c = chest_w + fwd * 0.55 - up * 0.5 - right * 0.32 * s
		hit_d = (fwd * 0.75 - up * 0.5 - right * 0.45 * s).normalized()
	var a := swing_phase
	var c: Vector3
	var d: Vector3
	var twist := 0.0
	if a < 0.45:
		var u := ease(a / 0.45, -1.8)
		c = ready_c.lerp(raise_c, u)
		d = ready_d.lerp(raise_d, u)
		twist = 0.45 * s * u * (0.4 if heavy else 1.0)
	elif a < 0.6:
		var u := ease((a - 0.45) / 0.15, 2.4)
		c = raise_c.lerp(hit_c, u)
		d = raise_d.lerp(hit_d, u)
		twist = lerpf(0.45, -0.5, u) * s * (0.4 if heavy else 1.0)
	else:
		var u := smoothstep(0.0, 1.0, (a - 0.6) / 0.4)
		c = hit_c.lerp(ready_c, u)
		d = hit_d.lerp(ready_d, u)
		twist = lerpf(-0.5, 0.0, u) * s * (0.4 if heavy else 1.0)
	d = d.normalized()
	# Torso twist / chop lean.
	var axis_up := (inv.basis * up).normalized()
	var axis_r := (inv.basis * right).normalized()
	var lean := 0.0
	if heavy:
		lean = -0.35 * sin(clampf((a - 0.4) / 0.4, 0.0, 1.0) * PI) + 0.25 * sin(clampf(a / 0.45, 0.0, 1.0) * PI) * 0.5
	for key in ["Spine1", "Spine2"]:
		var gp := skel.get_bone_global_pose(_b[key])
		gp.basis = Basis(axis_up, twist * 0.5) * Basis(axis_r, lean * 0.5) * gp.basis
		skel.set_bone_global_pose(_b[key], gp)
	var r_hand := c - d * 0.16
	var l_hand := c + d * 0.16
	if blade:
		blade.global_transform = Transform3D(Basis.looking_at(d, up if absf(d.dot(up)) < 0.97 else fwd), r_hand)
	var l_shoulder := shoulder_w - right * 0.4
	_two_bone(skel, _b.RightArm, _b.RightForeArm, _b.RightHand, inv * r_hand, inv * (shoulder_w + right * 0.45 - up * 0.4))
	_two_bone(skel, _b.LeftArm, _b.LeftForeArm, _b.LeftHand, inv * l_hand, inv * (l_shoulder - right * 0.35 - up * 0.45))
	var wrap := d.cross(up).normalized()
	_point_bone_y(skel, _b.RightHand, inv.basis * (wrap * -1.0 + d * 0.2))
	_point_bone_y(skel, _b.LeftHand, inv.basis * (wrap * 1.0 + d * 0.2))


## Left-hand path for a reload: strip mag, reach to the belt pouch, seat the
## new mag, slap it home, return to the handguard.
func _reload_hand(skel: Skeleton3D, sx: Transform3D, grip: Vector3, gb: Basis, guard: Vector3, fwd: Vector3, right: Vector3) -> Vector3:
	var well := grip + gb * Vector3(0, -0.06, -0.2)
	var below := well - gb.y * 0.16 + fwd * 0.02
	var hips := sx * skel.get_bone_global_pose(_b.Hips).origin
	var pouch := hips - right * 0.2 + fwd * 0.1 + Vector3.UP * 0.05
	var keys := [
		[0.0, guard], [0.12, well], [0.24, below], [0.42, pouch], [0.5, pouch],
		[0.68, below], [0.78, well], [0.84, well + gb.y * 0.03], [1.0, guard],
	]
	var a := reload_phase
	var pos: Vector3 = guard
	for i in range(1, keys.size()):
		if a <= keys[i][0]:
			var k0: Array = keys[i - 1]
			var k1: Array = keys[i]
			var u := smoothstep(0.0, 1.0, (a - k0[0]) / maxf(k1[0] - k0[0], 0.001))
			pos = (k0[1] as Vector3).lerp(k1[1], u)
			break
	mag_hand_pos = pos + gb.y * 0.05
	return pos


## Swimming. Front crawl: arms windmill (reach past the head, pull under the
## chest to the hip, recover over the back), the body rolls with each stroke,
## legs flutter-kick and the head lifts to look ahead. Treading water: hands
## scull side to side in front of the chest while the legs cycle slowly.
func _swim_pose(skel: Skeleton3D, sx: Transform3D, inv: Transform3D, fwd: Vector3, right: Vector3) -> void:
	var a := swim_tilt
	var up_b := Vector3.UP * cos(a) + fwd * sin(a)      # toward the head
	var fwd_b := fwd * cos(a) - Vector3.UP * sin(a)     # where the chest faces
	var m := swim_move
	var th := swim_phase * TAU
	var axis_r := (inv.basis * right).normalized()
	var axis_long := (inv.basis * up_b).normalized()

	var roll := sin(th) * 0.3 * m
	for key in ["Spine", "Spine1", "Spine2"]:
		var gp := skel.get_bone_global_pose(_b[key])
		gp.basis = Basis(axis_long, roll / 3.0) * gp.basis
		skel.set_bone_global_pose(_b[key], gp)
	var lift := a * 0.62
	for key in ["Neck", "Head"]:
		if _b[key] < 0:
			continue
		var gh := skel.get_bone_global_pose(_b[key])
		gh.basis = Basis(axis_long, -roll * 0.6) * Basis(axis_r, lift * 0.5) * gh.basis
		skel.set_bone_global_pose(_b[key], gh)

	for leg in [["RightUpLeg", "RightLeg", 0.0], ["LeftUpLeg", "LeftLeg", PI]]:
		var off: float = leg[2]
		var kick := sin(th * 3.0 + off) * 0.3
		var cyc := sin(th + off)
		var thigh := lerpf(0.55 + 0.32 * cyc, kick * 0.6 - 0.12, m)
		var shin := lerpf(1.0 + 0.35 * cyc, 0.06 + 0.16 * maxf(sin(th * 3.0 + off + 0.8), 0.0), m)
		var gu := skel.get_bone_global_pose(_b[leg[0]])
		gu.basis = Basis(axis_r, thigh) * gu.basis
		skel.set_bone_global_pose(_b[leg[0]], gu)
		var gl := skel.get_bone_global_pose(_b[leg[1]])
		gl.basis = Basis(axis_r, -shin) * gl.basis
		skel.set_bone_global_pose(_b[leg[1]], gl)

	for arm in [["RightArm", "RightForeArm", "RightHand", 1.0, 0.0], ["LeftArm", "LeftForeArm", "LeftHand", -1.0, PI]]:
		var s: float = arm[3]
		var t: float = th + arm[4]
		var sh := sx * skel.get_bone_global_pose(_b[arm[0]]).origin
		# Pull is deep under the chest; recovery stays low with a high elbow.
		var depth := sin(t) * (0.36 if sin(t) > 0.0 else 0.12)
		var crawl := sh + up_b * (0.06 + 0.56 * cos(t)) + fwd_b * depth + right * s * (0.12 + 0.12 * maxf(-sin(t), 0.0))
		var crawl_pole := sh + right * s * 0.35 - fwd_b * 0.6 - up_b * 0.1
		var tread := sh + fwd_b * 0.36 - up_b * 0.24 + right * s * (0.17 + 0.14 * sin(th))
		var tread_pole := sh + right * s * 0.5 - up_b * 0.45
		_two_bone(skel, _b[arm[0]], _b[arm[1]], _b[arm[2]], inv * tread.lerp(crawl, m), inv * tread_pole.lerp(crawl_pole, m))
