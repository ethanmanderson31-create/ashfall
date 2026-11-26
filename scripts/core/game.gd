extends Node
## Global state + world height function shared by every system.

const MAP_SIZE := 512.0
const TERRAIN_RES := 256
const WATER_LEVEL := -2.5

const L_WORLD := 1
const L_PLAYER := 2
const L_ENEMY := 4

var noise_base := FastNoiseLite.new()
var noise_detail := FastNoiseLite.new()
var noise_ridge := FastNoiseLite.new()
var noise_forest := FastNoiseLite.new()

var heights := PackedFloat32Array()
var player: CharacterBody3D
var hud: CanvasLayer
var world: Node3D
var shot_mode := false
var env: Environment
var sun: DirectionalLight3D
var grass_holder: Node3D
var route: Array[Vector3] = []
## [center(Vector3 with y = target height), radius] pads levelled for fights.
var flat_spots: Array = []
var run_seed := 1337
var run_count := 0


func _init() -> void:
	new_run(true)
	run_count = 0


## Each run reshapes the whole map (hills, lakes, forests, camp sites).
func new_run(fixed: bool) -> void:
	run_count += 1
	randomize()
	run_seed = 1337 if fixed else randi() % 1000000
	flat_spots.clear()
	route.clear()
	noise_base.seed = run_seed
	noise_base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_base.frequency = 0.0045
	noise_base.fractal_octaves = 4
	noise_detail.seed = run_seed + 77
	noise_detail.frequency = 0.035
	noise_detail.fractal_octaves = 3
	noise_ridge.seed = run_seed + 4242
	noise_ridge.frequency = 0.008
	noise_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise_ridge.fractal_octaves = 4
	noise_forest.seed = run_seed + 99
	noise_forest.frequency = 0.012


func height_at(x: float, z: float) -> float:
	var h := noise_base.get_noise_2d(x, z) * 20.0
	h += noise_detail.get_noise_2d(x, z) * 1.6
	var d := Vector2(x, z).length()
	# Flat-ish meadow around the start point.
	h = lerpf(1.0 + noise_detail.get_noise_2d(x, z) * 0.4, h, smoothstep(22.0, 70.0, d))
	# Mountain ring that bounds the map.
	var edge := smoothstep(165.0, 240.0, d)
	h += edge * (25.0 + (noise_ridge.get_noise_2d(x, z) * 0.5 + 0.5) * 55.0)
	for s in flat_spots:
		var c: Vector3 = s[0]
		var r: float = s[1]
		var w := 1.0 - smoothstep(r * 0.65, r * 1.35, Vector2(x - c.x, z - c.z).length())
		h = lerpf(h, c.y, w)
	return h


func bake_heights() -> void:
	var r1 := TERRAIN_RES + 1
	var step := MAP_SIZE / TERRAIN_RES
	heights.resize(r1 * r1)
	for j in r1:
		for i in r1:
			heights[j * r1 + i] = height_at(-MAP_SIZE * 0.5 + i * step, -MAP_SIZE * 0.5 + j * step)


## Fast bilinear lookup into the baked grid (matches the rendered terrain).
func sample_height(x: float, z: float) -> float:
	var r1 := TERRAIN_RES + 1
	var step := MAP_SIZE / TERRAIN_RES
	var fx := clampf((x + MAP_SIZE * 0.5) / step, 0.0, TERRAIN_RES - 0.001)
	var fz := clampf((z + MAP_SIZE * 0.5) / step, 0.0, TERRAIN_RES - 0.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var a := heights[j * r1 + i]
	var b := heights[j * r1 + i + 1]
	var c := heights[(j + 1) * r1 + i]
	var d := heights[(j + 1) * r1 + i + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


func sample_normal(x: float, z: float) -> Vector3:
	var e := 1.0
	var hl := sample_height(x - e, z)
	var hr := sample_height(x + e, z)
	var hd := sample_height(x, z - e)
	var hu := sample_height(x, z + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()
