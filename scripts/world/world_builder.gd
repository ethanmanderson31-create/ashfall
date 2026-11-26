class_name WorldBuilder
extends RefCounted
## Procedurally builds the open world: sky/lighting, terrain, water, grass,
## trees, rocks and ruin sites.

static var stone_mat: ShaderMaterial


static func build_environment(root: Node3D) -> DirectionalLight3D:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.16, 0.36, 0.72)
	sm.sky_horizon_color = Color(0.95, 0.78, 0.58)
	sm.sky_curve = 0.12
	sm.ground_horizon_color = Color(0.72, 0.62, 0.54)
	sm.ground_bottom_color = Color(0.16, 0.15, 0.13)
	sm.sun_angle_max = 25.0
	sm.sun_curve = 0.08
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.65
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.2
	env.ssil_enabled = true
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.80, 0.74, 0.68)
	env.fog_density = 0.0012
	env.fog_aerial_perspective = 0.55
	env.fog_sky_affect = 0.2
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0028
	env.volumetric_fog_albedo = Color(0.92, 0.86, 0.80)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 96.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	we.environment = env
	Game.env = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-24, -35, 0)
	sun.light_color = Color(1.0, 0.87, 0.70)
	sun.light_energy = 2.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.light_angular_distance = 0.8
	sun.light_volumetric_fog_energy = 1.6
	root.add_child(sun)
	Game.sun = sun
	return sun


static func build_terrain(root: Node3D) -> void:
	if Game.heights.is_empty():
		Game.bake_heights()
	var res := Game.TERRAIN_RES
	var r1 := res + 1
	var step := Game.MAP_SIZE / res
	var half := Game.MAP_SIZE * 0.5
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	verts.resize(r1 * r1)
	norms.resize(r1 * r1)
	uvs.resize(r1 * r1)
	var h := Game.heights
	for j in r1:
		for i in r1:
			var k := j * r1 + i
			verts[k] = Vector3(-half + i * step, h[k], -half + j * step)
			var hl := h[j * r1 + maxi(i - 1, 0)]
			var hr := h[j * r1 + mini(i + 1, res)]
			var hd := h[maxi(j - 1, 0) * r1 + i]
			var hu := h[mini(j + 1, res) * r1 + i]
			norms[k] = Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
			uvs[k] = Vector2(i, j) / res
	for j in res:
		for i in res:
			var a := j * r1 + i
			var b := a + 1
			var c := a + r1
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/world/terrain.gdshader")
	mat.set_shader_parameter("water_level", Game.WATER_LEVEL)
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	root.add_child(mi)

	var body := StaticBody3D.new()
	body.collision_layer = Game.L_WORLD
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	root.add_child(body)


static func build_water(root: Node3D) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(Game.MAP_SIZE, Game.MAP_SIZE)
	pm.subdivide_width = 4
	pm.subdivide_depth = 4
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/world/water.gdshader")
	pm.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = pm
	mi.position.y = Game.WATER_LEVEL
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


# ---------------------------------------------------------------- grass

static func _grass_clump_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for b in 13:
		var a := rng.randf() * TAU
		var off := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.38)
		var rot := rng.randf() * TAU
		var dir := Vector3(cos(rot), 0, sin(rot))
		var lean := Vector3(-dir.z, 0, dir.x) * rng.randf_range(0.05, 0.3)
		var hgt := rng.randf_range(0.28, 0.62)
		var w := rng.randf_range(0.016, 0.03)
		var shade := rng.randf_range(0.8, 1.15)
		var segs := 3
		var pts_l: Array[Vector3] = []
		var pts_r: Array[Vector3] = []
		for s in segs + 1:
			var t := float(s) / segs
			var p := off + lean * t * t + Vector3(0, hgt * t, 0)
			var width := w * (1.0 - t)
			pts_l.append(p - dir * width)
			pts_r.append(p + dir * width)
		var nrm := Vector3(-dir.z, 0.3, dir.x).normalized()
		for s in segs:
			var t0 := float(s) / segs
			var t1 := float(s + 1) / segs
			var quad := [[pts_l[s], t0], [pts_r[s], t0], [pts_l[s + 1], t1],
				[pts_r[s], t0], [pts_r[s + 1], t1], [pts_l[s + 1], t1]]
			for q in quad:
				st.set_color(Color(shade, shade, shade))
				st.set_uv(Vector2(0.5, q[1]))
				st.set_normal(nrm)
				st.add_vertex(q[0])
	return st.commit()


static func build_grass(root: Node3D) -> void:
	var mesh := _grass_clump_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/world/grass.gdshader")
	mesh.surface_set_material(0, mat)
	var chunk := 24.0
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.run_seed + 11
	var half := 216.0
	var holder := Node3D.new()
	holder.name = "Grass"
	Game.grass_holder = holder
	root.add_child(holder)
	var cx := -half
	while cx < half:
		var cz := -half
		while cz < half:
			var center := Vector3(cx + chunk * 0.5, 0, cz + chunk * 0.5)
			var xf: Array[Transform3D] = []
			for i in 900:
				var x := cx + rng.randf() * chunk
				var z := cz + rng.randf() * chunk
				if Vector2(x, z).length() > 210.0:
					continue
				var dens := Game.noise_forest.get_noise_2d(x * 2.3 + 300.0, z * 2.3)
				if dens < -0.3 and rng.randf() < 0.8:
					continue
				var h := Game.sample_height(x, z)
				if h < Game.WATER_LEVEL + 0.5 or h > 34.0:
					continue
				var n := Game.sample_normal(x, z)
				if n.y < 0.84:
					continue
				var s := rng.randf_range(0.75, 1.4)
				var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.35), s))
				xf.append(Transform3D(b, Vector3(x, h - 0.05, z) - center))
			if xf.size() > 0:
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = mesh
				mm.instance_count = xf.size()
				for k in xf.size():
					mm.set_instance_transform(k, xf[k])
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.position = center
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.visibility_range_end = 75.0
				mmi.visibility_range_end_margin = 12.0
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				holder.add_child(mmi)
			cz += chunk
		cx += chunk


# ---------------------------------------------------------------- trees

static func _add_frustum(st: SurfaceTool, base: Vector3, top: Vector3, r0: float, r1: float, segs: int, col: Color, rng: RandomNumberGenerator) -> void:
	var axis := (top - base).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.y) > 0.9 else Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var side2 := axis.cross(side).normalized()
	var ring0: Array[Vector3] = []
	var ring1: Array[Vector3] = []
	var nrm: Array[Vector3] = []
	for s in segs + 1:
		var a := TAU * s / segs
		var d := side * cos(a) + side2 * sin(a)
		ring0.append(base + d * r0)
		ring1.append(top + d * r1)
		nrm.append(d)
	for s in segs:
		var tri := [[ring0[s], nrm[s], 0.0], [ring1[s], nrm[s], 1.0], [ring0[s + 1], nrm[s + 1], 0.0],
			[ring0[s + 1], nrm[s + 1], 0.0], [ring1[s], nrm[s], 1.0], [ring1[s + 1], nrm[s + 1], 1.0]]
		for v in tri:
			st.set_color(col)
			st.set_normal(v[1])
			st.set_uv(Vector2(float(s) / segs, v[2]))
			st.add_vertex(v[0])


static func _add_card(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3, nrm: Vector3, shade: float) -> void:
	var c := Color(shade, shade, shade, 1.0)
	var p := [center - u - v, center + u - v, center + u + v, center - u + v]
	var t := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_color(c)
		st.set_normal(nrm)
		st.set_uv(t[k])
		st.add_vertex(p[k])


static func _add_blob(st: SurfaceTool, center: Vector3, radius: Vector3, nrm_center: Vector3) -> void:
	# Solid inner volume (vertex alpha 0 = always opaque in the foliage shader).
	var sm := SphereMesh.new()
	sm.radial_segments = 10
	sm.rings = 6
	var arr := sm.get_mesh_arrays()
	var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for k in ii:
		var p: Vector3 = vv[k] * radius + center
		st.set_color(Color(0.42, 0.42, 0.42, 0.0))
		st.set_normal((p - nrm_center).normalized())
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(p)


static func make_broadleaf(rng: RandomNumberGenerator) -> ArrayMesh:
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var px := SurfaceTool.new()
	px.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk_h := rng.randf_range(3.5, 5.5)
	var bc := Color(1, 1, 1)
	_add_frustum(bark, Vector3(0, -0.4, 0), Vector3(0, trunk_h, 0), 0.38, 0.2, 9, bc, rng)
	_add_frustum(px, Vector3(0, -0.4, 0), Vector3(0, trunk_h, 0), 0.38, 0.2, 6, bc, rng)
	var crown := Vector3(0, trunk_h + 2.2, 0)
	var crown_r := rng.randf_range(3.0, 4.2)
	var blobs := rng.randi_range(4, 6)
	for b in blobs:
		var a := TAU * b / blobs + rng.randf_range(-0.4, 0.4)
		var off := Vector3(cos(a) * crown_r * 0.5, rng.randf_range(-0.6, 1.4), sin(a) * crown_r * 0.5)
		var bpos := crown + off
		_add_frustum(bark, Vector3(0, trunk_h - 0.6, 0), bpos * Vector3(0.8, 0.9, 0.8), 0.18, 0.07, 6, bc, rng)
		var br := rng.randf_range(1.6, 2.3)
		_add_blob(leaves, bpos, Vector3(br, br * 0.75, br) * 0.56, crown)
		_add_blob(px, bpos, Vector3(br, br * 0.8, br) * 0.95, crown)
		for c in 34:
			var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1), rng.randf_range(-1, 1)).normalized()
			var p := bpos + dir * br * Vector3(1, 0.8, 1) * rng.randf_range(0.65, 1.05)
			var nrm := ((p - crown).normalized() + Vector3.UP * 0.35).normalized()
			var size := rng.randf_range(0.75, 1.15)
			var u := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
			var v := u.cross(dir).normalized()
			u = v.cross(dir).normalized()
			var shade := clampf(0.5 + (p.y - crown.y) * 0.15 + dir.dot(Vector3(0.4, 0.6, 0.4)) * 0.35, 0.1, 1.0)
			_add_card(leaves, p, u * size, v * size, nrm, shade)
	var mesh := ArrayMesh.new()
	bark.commit(mesh)
	leaves.commit(mesh)
	mesh.set_meta("proxy", px.commit())
	return mesh


static func make_pine(rng: RandomNumberGenerator) -> ArrayMesh:
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var height := rng.randf_range(9.0, 15.0)
	var radius := height * rng.randf_range(0.26, 0.32)
	_add_frustum(bark, Vector3(0, -0.4, 0), Vector3(0, height, 0), 0.4, 0.05, 9, Color(1, 1, 1), rng)
	var px := SurfaceTool.new()
	px.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_frustum(px, Vector3(0, -0.4, 0), Vector3(0, height * 0.2, 0), 0.4, 0.3, 6, Color(1, 1, 1), rng)
	_add_frustum(px, Vector3(0, height * 0.16, 0), Vector3(0, height, 0), radius * 0.8, 0.05, 10, Color(1, 1, 1), rng)
	# Solid inner cone so you can't see through gaps.
	var sm := CylinderMesh.new()
	sm.top_radius = 0.05
	sm.bottom_radius = radius * 0.26
	sm.height = height * 0.78
	sm.radial_segments = 10
	sm.rings = 2
	var arr := sm.get_mesh_arrays()
	var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var cone_base := height * 0.2
	for k in ii:
		var p: Vector3 = vv[k] + Vector3(0, cone_base + sm.height * 0.5, 0)
		leaves.set_color(Color(0.1, 0.1, 0.1, 0.0))
		leaves.set_normal((Vector3(p.x, 0, p.z).normalized() + Vector3.UP * 0.5).normalized())
		leaves.set_uv(Vector2(0.5, 0.5))
		leaves.add_vertex(p)
	var whorls := int(height * 1.5)
	for w in whorls:
		var t := float(w) / whorls
		var y := lerpf(height * 0.18, height * 0.97, t)
		var r := lerpf(radius, 0.4, pow(t, 0.9)) * rng.randf_range(0.85, 1.1)
		var count := int(lerpf(12, 5, t))
		var rot := rng.randf() * TAU
		for b in count:
			var a := rot + TAU * b / count + rng.randf_range(-0.2, 0.2)
			var out := Vector3(cos(a), 0, sin(a))
			var droop := r * rng.randf_range(0.25, 0.45)
			var base := Vector3(0, y, 0) + out * 0.1
			var tip := Vector3(0, y - droop, 0) + out * r
			var along := tip - base
			var side := out.cross(Vector3.UP).normalized() * r * 0.5
			var nrm := (out + Vector3.UP * 0.7).normalized()
			var shade := clampf(0.35 + t * 0.4 + rng.randf_range(-0.1, 0.15), 0.1, 1.0)
			# Card UV.x runs along the branch (0 trunk -> 1 tip), UV.y across.
			var p := [base - side * 0.3, tip - side, tip + side, base + side * 0.3]
			var tuv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
			for k in [0, 1, 2, 0, 2, 3]:
				leaves.set_color(Color(shade, shade, shade, 1.0))
				leaves.set_normal(nrm)
				leaves.set_uv(tuv[k])
				leaves.add_vertex(p[k])
			# A second, slightly raised card adds volume.
			var lift := Vector3(0, r * 0.12, 0)
			for k in [0, 1, 2, 0, 2, 3]:
				leaves.set_color(Color(shade * 1.1, shade, shade, 1.0))
				leaves.set_normal(nrm)
				leaves.set_uv(tuv[k])
				leaves.add_vertex(p[k] + lift * (1.0 if k == 1 or k == 2 else 0.3) + along * -0.05)
	var mesh := ArrayMesh.new()
	bark.commit(mesh)
	leaves.commit(mesh)
	mesh.set_meta("proxy", px.commit())
	return mesh


static func build_trees(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.run_seed + 2024
	var bark_mat := ShaderMaterial.new()
	bark_mat.shader = load("res://shaders/world/rock.gdshader")
	bark_mat.set_shader_parameter("base_a", Color(0.33, 0.25, 0.19))
	bark_mat.set_shader_parameter("base_b", Color(0.13, 0.10, 0.08))
	bark_mat.set_shader_parameter("moss_amount", 0.35)
	bark_mat.set_shader_parameter("scale", 1.6)
	var leaf_mat := ShaderMaterial.new()
	leaf_mat.shader = load("res://shaders/world/foliage.gdshader")
	var pine_mat := ShaderMaterial.new()
	pine_mat.shader = load("res://shaders/world/foliage.gdshader")
	pine_mat.set_shader_parameter("pine", true)
	pine_mat.set_shader_parameter("leaf_dark", Color(0.04, 0.10, 0.06))
	pine_mat.set_shader_parameter("leaf_light", Color(0.20, 0.34, 0.16))
	pine_mat.set_shader_parameter("wind", 0.5)

	var variants: Array[ArrayMesh] = []
	var is_pine: Array[bool] = []
	for i in 4:
		var m := make_broadleaf(rng)
		m.surface_set_material(0, bark_mat)
		m.surface_set_material(1, leaf_mat)
		variants.append(m)
		is_pine.append(false)
	for i in 4:
		var m := make_pine(rng)
		m.surface_set_material(0, bark_mat)
		m.surface_set_material(1, pine_mat)
		variants.append(m)
		is_pine.append(true)

	var per_variant: Array = []
	for i in variants.size():
		per_variant.append([])
	var body := StaticBody3D.new()
	body.name = "TreeColliders"
	body.collision_layer = Game.L_WORLD
	root.add_child(body)
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.4
	trunk_shape.height = 6.0
	var placed := 0
	for i in 9000:
		var x := rng.randf_range(-215, 215)
		var z := rng.randf_range(-215, 215)
		var d := Vector2(x, z).length()
		if d < 26.0 or d > 225.0:
			continue
		if _near_route(x, z, 13.0):
			continue
		var f := Game.noise_forest.get_noise_2d(x, z)
		var chance := smoothstep(-0.05, 0.35, f) * 0.9 + 0.025
		if rng.randf() > chance:
			continue
		var h := Game.sample_height(x, z)
		if h < Game.WATER_LEVEL + 0.8 or h > 52.0:
			continue
		if Game.sample_normal(x, z).y < 0.8:
			continue
		var pine_bias := smoothstep(4.0, 20.0, h) * 0.8 + 0.1
		var want_pine := rng.randf() < pine_bias
		var v := rng.randi_range(0, 3) + (4 if want_pine else 0)
		var s := rng.randf_range(0.8, 1.3)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, h, z))
		per_variant[v].append(xf)
		var cs := CollisionShape3D.new()
		cs.shape = trunk_shape
		cs.position = Vector3(x, h + 3.0, z)
		body.add_child(cs)
		placed += 1
	for v in variants.size():
		var list: Array = per_variant[v]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = variants[v]
		mm.instance_count = list.size()
		for k in list.size():
			mm.set_instance_transform(k, list[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.add_to_group("trees")
		root.add_child(mmi)
		# Cheap solid stand-in that only renders into shadow maps.
		var pm := MultiMesh.new()
		pm.transform_format = MultiMesh.TRANSFORM_3D
		pm.mesh = variants[v].get_meta("proxy")
		pm.instance_count = list.size()
		for k in list.size():
			pm.set_instance_transform(k, list[k])
		var pmi := MultiMeshInstance3D.new()
		pmi.multimesh = pm
		pmi.material_override = _shadow_mat()
		pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		root.add_child(pmi)
	print("trees placed: ", placed)


# ---------------------------------------------------------------- rocks & ruins

static func make_rock(rng: RandomNumberGenerator) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.9
	noise.fractal_octaves = 3
	var sm := SphereMesh.new()
	sm.radial_segments = 22
	sm.rings = 14
	var arr := sm.get_mesh_arrays()
	var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var squash := Vector3(rng.randf_range(0.9, 1.4), rng.randf_range(0.5, 0.8), rng.randf_range(0.9, 1.3))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in ii:
		var p: Vector3 = vv[k] * 2.0
		var n := p.normalized()
		var disp := noise.get_noise_3dv(n * 2.0) * 0.45
		# Flatten into facets for a chiseled look.
		var facet := floorf(noise.get_noise_3dv(n * 0.8) * 4.0) * 0.06
		p = n * (1.0 + disp + facet) * squash
		st.add_vertex(p)
	st.generate_normals()
	return st.commit()


static func _rock_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/world/rock.gdshader")
	return m


static func build_rocks(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.run_seed + 77
	var mat := _rock_mat()
	var meshes: Array[ArrayMesh] = []
	var shapes: Array[Shape3D] = []
	for i in 5:
		var m := make_rock(rng)
		m.surface_set_material(0, mat)
		meshes.append(m)
		shapes.append(m.create_convex_shape())
	var body := StaticBody3D.new()
	body.name = "Rocks"
	body.collision_layer = Game.L_WORLD
	root.add_child(body)
	for i in 420:
		var x := rng.randf_range(-230, 230)
		var z := rng.randf_range(-230, 230)
		var d := Vector2(x, z).length()
		if d < 14.0 or d > 240.0:
			continue
		var h := Game.sample_height(x, z)
		if h < Game.WATER_LEVEL - 1.0 or _near_route(x, z, 9.0):
			continue
		var n := Game.sample_normal(x, z)
		var big := rng.randf() < 0.25 or n.y < 0.85
		var s := rng.randf_range(1.2, 3.2) if big else rng.randf_range(0.25, 0.9)
		var v := rng.randi() % meshes.size()
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[v]
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
		var xf := Transform3D(basis.scaled(Vector3(s, s, s)), Vector3(x, h - s * 0.25, z))
		mi.transform = xf
		root.add_child(mi)
		if s > 0.7:
			var cs := CollisionShape3D.new()
			cs.shape = shapes[v]
			cs.transform = xf
			body.add_child(cs)


static func _stone_mat() -> ShaderMaterial:
	if stone_mat == null:
		stone_mat = _rock_mat()
		stone_mat.set_shader_parameter("base_a", Color(0.62, 0.58, 0.52))
		stone_mat.set_shader_parameter("base_b", Color(0.34, 0.32, 0.30))
		stone_mat.set_shader_parameter("moss_amount", 0.55)
		stone_mat.set_shader_parameter("scale", 0.6)
	return stone_mat


static func _stone_piece(root: Node3D, body: StaticBody3D, mesh: Mesh, xf: Transform3D, shape: Shape3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _stone_mat()
	mi.transform = xf
	root.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xf
	body.add_child(cs)


static func _pillar(root: Node3D, body: StaticBody3D, pos: Vector3, height: float, tilt: float, rng: RandomNumberGenerator) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.6
	cyl.height = height
	cyl.radial_segments = 12
	var shape := CylinderShape3D.new()
	shape.radius = 0.6
	shape.height = height
	var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, tilt)
	_stone_piece(root, body, cyl, Transform3D(basis, pos + basis.y * height * 0.5 - Vector3(0, 0.3, 0)), shape)
	# Plinth.
	var box := BoxMesh.new()
	box.size = Vector3(1.7, 0.6, 1.7)
	var bs := BoxShape3D.new()
	bs.size = box.size
	_stone_piece(root, body, box, Transform3D(Basis(Vector3.UP, rng.randf() * 0.3), pos + Vector3(0, 0.0, 0)), bs)


static func fire(parent: Node3D, pos: Vector3, scale: float = 1.0) -> void:
	var p := GPUParticles3D.new()
	p.amount = 48
	p.lifetime = 0.9
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25 * scale
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 1.0 * scale
	pm.initial_velocity_max = 2.2 * scale
	pm.gravity = Vector3(0, 1.5, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var curve := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 0.6))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(1, 0))
	curve.curve = c
	pm.scale_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(4.0, 2.4, 0.8, 1))
	grad.set_color(1, Color(1.5, 0.2, 0.05, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5) * scale
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = _soft_dot()
	q.material = qm
	p.draw_pass_1 = q
	p.position = pos
	parent.add_child(p)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 3.0 * scale
	light.omni_range = 9.0 * scale
	light.shadow_enabled = true
	light.add_to_group("fire_lights")
	light.position = pos + Vector3(0, 0.6, 0)
	parent.add_child(light)
	var crackle := Node3D.new()
	parent.add_child(crackle)
	crackle.position = pos
	Sfx.loop("fire", crackle, -2.0)


static var _dot: GradientTexture2D
static func _soft_dot() -> GradientTexture2D:
	if _dot == null:
		_dot = GradientTexture2D.new()
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(0.5, 0.0)
		# Gaussian-ish falloff so overlapping puffs blend instead of reading as discs.
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.3, Color(1, 1, 1, 0.62))
		g.add_point(0.6, Color(1, 1, 1, 0.18))
		_dot.gradient = g
	return _dot


## Builds husk camps (ruin rings with a brazier). Returns their centers.
## Plans the act's route: a chain of encounter sites leading away from the
## start, ending at the boss arena. Stored in Game.route (last = arena).
static func plan_route() -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.run_seed + 515
	var a0 := rng.randf() * TAU
	var route: Array[Vector3] = []
	var dists := [32.0, 54.0, 76.0, 98.0, 118.0, 136.0]
	for k in dists.size():
		var a: float = a0 + sin(k * 1.3) * 0.45 + rng.randf_range(-0.15, 0.15)
		var best := Vector3.ZERO
		var found := false
		for tries in 60:
			var r: float = dists[k] + rng.randf_range(-6.0, 6.0) * minf(tries, 10) * 0.3
			var aa := a + rng.randf_range(-0.4, 0.4) * minf(tries, 12) / 12.0
			var c := Vector3(cos(aa) * r, 0, sin(aa) * r)
			c.y = Game.sample_height(c.x, c.z)
			var flat := Game.sample_normal(c.x, c.z).y
			if c.y > Game.WATER_LEVEL + 1.0 and flat > (0.93 if k == dists.size() - 1 else 0.88):
				best = c
				found = true
				break
		if not found:
			best = Vector3(cos(a) * dists[k], 0, sin(a) * dists[k])
			best.y = Game.sample_height(best.x, best.z)
		route.append(best)
	Game.route = route
	# Level each fight site (wide for the arena) and re-bake the terrain.
	for i in route.size():
		var last := i == route.size() - 1
		var c := route[i]
		c.y = maxf(c.y, Game.WATER_LEVEL + 1.5)
		Game.flat_spots.append([c, 26.0 if last else 11.0])
		route[i] = c
	Game.bake_heights()
	return route


static func build_ruins(root: Node3D, sites: Array[Vector3]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.run_seed + 909
	var body := StaticBody3D.new()
	body.name = "Ruins"
	body.collision_layer = Game.L_WORLD
	root.add_child(body)
	for c in sites:
		var n := rng.randi_range(6, 9)
		for i in n:
			if rng.randf() < 0.2:
				continue
			var pa := TAU * i / n
			var pp := c + Vector3(cos(pa), 0, sin(pa)) * 8.0
			pp.y = Game.sample_height(pp.x, pp.z)
			_pillar(root, body, pp, rng.randf_range(1.5, 6.5), rng.randf_range(-0.12, 0.12), rng)
		# A fallen column.
		var fc := CylinderMesh.new()
		fc.top_radius = 0.55
		fc.bottom_radius = 0.55
		fc.height = 5.0
		var fs := CylinderShape3D.new()
		fs.radius = 0.55
		fs.height = 5.0
		var fp := c + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
		fp.y = Game.sample_height(fp.x, fp.z) + 0.35
		_stone_piece(root, body, fc, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.FORWARD, PI * 0.5), fp), fs)
		# Brazier.
		var bowl := CylinderMesh.new()
		bowl.top_radius = 0.9
		bowl.bottom_radius = 0.4
		bowl.height = 1.1
		var bsh := CylinderShape3D.new()
		bsh.radius = 0.9
		bsh.height = 1.1
		_stone_piece(root, body, bowl, Transform3D(Basis(), c + Vector3(0, 0.5, 0)), bsh)
		fire(root, c + Vector3(0, 1.2, 0), 1.2)


## Boss arena: a wide ring of tall broken pillars with four braziers.
static func build_arena(root: Node3D, c: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.run_seed + 4040
	var body := StaticBody3D.new()
	body.collision_layer = Game.L_WORLD
	root.add_child(body)
	for i in 14:
		var a := TAU * i / 14.0
		var pp := c + Vector3(cos(a), 0, sin(a)) * 19.0
		pp.y = Game.sample_height(pp.x, pp.z)
		_pillar(root, body, pp, rng.randf_range(5.0, 11.0) if i % 3 != 0 else rng.randf_range(2.0, 4.0), rng.randf_range(-0.08, 0.08), rng)
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		var bp := c + Vector3(cos(a), 0, sin(a)) * 13.0
		bp.y = Game.sample_height(bp.x, bp.z)
		var bowl := CylinderMesh.new()
		bowl.top_radius = 0.9
		bowl.bottom_radius = 0.4
		bowl.height = 1.1
		var bsh := CylinderShape3D.new()
		bsh.radius = 0.9
		bsh.height = 1.1
		_stone_piece(root, body, bowl, Transform3D(Basis(), bp + Vector3(0, 0.5, 0)), bsh)
		fire(root, bp + Vector3(0, 1.2, 0), 1.3)


## The Waygate at the start: an arch with a dormant rift.
static func build_waygate(root: Node3D, pos: Vector3) -> Node3D:
	var body := StaticBody3D.new()
	body.collision_layer = Game.L_WORLD
	root.add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for sx in [-3.2, 3.2]:
		var box := BoxMesh.new()
		box.size = Vector3(1.4, 8.0, 1.4)
		var bs := BoxShape3D.new()
		bs.size = box.size
		_stone_piece(root, body, box, Transform3D(Basis(), pos + Vector3(sx, 4.0, 0)), bs)
	var lintel := BoxMesh.new()
	lintel.size = Vector3(9.0, 1.3, 1.8)
	var ls := BoxShape3D.new()
	ls.size = lintel.size
	_stone_piece(root, body, lintel, Transform3D(Basis(), pos + Vector3(0, 8.4, 0)), ls)
	var step := BoxMesh.new()
	step.size = Vector3(10.0, 0.5, 5.0)
	var ss := BoxShape3D.new()
	ss.size = step.size
	_stone_piece(root, body, step, Transform3D(Basis(), pos + Vector3(0, 0.0, 0)), ss)
	var ring := TorusMesh.new()
	ring.inner_radius = 2.2
	ring.outer_radius = 2.5
	ring.rings = 48
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.1, 0.1, 0.1)
	rm.emission_enabled = true
	rm.emission = Color(0.3, 0.8, 1.0)
	rm.emission_energy_multiplier = 3.0
	ring.material = rm
	var rmi := MeshInstance3D.new()
	rmi.mesh = ring
	rmi.position = pos + Vector3(0, 4.2, 0)
	rmi.rotation.x = PI * 0.5
	root.add_child(rmi)
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 0.8, 1.0)
	l.light_energy = 2.5
	l.omni_range = 14.0
	l.position = pos + Vector3(0, 4.2, 1.0)
	root.add_child(l)
	return rmi


static var _shadow_m: StandardMaterial3D
static func _shadow_mat() -> StandardMaterial3D:
	if _shadow_m == null:
		_shadow_m = StandardMaterial3D.new()
		_shadow_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _shadow_m


static func _near_route(x: float, z: float, r: float) -> bool:
	for i in Game.route.size():
		var c: Vector3 = Game.route[i]
		var rr := r * (1.9 if i == Game.route.size() - 1 else 1.0)
		if Vector2(c.x - x, c.z - z).length() < rr:
			return true
	return false
