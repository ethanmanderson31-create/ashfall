# Ashfall Playbook — read this first every session

Master guide to how we build this game and how the user likes to work. Keep it short; update it at each /close-session.

## How the user makes decisions
- **Wants to be part of every look/feel decision.** For visuals, animation, sound and feel: build 2–4 real options, show them, let them pick, *then* build the final one.
- **Options must be real**: in-engine screenshots or GIFs (`-- --shots`, `--fixed-fps 30` recordings → `tools/frames_to_gif.py`), playable sounds on the sound board. Flat 2D/SVG mockups were rejected.
- Use the multiple-choice question tool with previews when offering options.
- For mechanical tweaks (numbers, bugs, "make X happen more often") → just do it, no options.
- Gives feedback after playtesting in long multi-item messages → address **every** item; keep a checklist.
- Likes a walkthrough of *why* (e.g. explain how boons are rewarded) along with the change.
- Asked to approve before big refactors (audit fixes need a yes first).
- After changes: export the app to the Desktop so they can play it.

## Taste learned so far
- **Style:** grounded/realistic fantasy, not "Roblox". Molten-rock creatures (charred basalt + glowing ember cracks). Effects should match that palette (e.g. slam ring uses the creature `ember_flesh` shader).
- **UI:** clean, professional; text must fit its boxes. No on-screen hand-holding prompts like "JUMP!".
- **Combat feel:** heavy, impactful melee; satisfying combos; rolls keep momentum, slower somersault (not rushed), cooldown so it can't be spammed; scarce ammo forcing melee.
- **Sound likes:** recorded AR-15 gun (tried the AK, came back to the AR-15), soft ember-puff XP, heavy low axe swing (Swing 3), heavy axe draw, deep low-boom explosions, crunchy heavy axe hits, potion sounds, body-roll thud, simple Skyrim-style jump/land (style only — no Skyrim assets). World: crickets over birds, trickling water at shores, gentle swim paddle, splashy wading, gear-jingle footsteps, ember-crunch creature steps, fading-heartbeat death.
- **Sound dislikes:** bells, harsh/crunchy card sounds, low "boing" sweeps, whooshes for rolls, booms on jump/land, loud in-your-face player-hit, monsters audible at range or after death, anything loud and in-your-face on reward moments (Codex book opening turned down to -13 dB).
- **UI/reward sounds:** fantasy, whimsical, quiet (harp, flute, sparkle).
- **Monsters:** constant breathing that gets louder up close; grunt + crunch when they hit you.
- **Rewards:** boons should feel exciting (tarot deal/flip/claim, celebration effects, weapon looks change with builds).

## How to operate
- Read `CLAUDE.md` (commands, rules) and the newest `docs/sessions/session-NN/SUMMARY.md`.
- Verify with screenshots (`--shots`) and check for `SCRIPT ERROR`; look at the images.
- Only CC0 assets; record in `assets/audio/CREDITS.md`.
- Delete replaced/unchosen options and files once the user picks.
- Keep files organized by folder; don't grow big files — add new scripts.

## Session log
| # | Focus | Summary |
|---|-------|---------|
| 1 | Built the game through Act I + boss, sound, audit | [session-01](session-01/SUMMARY.md) |
