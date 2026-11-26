# Ashfall

Third-person roguelike shooter built with Godot 4.7. Fight through 3 acts, each ending in a boss.
Each run builds a new world and offers different boons. When you die, the run resets.

## Run it

    ~/Applications/Godot.app/Contents/MacOS/Godot --path ~/Documents/Claude/ashfall

Screenshot mode (renders stills to `screenshots/` and quits):

    ~/Applications/Godot.app/Contents/MacOS/Godot --path . -- --shots

## Standalone app

`~/Applications/Ashfall.app` opens from Finder, Launchpad or Spotlight. Rebuild it after changes with:

    tools/export_mac.sh

## Graphics

F1 cycles Low, Medium, High and Ultra (the choice is saved). F3 toggles the FPS counter. F11 toggles fullscreen.
Measured on an M2 Pro: Low about 145 FPS, Medium about 118, High about 79 (the default), Ultra about 40.

## Controls

| Key | Action |
| --- | --- |
| WASD / Shift / Space | Move / sprint / jump (double jump with *Updraft*) |
| Mouse, RMB, LMB | Look, aim, and fire or swing (whichever weapon is out) |
| Scroll up / down | Draw the rifle / draw the axe |
| 1, 2, 3 | Drink the potion in that satchel slot |
| Esc | Pause menu: quality, sensitivity, keybinds |
| F (or V) | Rifle out: **Rifle Bash** (bash right after shooting = *Point Blank*; shoot right after a bash hit = *Bash Shot*, a guaranteed crit). Axe out: axe swing |
| Attack in mid-air | **Jump Bash**: plunge into the ground for area damage, then a short rooted recovery (*Meteor* makes it bigger and faster) |
| E | Read the Ember Codex at a cleared site to choose a boon |
| C / Ctrl | Combat roll: a forward somersault into a short slide, briefly invulnerable, with a cooldown |
| R | Reload (uses reserve ammo, which is limited) |
| Tab | The Ember Arcana (build tree) |

## Folder layout

| Folder | What lives there |
| --- | --- |
| `scenes/` | Entry scene (`main.tscn`). `scenes/ui/` is for future authored UI scenes |
| `scripts/core/` | `game.gd` (global state, run seed, height function) and `main.gd` (run bootstrap, camps, screenshot mode) |
| `scripts/player/` | `player.gd` (movement, gun, blade, build stats) and `aim_modifier.gd` (procedural spine and arm IK pose) |
| `scripts/enemies/` | `enemy.gd` (ghoul and hound tactical AI) and `boss_colossus.gd` (Act I boss) |
| `scripts/enemies/creatures/` | Procedural monsters: `creature_parts.gd` (organic meshes) and `creature.gd` (rigs, animation clips, death dissolve) |
| `scripts/combat/` | `fx.gd` (muzzle flash, impacts, axe hits), `slam_fx.gd` (Rubble Eruption ground slam) and `blade_wave.gd` (Bladestorm projectile) |
| `scripts/items/` | `consumables.gd` (potion data, rarities, drop rolls) |
| `scripts/pickups/` | `pickup.gd` (XP embers and ammo cells) and `ember_tome.gd` (boon lectern at cleared sites) |
| `scripts/progression/` | `skill_tree.gd` (3 branches, tiers, keystones, random boon offers) |
| `scripts/ui/` | `hud.gd` (HUD, satchel, arcana tree, death summary), `boon_menu.gd` (Tarot cards dealt and flipped), `pause_menu.gd` and `loading_screen.gd` |
| `shaders/ui/` | Card frame and branch sigil shaders |
| `scripts/world/` | `world_builder.gd` (procedural terrain, grass, trees, rocks, ruins, Waygate) |
| `shaders/world/` | Terrain, grass, foliage, rock/stone and water shaders |
| `shaders/creatures/` | `ember_flesh.gdshader` (molten-rock creature skin) |
| `shaders/common/` | Shared noise and voronoi include |
| `assets/models/player/` | Player character model and its textures |
| `assets/audio/` | Sound effects: `creatures/`, `weapons/`, `items/`, `ui/` (CC0 recordings) and `synth/` (generated) |
| `animations/player/`, `animations/enemies/` | Standalone animation libraries (.res/.glb), added here as they are made |
| `screenshots/` | Output of screenshot mode |
| `tools/` | Build scripts (`export_mac.sh`) |
| `build/` | Export output (ignored by Godot) |

## Builds (skill tree)

- **Gunslinger:** damage, fire rate, ammo, crits, piercing and explosive rounds. Keystones: *Lead Storm*, *Overclock*.
- **Blademaster:** melee damage and speed, high jump, double jump, lunge, ground slam, dash slicing. Keystones: *Bladestorm*, *Frenzy*.
- **Warden:** health, regeneration, armor, shields, thorns, mobility. Keystones: *Phoenix*, *Juggernaut*.

Boons come only from the Ember Codex at each cleared site and from the boss: about 6 per act. Each Codex deals 3 random cards from the unsealed tiers. Tiers unseal at 1, 3 and 5 boons in a branch. Your **3rd boon in a branch awakens its mastery**: Hot Streak (Gunslinger), Ember Combo, which unlocks the 3-hit axe combo (Blademaster), and Ember Ward (Warden). Level-ups give +6 max health and +4% damage with no menu.

## Audio

`scripts/core/audio.gd` (the `Sfx` autoload) holds the sound catalog. Every slot lists its options (A, B, C), matching the Ashfall Sound Board page (`docs/soundboard/`), and `PICKS` chooses which option the game uses. Sounds are routed to Effects, Creatures and Ambience buses, with volume sliders in the pause menu. Recorded sounds are CC0 (see `assets/audio/CREDITS.md`); everything in `assets/audio/synth/` is generated by `tools/sfx_synth.py`.

## Synergies

Owning both halves of a synergy unlocks a bonus effect. They're listed at the bottom of the Arcana (Tab), and a card tells you when picking it would complete one.

| Synergy | Needs | Effect |
| --- | --- | --- |
| Molten Edge | Honed Edge + Ember Rounds | Axe hits set creatures ablaze |
| Gunblade | Hot Streak + Ember Combo masteries | Every axe hit primes an explosive round |
| Ironclad Fury | Plating + Flowing Strikes | Axe hits grant 8 shield (up to 40) |
| Hunter's Mark | Deadeye + Lunge | Lunging hits mark prey: +50% gun damage to it for 4s |
| Ember Dancer | Phase Step + Hair Trigger | Rolling grants +40% fire rate for 2s |

Your weapons change as your build grows. The rifle's trim brightens and gains runes, and it smoulders at mastery. The axe grows and its edge burns, wreathed in flame at mastery. Warden boons give you an ember aura.

## Consumables

Rare potions in 4 rarities (Common, Rare, Epic, Legendary), roughly 2 per act. They drop from about 1 in 40 kills, 1 in 4 elites, and always from the boss. You can hold 3 and drink them with keys 1–3. Effects include healing, strength, speed, stoneskin and endless ammo; legendaries are stronger and last longer.

## Act structure

Act I is a route of 5 ambush sites marked by an ember beacon, ending in the Colossus arena. Fights grow from 2 ghouls to mixed packs with elites and second waves. Each cleared site raises an Ember Codex on a lectern at its center. Read it (E) to draw one of three Tarot of Embers boon cards, plus 20 health and 20 rounds. Ammo is scarce: about 1 kill in 5 drops 3–6 rounds, and elites drop 12. The Colossus rumbles with every step, turns the arena blood-red, and its slam bursts the ground into an expanding ring of rubble that you must jump.

Showcase renders of the creatures: `Godot --path . -- --shots --creatures`
