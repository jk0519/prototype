# Side-view athlete artwork

These are the active athlete textures for SIDEOUT 0.13.0. `scripts/athlete_renderer.gd` attaches the individual parts to the joint positions sampled by `scripts/athlete_pose.gd`. The match uses that same pose for contact centers. This replaces the earlier whole-character action atlas.

The intended construction is a small side-facing athlete: narrow torso, simple profile head without eyes, lean limbs, readable limb overlap, and restrained team colors. The turned torso variant is used during attacks. It is a limited shoulder turn within a side-view game, not a front-facing character rendered small.

## Files and preparation

`source-atlas.png` is the generated 4-column by 3-row source sheet. Its surrounding checker pattern was removed during preparation; the individual runtime parts have transparent backgrounds. The crops are keyed and trimmed, with a one-pixel matte cleanup; the renderer sizes them to the joints. `tools/prepare_side_rig.py` reproduces the preparation from the source sheet with Pillow and NumPy. `-south` variants recolor the jersey/shorts palette for the opposing team. This is asset preparation; the source sheet does not contain the game's action animation.

| Source cell | Runtime part |
| --- | --- |
| Row 1, column 1 | `head.png` |
| Row 1, column 2 | `torso.png` |
| Row 1, column 3 | `torso_turn.png` |
| Row 1, column 4 | `pelvis.png` |
| Row 2, column 1 | `upper_arm.png` |
| Row 2, column 2 | `forearm.png` |
| Row 2, column 3 | `far_upper_arm.png` |
| Row 2, column 4 | `far_forearm.png` |
| Row 3, column 1 | `thigh.png` |
| Row 3, column 2 | `shin.png` |
| Row 3, column 3 | `shoe.png` |
| Row 3, column 4 | `palm.png` |

Near/far layering, limb angles, joint placement, and action timing come from the authored rig code. Body-part dimensions are kept consistent by fixed-length limb solving. The textures are original generated artwork; no character sprites were extracted from The Spike.

## Generation provenance

Generated with the built-in **`image_gen.imagegen`** tool on September 6, 2026. The user-supplied gameplay screenshot was supplied as a visual reference for side-view construction and simplified shapes. The request was for an original athlete and modular body parts, not a copy of a named character.

Final generation prompt:

> Use case: stylized-concept. Asset type: production modular sprite body-part atlas for a 2D SIDE-VIEW volleyball game. The attached gameplay screenshot is ONLY a reference for side-view construction and simple flat graphic shapes. Create original artwork, not that named character. We need SEPARATE CLEAN CUTOUT BODY PARTS, not a whole character, in an EXACT 4 columns x 3 rows equal-cell grid on TRUE TRANSPARENT background. Wide 4:3 canvas, no text, no grid lines, no scene. Every isolated part fits entirely inside its own equal cell with generous transparent margin. Viewpoint consistent SIDE PROFILE FACING RIGHT, lean male young-adult volleyball athlete, pale warm skin, simple dark navy short hair, plain navy short-sleeved jersey with a muted cyan side panel and white shoulder strip, navy shorts, small white court shoes with dark soles, black kneepads. Flat 2D animation artwork like understated sports game sprites: clean small simple shapes, zero eyes/facial expression, slight nose profile, no broad front-facing chest, no glossy highlights, no thick bright outlines, no muscles. Each part is straight, vertically aligned with proximal joint at TOP and distal joint at BOTTOM for rigging, no foreshortening. All parts share same anatomy/style. Cell order LEFT TO RIGHT row1: (1) isolated right-profile HEAD with hair and tiny neck stump, (2) narrow SIDE-PROFILE JERSEY TORSO only, from neck/shoulder top to waist bottom, (3) same jersey torso with modest attacking shoulder turn exposing a little chest, (4) NAVY SHORTS/PELVIS only, side profile. Row2: (5) near UPPER ARM with navy short sleeve at top and bare skin elbow at bottom, (6) near FOREARM only, straight downward with simple SMALL CLOSED PALM at bottom, (7) farther UPPER ARM same proportions slightly darker, (8) farther FOREARM with small open hand at bottom, slightly darker. Row3: (9) THIGH from shorts cuff at top to black KNEEPAD at bottom, slim and straight, (10) LOWER LEG shin only with black kneepad edge at top and ankle bottom, (11) SMALL WHITE SHOE side profile toe pointing right heel left, (12) isolated SMALL OPEN HAND with fingers together, palm in profile pointing upward for toss/contact (wrist bottom). No detached specks, all 12 assets must be present, no completed people. Anatomy should allow graceful side-running and overhead spiking once rigged. Keep two torso variants the same overall height. Every part opaque; everything surrounding parts fully transparent.

The generated sheet did not fulfill the requested true alpha background. Preparation removed its baked-in checker background before the parts were used in the game. Visual suitability must be judged from the assembled athlete moving at gameplay scale, not from this sheet alone.
