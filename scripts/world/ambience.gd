extends Node
## World ambience around the player: wildlife over the valley, and water
## lapping at whichever shore is nearest (the emitter slides along the bank).

var shore: Node3D
var _scan_t := 0.0
var _target := Vector3.ZERO
var _near := false


func _ready() -> void:
	Sfx.loop("wildlife", self, -20.0)
	shore = Node3D.new()
	Game.world.add_child.call_deferred(shore)
	shore.ready.connect(func(): Sfx.loop("shore", shore, -3.0, 4.0, 32.0))


func _process(delta: float) -> void:
	var p := Game.player
	if p == null or shore == null or not shore.is_inside_tree():
		return
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.4
		_scan(p.global_position)
	if _near:
		shore.global_position = shore.global_position.lerp(_target, 1.0 - exp(-3.0 * delta))
	else:
		shore.global_position = p.global_position + Vector3(0, 200, 0)


## Nearest point within ~28 m where the ground crosses the waterline.
func _scan(at: Vector3) -> void:
	var best := INF
	for k in 24:
		var a := TAU * k / 24.0
		var dir := Vector3(cos(a), 0, sin(a))
		var prev := Game.sample_height(at.x, at.z) > Game.WATER_LEVEL
		var r := 1.5
		while r < 28.0:
			var q := at + dir * r
			var land := Game.sample_height(q.x, q.z) > Game.WATER_LEVEL
			if land != prev:
				if r < best:
					best = r
					_target = Vector3(q.x, Game.WATER_LEVEL + 0.2, q.z)
				break
			r += 1.5
	if best < INF and not _near:
		shore.global_position = _target
	_near = best < INF
