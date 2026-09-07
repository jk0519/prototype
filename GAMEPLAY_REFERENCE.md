# The Spike Cross gameplay reference

This document fixes the external gameplay target for SIDEOUT. It separates observed behavior from our implementation so later changes do not drift into a different volleyball game.

## Sources reviewed

- [Official Steam page and media](https://store.steampowered.com/app/3983810/The_Spike_Cross/): current 3v3 presentation, camera composition, character scale, attack effects, and the statement that the player controls one athlete from start to finish.
- [Steam serve controls guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2192840469): movement remains available before the toss; holding the serve input longer throws the ball farther; the jump-serve contact then works like a spike.
- [Current PC control reference](https://kamigame.jp/thespike/page/417805132080669220.html): WASD movement, Z spike/jump, X block, C dive, and Space receive in manual play.
- [Full match footage](https://www.youtube.com/watch?v=kN21zT7xkH0): sampled frame by frame for normal rallies, serves, camera tracking, score changes, and transitions into the next rally.

The dimensions and timings below are measurements from visible frames. They are behavior targets, not claims about The Spike Cross source code.

## Measured targets

- At 1280×720, a grounded athlete normally occupies about 45–65 pixels of visible height. The court remains the dominant shape in the frame.
- The painted court commonly fills roughly 65–82% of the frame width. High tosses and sets pull the camera wider or higher instead of making the athlete dominate the frame.
- Strong contacts keep the ball path readable. Feedback is directional: a stretched ball trail, a short contact flash, a small camera kick or roll, and a brief freeze. The framing does not punch into a large character close-up.
- The server can move horizontally while preparing and charging the toss. The carried ball must remain attached to the displayed hand until a visible release. Toss distance comes from hold duration. Releasing the input throws the ball; movement continues into the approach, jump, and spike-like contact.
- A normal point does not open a result screen or suspend the match. The score changes in the existing court view and the next serve setup follows in about half a second. A separate result view is reserved for the completed match.
- Receives and sets use deliberately readable arcs. Attacks and jump serves change velocity sharply at contact and travel much faster, with a steep downward finish.
- In the official trailer's side-view attack sequence, the guiding arm points toward the ball while the hitting elbow loads behind the head. The hitting arm then extends and follows through across the body. Blocking has a straighter torso and a two-hand overhead reach. These silhouettes need to remain distinct through ascent, contact, descent, and landing; merely changing a hand endpoint does not establish the intended motion.
- The official trailer displays shot speed and height near the action. Our readout explicitly names the latter **contact height** and measures every human and AI contact.

## Speed calibration for 0.14.0

The user requested reasonable serve speeds while retaining arcade movement. For context, the [FIVB 2025 VNL technical report, pages 12–13](https://www.fivb.com/wp-content/uploads/2025/04/VNL2025_Technical_Data-Report.pdf) reports men's average serve speed of **88.1 km/h**, maximum serve speed of **135.2 km/h**, and highest spike contact of **3.50 m**. The report also distinguishes typical speeds from exceptional maximums. These tournament figures inform tuning; they are not measurements of The Spike's simulation.

SIDEOUT now maps its 1,640-unit court to 18 metres, giving **0.0395121951 km/h per world unit/second**. The previous HUD multiplier, `0.058`, overstated speed under this scale. Both the physical attack velocity and the conversion have changed: default serve tuning spans 80–120 km/h and spike tuning 70–125 km/h, with respective hard limits of 125 and 130 km/h after player power multipliers. These profiles are design choices, not claimed real-world ranges or recovered values from The Spike. Trajectories solve for the requested full-vector speed rather than changing only the displayed number.

Contact height uses the same metre conversion on the ball's vertical position at the instant of contact. The existing small athletes, high jumps, low net, and oversized sets remain stylized. Vertical gameplay has not been retuned to match regulation dimensions or the FIVB height figures.

## Prototype constraints

- Keep all six athletes and the relevant ball path readable in ordinary play.
- Keep A/D as movement in every serve phase. X hold duration sets forward toss distance; W/S remains an additional vertical-toss control for this prototype.
- Keep the server behind the line until the hit, including while airborne, as requested for this prototype. Preserve backward access to the service apron after contact. Warn when a charged toss needs more room behind the line. This is our explicit serving constraint, not a claim about every rule variant in the reference game.
- Capture outgoing speed and contact height for all seven player-contact actions on both teams. Faults and non-player collisions must not fabricate shots; measurements remain fixed as the ball continues to fly.
- Keep the live court active through ordinary score changes and automatically stage the next server.
- Preserve one-human-plus-five-AI 3v3 play. All roles continue to use the same movement and contact simulation so control can be reassigned later.
- Tune against captured full sequences—serve setup through landing and point through next serve—rather than judging isolated pose screenshots.
