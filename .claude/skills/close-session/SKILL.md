---
name: close-session
description: Close out the current Ashfall work session — write a numbered session summary folder and update the master playbook. Use when the user types /close-session.
---

Close out this session so the next one can continue cheaply.

1. List `docs/sessions/` and pick the next number: `session-NN` (two digits, one higher than the highest existing).
2. Create `docs/sessions/session-NN/SUMMARY.md`, under ~40 lines, with these sections:
   - `# Session NN — <focus in a few words>`
   - `## Built` — what changed this session, file names where useful.
   - `## Decisions (picked → rejected)` — every option the user chose and what they turned down, with their reason if given.
   - `## Open / next` — numbered, unfinished items and approved-but-not-done work first.
   - `## Perf baseline` — latest bench numbers if a bench ran.
3. Update `docs/sessions/PLAYBOOK.md`:
   - Add anything new learned about the user's taste or how they like to decide (feedback, corrections, likes/dislikes). Edit existing lines rather than duplicating; remove anything now wrong.
   - Add a row to the Session log table.
   Keep the playbook short — it is read every session.
4. Reply to the user with the folder path, 3–5 bullets of what was recorded, and the one-line prompt they can paste to start the next session.
