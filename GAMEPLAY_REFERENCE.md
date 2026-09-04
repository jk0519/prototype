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

## Prototype constraints

- Keep all six athletes and the relevant ball path readable in ordinary play.
- Keep A/D as movement in every serve phase. X hold duration sets forward toss distance; W/S remains an additional vertical-toss control for this prototype.
- Keep the live court active through ordinary score changes and automatically stage the next server.
- Preserve one-human-plus-five-AI 3v3 play. All roles continue to use the same movement and contact simulation so control can be reassigned later.
- Tune against captured full sequences—serve setup through landing and point through next serve—rather than judging isolated pose screenshots.
