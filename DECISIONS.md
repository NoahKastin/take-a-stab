# Pending Decisions

Open design/architecture calls that need a human decision before downstream work can proceed. Each entry has the conflict, the options with tradeoffs, and any reference material needed to act on it. When a decision is resolved, remove the entry (or mark it `Status: Closed` with the chosen option).

---

## Watch architecture: wrist-mounted vs. camera-parented

**Status:** Closed 2026-04-07 — **Option 2 chosen: wrist-mounted watch, rewrite `_setup_watch()`**.

**Resolution rationale:** The user clarified that the "always-visible / no-bob during stab" framing in the current code comment at `scenes/player/player.gd:163-164` was a workaround for the watch having been positioned too far behind the camera such that it was *only* visible during stabs — not a deep design principle. With a properly-placed wrist-mounted watch, usual visibility is expected in the default first-person pose; bobbing during stabs and occasional occlusion in extreme arm poses are acceptable trade-offs for the literal-to-design immersion gain. The user explicitly accepts the implementation cost (Meshy generation, `_setup_watch()` rewrite, death-sequence camera pan rework, likely follow-up bug fixes).

### Follow-up work

1. ~~**Model generation**~~ — Done (2026-04-10, Tripo). All three .glb files in project root.
   - **Blender cleanup still needed on left arm:** move watch to inner wrist, ensure watch face is a clean flat surface, fix finger grip around knife handle. Right arm and zombie look good as-is.
2. **`_setup_watch()` rewrite** in `scenes/player/player.gd:109-197`:
   - Delete the code-generated `BoxMesh` body creation — the imported arm has its own watch body.
   - Locate the flat watch-face surface on the imported arm (the Meshy prompt instructs that the face must be a single flat rectangular surface for runtime retexturing).
   - Apply the `SubViewport` texture as a surface override material on that face, instead of creating a fresh `QuadMesh`.
   - Re-parent the watch logic to a wrist bone on the imported arm rig instead of `camera_pivot`.
3. **Death-sequence camera pan** at `scenes/player/player.gd:396-400`: currently uses a hardcoded `Vector3(-0.51, 0.44, 0)` rotation aimed at the camera-parented watch position. Needs to dynamically look up the wrist bone's world position and aim there.
4. **Retain** `scenes/player/player.gd:48-53` — variable declarations for `watch_viewport`, `watch_mesh`, and the kills/time/high-score/play-again labels. Only their host mesh changes.
5. **Visibility check after rewrite:** verify the watch is actually visible in the default first-person pose. The original bug (commit `5d03ebf`) was that the left arm was mounted at 45° from camera center while the camera's half-FOV is only 37.5°, so the wrist (and any watch on it) was off-screen except during stab animations. That commit's fix was to abandon wrist-mounting entirely and parent the watch to `camera_pivot`. Now that we're committing to wrist-mounting again, the visibility fix has to come from elsewhere: bring the left-arm mount position in the player scene closer to camera center, adjust the arm pose so the wrist swings inward, or widen the camera FOV. **Do not** revert to camera-parenting — that would re-close this decision for the wrong reason. The Meshy prompt itself only controls the arm's *pose* and *internal geometry*, not its mount transform in the player scene, so prompt tweaks alone won't fix this kind of visibility failure.

### Model generation prompts

**Left arm (with watch):**
```
First-person left forearm and hand of a strong young Black woman, gripping a thin combat knife in a closed fist. The left wrist wears a chunky rectangular gold wristwatch with a gold metal link band. The watch face must be a single flat rectangular surface, oriented so it is clearly visible to the camera in the first-person pose — not on the back of the wrist where it would face away from the player. Sleeveless, visible from just below the elbow to the fingertips. Stylized low-poly aesthetic, clean topology suitable for animation. Pose: arm extended forward from the player's POV, knife angled slightly inward toward center of view, blade pointing upward. Knife: simple straight ~30cm blade with a dark wrapped handle. Plain neutral background.
```

**Right arm (with glove):**
```
First-person right forearm and hand of a strong young Black woman, gripping a thin combat knife in a closed fist. The hand wears a gold fingerless metallic glove (knuckles and back of hand covered, fingertips bare). Sleeveless, visible from just below the elbow to the fingertips. Stylized low-poly aesthetic, clean topology suitable for animation. Pose: arm extended forward from the player's POV, wrist neutral, knife angled slightly inward toward center of view, blade pointing upward. Knife: simple straight ~30cm blade with a dark wrapped handle. Plain neutral background.
```

**Zombie:**
```
Low-poly humanoid character, bald with no hair or hat, wide circular eyes. Wearing bell-bottom pants, platform shoes, and open-collar disco shirt. T-pose. Plain neutral background.
```
