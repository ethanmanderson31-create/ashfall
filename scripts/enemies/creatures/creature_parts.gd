class_name CreatureParts
extends RefCounted
## Organic mesh primitives for procedurally built creatures. Everything is a
## deformed capsule/sphere with noise displacement, smooth normals, and an
## origin at the joint so parts can be hung off a skeleton of Node3D joints.

static var _flesh_cache := {}
static var _bone_mat: ShaderMaterial
static var _eye_mat: StandardMaterial3D


static func flesh(crack_amount: float, ember := Color(1.0, 0.34, 0.07), key := "") -> ShaderMaterial:
	var k := "%s_%.2f_%s" % [key, crack_amount, ember.to_html()]
	if _flesh_cache.has(k):
		return _flesh_cache[k]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/creatures/ember_flesh.gdshader")
	m.set_shader_parameter("crack_amount", crack_amount)
	m.set_shader_parameter("ember", ember)
	_flesh_cache[k] = m
	return m


static func bone() -> ShaderMaterial:
	if _bone_mat == null:
		_bone_mat = ShaderMaterial.new()
		_bone_mat.shader = load("res://shaders/world/rock.gdshader")
		_bone_mat.set_shader_parameter("base_a", Color(0.58, 0.52, 0.44))
		_bone_mat.set_shader_parameter("base_b", Color(0.2, 0.17, 0.14))
		_bone_mat.set_shader_parameter("moss_amount", 0.0)
		_bone_mat.set_shader_parameter("scale", 3.0)
	return _bone_mat


static func eye(c := Color(1.0, 0.55, 0.15)) -> StandardMaterial3D:
	if _eye_mat == null:
		_eye_mat = StandardMaterial3D.new()
		_eye_mat.albedo_color = Color(0.1, 0.05, 0.02)
		_eye_mat.emission_enabled = true
		_eye_mat.emission = c
		_eye_mat.emission_energy_multiplier = 9.0
	return _eye_mat


static func _noise(seed: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq
	n.fractal_octaves = 3
	return n


static func _build(arr: Array, xform: Callable) -> ArrayMesh:
	var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var out := PackedVector3Array()
	out.resize(vv.size())
	for k in vv.size():
		out[k] = xform.call(vv[k])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in ii:
		st.set_uv(uv[k])
		st.add_vertex(out[k])
	st.index()
	st.generate_normals()
	return st.commit()


## Tapered, muscled limb hanging along -Y from the joint at the origin.
## bulge > 0 swells the middle like a muscle belly; flat squashes along Z.
static func limb(length: float, r0: float, r1: float, seed: int, bulge := 0.25, rough := 0.18, flat := 1.0) -> ArrayMesh:
	var cap := CapsuleMesh.new()
	cap.radius = 1.0
	cap.height = 4.0
	cap.radial_segments = 16
	cap.rings = 10
	var nz := _noise(seed, 1.6)
	var fn := func(p: Vector3) -> Vector3:
		var t := clampf((2.0 - p.y) / 4.0, 0.0, 1.0)
		var r := lerpf(r0, r1, t) * (1.0 + bulge * sin(PI * clampf(t * 1.15, 0.0, 1.0)))
		var side := Vector3(p.x, 0, p.z)
		var d := nz.get_noise_3d(p.x * 1.3, t * length * 3.0, p.z * 1.3)
		var q := side * r * (1.0 + d * rough)
		q.z *= flat
		return Vector3(q.x, -t * length * 1.12 + length * 0.06, q.z)
	return _build(cap.get_mesh_arrays(), fn)


## Lumpy ellipsoid (torsos, heads, sacs) centred on the origin.
static func blob(radii: Vector3, seed: int, rough := 0.15, freq := 1.4) -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 24
	sm.rings = 16
	var nz := _noise(seed, freq)
	var fn := func(p: Vector3) -> Vector3:
		var d := nz.get_noise_3dv(p * 1.5)
		return p * radii * (1.0 + d * rough)
	return _build(sm.get_mesh_arrays(), fn)


## Curved horn / claw / spike, base at origin, growing along -Y and curling
## toward +Z (or -Z with negative curl).
static func horn(length: float, radius: float, curl: float, seed: int) -> ArrayMesh:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 0.02
	cyl.height = 2.0
	cyl.radial_segments = 10
	cyl.rings = 8
	var nz := _noise(seed, 3.0)
	var fn := func(p: Vector3) -> Vector3:
		var t := clampf((1.0 - p.y) / 2.0, 0.0, 1.0)
		var r := radius * (1.0 + nz.get_noise_1d(t * 10.0) * 0.12)
		return Vector3(p.x * r, -t * length, p.z * r + curl * t * t * length)
	return _build(cyl.get_mesh_arrays(), fn)


static func part(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func joint(parent: Node3D, name: String, pos: Vector3, rot := Vector3.ZERO) -> Node3D:
	var j := Node3D.new()
	j.name = name
	j.position = pos
	j.rotation = rot
	parent.add_child(j)
	return j
