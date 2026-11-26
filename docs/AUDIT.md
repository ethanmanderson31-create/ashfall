# Ashfall code audit — prioritized fixes

Nothing here has been changed yet. Approve items by number (e.g. "do 1, 2, 4").
Baseline bench (exported app): Low 140 · Med 112 · High 81 · Ultra 50 FPS.
The bench measures a calm scene. The real problems are **hitches during fights** (spikes, not averages).

| # | Fix | Impact | Effort | Risk |
|---|-----|--------|--------|------|
| 1 | Cache creature meshes per kind | High: removes 25–32 ms spawn hitch | M | Low |
| 2 | Pool shot / hit FX, share materials | High: steady FPS while firing | M | Low |
| 3 | Boss slam rubble → MultiMesh + fewer dust emitters | High: boss-fight frame drops | M | Low |
| 4 | Cache looping sound streams, cap voices | Medium: memory + audio spikes | S | Low |
| 5 | One hitstop owner (`Engine.time_scale`) | Medium: fixes rare "stuck slow-mo" | S | Low |
| 6 | Split `player.gd` into components | Medium: faster, safer edits | L | Medium |
| 7 | Move dev/test code out of `main.gd` | Medium: −400 lines from a core file | S | Low |
| 8 | Split `hud.gd` / `world_builder.gd` | Low–Med: maintainability | M | Low |
| 9 | Small per-frame waste | Low: ~1–3 FPS in big fights | S | Low |

## Performance & memory

**1. Creature mesh caching** — `scripts/enemies/creature_parts.gd`, `creature.gd`
Every ghoul/hound regenerates 38–50 meshes (~13k verts) from scratch on spawn: measured 25–32 ms each, so a 4-enemy ambush wave freezes ~0.1 s. Build each kind's meshes once (static cache, keyed by kind + seed variant), reuse them, vary with scale/shader params. Also merge static body parts that never animate separately → fewer draw calls.

**2. FX pooling** — `scripts/combat/fx.gd`, `player.gd` (`_fire_ray`)
Each shot allocates a light, 3 quads, duplicated materials (`fx.gd:142`), smoke + shell particles, a tracer, impact bursts and a `Label3D` damage number, then frees them. At full auto that's hundreds of nodes/sec and GC churn. Keep small pools (muzzle flash, tracer, impact, damage numbers), reuse shared materials, drive per-instance color via instance uniforms.

**3. Slam rubble** — `scripts/combat/slam_fx.gd`
One slam spawns ~340 rock `MeshInstance3D`s that are moved in GDScript every frame, plus a new `CPUParticles3D` every 0.06 s. Replace rocks with one `MultiMeshInstance3D` per slam (same 4 meshes), and use 2–3 reusable dust emitters with `restart()`.

**4. Audio loops** — `scripts/core/audio.gd`
`Sfx.loop()` duplicates the `AudioStreamWAV` per enemy (breath loops are 0.5–0.7 MB each). Share the stream, pool `AudioStreamPlayer3D`s, cap simultaneous creature voices (~6, nearest wins). XP orbs also each carry an `OmniLight3D` — swap for emissive material.

**5. Hitstop** — `player.gd:876`, `player.gd:1422`, `hud.gd:724`, `pause_menu.gd:234`, `main.gd:527`
Five places write `Engine.time_scale`. Two overlapping hitstops can end in the wrong order (one restores 1.0 while the other wanted 0.35), and pause/unpause can clobber them. Route all through one `Game.hitstop(scale, secs)` that tracks the strongest active request.

## Modularity

**6. player.gd (1,423 lines)** → `player.gd` (movement, health, state) + `gun.gd` + `axe.gd` + `build_stats.gd` (boon ranks, synergies, masteries) + `player_visuals.gd` (weapon looks, celebrations). Biggest win for future work: most requests touch one of these, and smaller files mean fewer accidental breakages.

**7. main.gd (769 lines)** — ~400 lines are screenshot tour / bench / creature showcase. Move to `scripts/dev/`, and the act director (encounters, waves, beacon, boss) to `scripts/core/act_director.gd`. Acts II/III will need that director to be data-driven anyway.

**8. hud.gd (914) / world_builder.gd (852)** — split HUD into satchel / arcana / overlays; split world builder into terrain, foliage and props.

## Small stuff (9)
- HUD rewrites label text every frame → update only on change.
- Enemy death runs `find_children` every frame → cache once.
- Enemy separation is O(n²) → fine now, revisit if waves grow past ~20.
- Timers/tweens that capture nodes which may be freed → check `is_instance_valid`.

## Suggested order
**1 → 2 → 3 → 5** first (felt in play, low risk), then **7 → 6** before starting Act II.
