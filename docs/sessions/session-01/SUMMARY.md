# Session 1 — Act I playable end-to-end

## Built
- Godot 4.7 project, all built in code. Open procedural world, quality presets (Low/Med/High/Ultra), Mac app export to Desktop.
- Player: Soldier, rifle (recoil, reload anim, scarce ammo), heavy battle axe with combo, rifle bash, Point Blank / Bash Shot combos, jump bash, combat somersault roll, weapon switch on scroll.
- Enemies (Act I): Ash Ghoul, Ashhound (procedural molten-rock creatures). Brute/Spitter exist for later acts.
- Boss: Ashen Colossus (HP 3400, slam with ember telegraph ring + rubble wavefront, 2 summons per threshold).
- Act flow: ember beacon → 5 ambush sites → Ember Codex tome → Tarot of Embers boon cards → boss.
- Builds: Arcana tree (Tab), masteries on 3rd boon per branch, synergies, weapon looks change with builds.
- Potions: 4 rarities, 3 slots (keys 1–3). Pause menu: quality, sensitivity, invert Y, keybinds, volume sliders.
- Audio: catalog via `tools/build_sound_catalog.py`; sound board artifact https://claude.ai/artifact/Sp3frs4WHUvUf2m1a2HEST

## Decisions (picked → rejected)
- Creatures: molten rock → other fantasy styles. Boons: tarot cards. Boss slam: Rubble Eruption. Roll: slow somersault with slide.
- Sounds: see PLAYBOOK taste list. Last change: removed "JUMP!" prompt; slam rings use creature ember shader.

## Open / next
1. **Audit fixes awaiting approval** — `docs/AUDIT.md`. Recommended first: 1, 2, 3, 5 (creature mesh cache, FX pooling, slam rubble MultiMesh, single hitstop owner). Then 7 → 6 before Act II.
2. Act 1 ideas not built: ember currency + merchant, optional champion site, explosive ember pods, boss intro + phase change, meta-progression between runs.
3. Acts II and III not started.

## Perf baseline
Bench (exported): Low 140 · Med 112 · High 81 · Ultra 50 FPS.
