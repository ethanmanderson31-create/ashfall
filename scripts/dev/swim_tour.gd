class_name SwimTour
extends RefCounted
## Dev tour: `-- --shots --swim`. Finds the lakes and islands on the map,
## walks the soldier off the nearest shore and swims him to an island,
## saving screenshots (screenshots/swim_*.png) and a GIF frame dump
## (screenshots/swim.rgb, 480x270) of the stroke.

const STEP := 4.0
const HALF := 200.0
const GIF_W := 480
const GIF_H := 270


## Land components that aren't connected to the start meadow by land.
static func find_islands() -> Array:
	var n := int(HALF * 2.0 / STEP)
	var land := PackedByteArray()
	land.resize(n * n)
	for j in n:
		for i in n:
			var x := -HALF + i * STEP
			var z := -HALF + j * STEP
			land[j * n + i] = 1 if Game.sample_height(x, z) > Game.WATER_LEVEL + 0.2 else 0
	var comp := PackedInt32Array()
	comp.resize(n * n)
	comp.fill(-1)
	var comps: Array = []
	for start in n * n:
		if land[start] == 0 or comp[start] >= 0:
			continue
		var id := comps.size()
		var cells: Array[int] = [start]
		comp[start] = id
		var k := 0
		while k < cells.size():
			var c := cells[k]
			k += 1
			var ci := c % n
			var cj := c / n
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var ni: int = ci + d[0]
				var nj: int = cj + d[1]
				if ni < 0 or nj < 0 or ni >= n or nj >= n:
					continue
				var nc := nj * n + ni
				if land[nc] == 1 and comp[nc] < 0:
					comp[nc] = id
					cells.append(nc)
		comps.append(cells)
	var mi := int(HALF / STEP)
	var main_id := comp[mi * n + mi]
	var out: Array = []
	for id in comps.size():
		if id == main_id or comps[id].size() < 3:
			continue
		var sum := Vector3.ZERO
		for c in comps[id]:
			sum += Vector3(-HALF + (c % n) * STEP, 0, -HALF + (c / n) * STEP)
		var center: Vector3 = sum / comps[id].size()
		center.y = Game.sample_height(center.x, center.z)
		out.append({"center": center, "cells": comps[id].size(), "area": comps[id].size() * STEP * STEP})
	return out


## Walks from the island toward the map centre: island → water → mainland.
## Returns a point a few metres inland from where the mainland starts, and
## prints the depth profile of the crossing.
static func shore_toward(island: Vector3) -> Vector3:
	var dir := Vector3(-island.x, 0, -island.z).normalized()
	var p := island
	var state := 0
	var prof := []
	for i in 300:
		p += dir
		var h := Game.sample_height(p.x, p.z)
		if state == 0 and h < Game.WATER_LEVEL:
			state = 1
		if state == 1:
			prof.append(snappedf(Game.WATER_LEVEL - h, 0.1))
			if h > Game.WATER_LEVEL + 0.3:
				print("crossing depth profile (m): ", prof)
				return p + dir * 4.0
	return island + dir * 30.0


static func run(main: Node) -> void:
	var player: CharacterBody3D = main.player
	var tree := main.get_tree()
	player.input_enabled = false
	main.hud.visible = false
	main.set_process(false)   # no ambushes during the tour
	var islands := find_islands()
	islands.sort_custom(func(a, b): return (a.center as Vector3).length() < (b.center as Vector3).length())
	print("ISLANDS: ", islands.size())
	for isl in islands:
		print("  island at ", (isl.center as Vector3).round(), "  area ", isl.area, " m2")
	if islands.is_empty():
		print("no islands found")
		tree.quit()
		return
	var target: Vector3 = islands[0].center
	for isl in islands:
		if isl.area >= 64.0:
			target = isl.center
			break
	var start := shore_toward(target)
	print("swim from ", start.round(), " to ", target.round())
	main._teleport(start)
	main._face_player_to(target)
	player.pitch = -0.18
	await tree.create_timer(1.0).timeout

	var side := Camera3D.new()
	side.fov = 45.0
	main.add_child(side)
	var f := FileAccess.open(ProjectSettings.globalize_path("res://screenshots/swim.rgb"), FileAccess.WRITE)
	player.force_move = Vector2(0, -1)
	var t := 0.0
	var shots := {1.4: "swim_01_wade_in", 3.2: "swim_02_crawl_chase", 5.0: "swim_03_crawl_side", 6.6: "swim_04_crawl_front"}
	var frame := 0
	var stop_at := 9.0
	while t < 60.0:
		var dt := tree.root.get_process_delta_time()
		t += dt
		var fwd := Vector3(-sin(player.face_yaw), 0, -cos(player.face_yaw))
		var right := Vector3(cos(player.face_yaw), 0, -sin(player.face_yaw))
		var body: Vector3 = player.global_position + Vector3(0, 1.2, 0)
		if t > 4.2 and t < 5.8:
			side.global_position = body + right * 3.4 + fwd * 0.6 + Vector3(0, 0.9, 0)
			side.look_at(body + fwd * 0.3)
			side.current = true
		elif t > 5.8 and t < 7.0:
			side.global_position = body + fwd * 3.6 + right * 1.2 + Vector3(0, 1.0, 0)
			side.look_at(body)
			side.current = true
		elif t > 9.0 and t < 12.0:
			side.global_position = body + fwd * 3.0 + right * 2.0 + Vector3(0, 0.7, 0)
			side.look_at(body + Vector3(0, 0.2, 0))
			side.current = true
		else:
			player.cam.current = true
		# Tread water for a few seconds, then finish the swim.
		if t > stop_at and t < stop_at + 3.0:
			player.force_move = Vector2.ZERO
		else:
			player.force_move = Vector2(0, -1)
			main._face_player_to(target)
		await RenderingServer.frame_post_draw
		for k in shots:
			if t >= k and not main.has_meta(shots[k]):
				main.set_meta(shots[k], true)
				await main._shot(shots[k])
		if t > stop_at + 2.0 and not main.has_meta("tread"):
			main.set_meta("tread", true)
			await main._shot("swim_05_tread")
		frame += 1
		if frame % 2 == 0 and t > 2.0 and t < 12.0:
			var img := main.get_viewport().get_texture().get_image()
			img.resize(GIF_W, GIF_H, Image.INTERPOLATE_BILINEAR)
			img.convert(Image.FORMAT_RGB8)
			f.store_buffer(img.get_data())
		if not player.swim.swimming and t > 12.0:
			break
	f.close()
	player.force_move = Vector2(0, -1)
	await tree.create_timer(1.5).timeout
	player.force_move = Vector2.ZERO
	player.cam.current = true
	await tree.create_timer(0.6).timeout
	await main._shot("swim_06_on_island")
	print("final pos ", player.global_position.round(), " swimming=", player.swim.swimming)
	tree.quit()
