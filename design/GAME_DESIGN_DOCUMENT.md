# CHAINS DEEZNUTS TOGETHER - Game Design Document

1-6 player online co-op horror-comedy. You are chained to your friends. Climb the Stack. Escape. Scream, then laugh.

> **Status (2026-10-15).** Sections were drafted in parallel from one shared creative bible (Appendix A). The cross-section acceptance audit did not run, so expect small name or number mismatches between sections; when two sections disagree, Appendix A wins, and `CLAUDE.md` wins on engineering. The engine is Godot 4 (see the note at the top of section 9).

## Contents

- [1. Game Overview & Pitch](#1-game-overview--pitch)
- [2. Core Gameplay Loop](#2-core-gameplay-loop)
- [3.1 Level 1 - The Yellow Rooms](#31-level-1---the-yellow-rooms)
- [3.2 Level 2 - The Pizzeria Night Shift](#32-level-2---the-pizzeria-night-shift)
- [3.3 Level 3 - The Infected City](#33-level-3---the-infected-city)
- [3.4 Level 4 - The Seductive Hotel](#34-level-4---the-seductive-hotel)
- [3.5 Level 5 - The Final Ascent](#35-level-5---the-final-ascent)
- [4. Items - "Go Stupid With It"](#4-items---go-stupid-with-it)
- [5. Enemies, Bosses & Combat](#5-enemies-bosses--combat)
- [6. Horror Director, Jump Scares & Audio](#6-horror-director-jump-scares--audio)
- [7. Multiplayer & Chain Physics](#7-multiplayer--chain-physics)
- [8. Progression, Unlockables & Cosmetics](#8-progression-unlockables--cosmetics)
- [9. Engine & Tech Stack](#9-engine--tech-stack)
- [10. Prototype Roadmap](#10-prototype-roadmap)
- [Appendix A - Creative Bible (canon)](#appendix-a---creative-bible-canon)

---

## 1. Game Overview & Pitch

**Pitch.** Five meters of chain between you and the person who will get you killed. CHAINS DEEZNUTS TOGETHER is an online co-op horror-comedy for 1-6 players: new hires at DEEZ Industrial Fasteners, cuffed wrist to wrist with a nut that cannot be undone by the person wearing it, and sent up the Stack, a 420 m tower of dead businesses nobody ever left. The horror is sincere. A blind thing in the drop ceiling hunts by noise and the fluorescents drop a semitone when it listens. A mascot moves only unwatched. Hunters see your flashlight at 60 m. A woman in a hotel doorway calls your name and asks you to come alone. Then one Link flinches, the Line Bites, and the physics does the rest: six adults, one jetpack, a sticky bomb on somebody's hat, a pigeon trying to carry five people, screaming in a major chord. The monsters are never the joke. The chain always is. Loot the absurd, drag your dead upstairs, and clock out through Door 1 together, because nobody escapes alone.

### Fact Sheet

| Field | Value |
|---|---|
| Genre | Online co-op horror-comedy, physics-chained vertical climb |
| Players | 1-6, drop-in/drop-out; solo plays with the Ballast |
| Perspective | First or third person, toggled any time (V, 0.25 s blend) |
| Platforms | PC (Steam) at launch; PlayStation 5 and Xbox Series X/S 6 months after, crossplay on |
| Session length | One level: 25-45 min, saved at every Break Room |
| Full run length | One Shift: 2.5-3.5 hours across 5 levels and 24 Break Rooms |
| Price tier | Premium indie, $19.99 USD; cosmetic unlocks earned in-game only |
| Comparables | For fans of Chained Together, Lethal Company, Content Warning and Phasmophobia |

### Tone Pillars

- **Scream, then laugh.** Every scare lands at full force with Flinch-lock and a 0.4 s camera snap; the laugh is the JERK label floating over whoever bolted first.
- **The Line is the comedian.** Monsters get no quips and no idle gags; the comedy budget is spent on 24-link physics segments, ragdoll thresholds and the Scream Chord.
- **Stupid loot, serious consequences.** The Honker fires one 400-damage round and launches you 6 m with the Line attached; Popflare fire travels the chain at 1 m/s.
- **The company is calm.** The Foreman logs a colleague pulled into the ceiling as "Incident #212" and asks you to file a report when safe.
- **Nobody escapes alone.** Door 1 opens only when every living Link pulls the same way for 5 s; any system that plays the same unchained gets redesigned.

### The Fiction

You are the new hires of DEEZ Industrial Fasteners, "Holding It Together Since 1931," makers of the Deez nut: a Grade 8 hex coupling nut that cannot be undone by the person wearing it. Orientation Day is a mandatory team-building ascent of the Stack, a 420 m tower the company built by buying failed businesses whole and stacking them: an office block, a family pizzeria, a city block, a luxury hotel, and a final floor stitched from all four. Nobody who was inside those businesses ever left, and they are still there. The team wakes in the Sump, a flooded pit at the bottom that kills whatever falls in, wrists cuffed into the company's own chain product, each cuff locked by one Deez stamped CHAINS · DEEZ NUTS · TOGETHER. Escape means reaching Door 1 on the roof and clocking out. The nuts release only when the shift timer reads "Shift Complete." The Foreman will be counting heads the whole way up.

### Key Hooks

- Six strangers, five meters of chain, and one thing in the ceiling that hunts by sound.
- Every jump scare has a second victim: whoever is holding the other end of the Line.
- The jetpack lifts the lightest Link first; the Line brings the other five up at the Bite, and the fuel runs out at the top.
- She calls your name from the doorway and asks you to come alone. The chain is the only reason you can't.
- The Foreman counts heads at every Break Room. It is sometimes wrong by one. It is never wrong by accident.

### Why It Clips

- **The Birthday Song (Pappy Pepperoni's, every Shift).** Power hits 0%, one party-hat spotlight finds the Link with the lowest Wellbeing, the band sings their name at half speed, and on the last word the office door swings open on Pappy's face while five teammates sprint for the freezer and Jerk the birthday Link off their feet.
- **The Scream Chord (any level, any drop over 4 m).** Three or more Links go off the same ledge, their ragdoll screams pitch-scale with fall speed, and the game auto-tunes them into a major chord in the second before the Line goes taut and the two left standing find out whether anyone Braced.
- **The Corpse Commute (any Shift with one death, which is all of them).** The dead Link rides the Line as 80 kg of Deadweight, dragged face-first up every staircase to the next Break Room, narrating from the corpse at 10% volume, and wakes at 50 Wellbeing asking who jerked.

### Target Audience and Session Fantasy

Friend groups of 3-6 aged 18-34 who already play co-op horror on voice chat and watch each other's clips the next morning; streamers whose content is reaction and chaos; solo players who want a hard, quiet climb with a 35 kg iron buddy. The fantasy: you are terrified, you are laughing, and both are the other five people's fault. You will be the one who screamed, the one who jerked, or the one who braced and held, and the scoreboard will remember which.

---

## 2. Core Gameplay Loop

### The 30-Second Loop

Every Link runs six beats on repeat, and the Line turns each beat into a question for the Link on the other end of the segment.

| Beat | What the Link does | What the Line does to it |
|---|---|---|
| Move | Walk (Noise +1/s), sprint (+3/s), crouch, Brace (hold crouch, 0.2 s wind-up, Footing 2, cannot move) | Segment HUD color: green Give under 4.0 m, amber Bite 4.0-5.0 m, red at the 5.0 m stop. Sprinting into the stop at 4 m/s ragdolls you 1 s. |
| Climb | Ladders (Footing 1.5), hand-over-hand cables, ledges (6 s grip meter) | A climber gains 5 m in about 4 s; a neighbor who has not started following is at the stop by then. |
| Manage Give | Read both neighbors' colors; take up or pay out slack; Hoist on call | Give is freedom. Bite is a tool (Chain-lines, shutters, tripping a Vacancy). The stop is a Jerk. |
| Scan | Torch cone, mirrors, ceiling tiles, the pitch of the nearest fluorescent | Every scare flinches the camera 0.4 s toward its source. The Head scans forward, the Tail scans back. |
| Items | Two hand slots, one Pocket; use, throw, drop | Every item has a chain consequence: recoil, fire travel, sticks to the Line. |
| Talk | Proximity voice (+4/s; shouting +12/s) | Callouts are the real controls: "Give," "Biting," "Brace," "Hoist," "Who jerked?" |

The question asked every second: do I have Give to do what I want, or do I have to ask for it?

### The Set-Piece Loop (3-6 Minutes)

Approach, coordinate, execute, threat interrupt, recover or Break Room. The emotional order is fixed: tension, chaos, laughter, reset. Never laughter first.

Worked example: Yellow Rooms, floor B6, five Links in the Conga, a dead elevator shaft, 4 min 30 s.

1. **Approach (60 s).** The Rearrange fires in the hall behind them. The poster beside the shaft reads "HANG IN THERE." The doors open only while someone stands on the pressure mat.
2. **Coordinate (45 s).** Link 3, the pivot, takes the mat. Links 1 and 2 climb the counterweight cable to a service ledge at 8 m and 4 m and Brace (Footing 2 + 2 = 4, enough for eight danglers). Links 4 and 5 wait in the hall. Plan: Link 3 steps off, the doors start a 2 s close, Links 1 and 2 Hoist, Links 4 and 5 run through.
3. **Execute (60 s).** Link 3 jumps for the cable. Link 4 is through. Link 5 sprints, hits the stop at 4 m/s, ragdolls 1 s in the doorway: "JERK: Link 5." The chain drags on carpet (+2/s); Link 5 shouts (+12/s).
4. **Threat interrupt (30 s).** Link 5's Noise crosses 60. The fluorescent above them drops a semitone and dims; tiles bow along the hall ceiling. Staggered and still for 3 s, Link 5 is within 8 m: a tile drops and the Custodian lifts them, Footing 3, over 4 s. Flinch-lock, first person, cuffs tugging the screen edge. Total Footing against it: 4 (Braced) + 1.5 (Link 3 on the cable) + 1 (Link 4) = 6.5. The Line wins. The out-pull yanks Link 5 out of the ceiling and Link 4 three meters into the shaft; Link 3 loses the cable. Three Links swing on 15 m of chain; the Scream Chord resolves to E major; a Traffic Cone hat falls the full 18 m. The lights cut 1.5 s. "Incident #41: colleague partially filed. Retrieved. Please proceed."
5. **Recover (75 s).** Nobody died, nobody has Give. Links 1 and 2 Hoist in turn; the Line climbs. Break Room B5 at 42 m; one Link punches the clock (2 s); Roll Call counts six. Five sit down.

The scream is the grab. The laugh is the pendulum and the hat. The reset is the clock.

### The Level Loop

A level is 4-6 Break Room arcs of 40-60 m, each arc one or two set pieces. The climb body runs 15-25 min; the exit sequence, scavenging and Layoff replays bring it to the Stack table's 25-45 min.

1. **Clock in.** Spawn in the entry Break Room: vending machine, 3 lockers, Roll Call.
2. **Scavenge.** 12 + 4 × Links spawns per level: 50% in the lower third, 30% middle, 20% top. Legendary weight doubles (7 to 14) in the top third.
3. **Climb.** Set pieces built on the level's signature mechanic.
4. **Puzzle.** One multi-Link lock per arc (two-Link doors, pressure mats, pulleys, counterweights).
5. **Threat pressure.** Ramps per Break Room passed: +1 concurrent roaming threat (cap 3); the Hook interval tightens from 6 min toward 3 min; the signature timer shortens (Rearrange 90 s to 60 s on B3-B1, Lantern packs +1 per night). The scripted scare sits in the middle third and always targets the Tail or the lowest Wellbeing.
6. **Exit sequence.** 40-120 s, scripted, always a Hoist test under a timer. It is the hardest coordination check in the level by design.

### The Run Loop

A **Shift** is all five levels; a full one takes 2.5-3.5 h. A session of 75-120 min covers two or three levels; the Shift suspends at the last Break Room and resumes there. Level entry unlocks per level reached; starting higher starts with an empty Lanyard.

1. **Lobby.** The punch-clock wall. 1-6 Links drop in and out freely.
2. **Formation vote.** 15 s, majority among shapes legal for the count, default on tie; the host may force any legal shape.
3. **Clock in.** Every present Link punches, or the host starts a 10 s countdown.
4. **Five levels.** Each exit pays 100 / 150 / 200 / 250 / 300 Washers and seals a Break Room.
5. **Door 1.** Every living Link in Bite in the same direction 5 s. "Shift Complete." Every Deez falls off.
6. **Results.** Washers by source, Incident total, Separations, the Jerk leaderboard, Scream Chords performed, Clean Shift levels.

Between levels: hand items, Pocket items, Washers and the Incident counter carry; Wellbeing resets to 100 at the seal. On a Layoff: hand items drop where you died and persist for the Shift (go get them), Pocket items stay, Washers earned since the Break Room pay out at 50%.

### The Meta Loop

Washers are team-shared and spent at the Lobby's vending wall; every unlock is cosmetic, no stat changes. Earning: 1 per meter of new team height split evenly, 25 per Break Room, 5 per Unscheduled Event survived, 2 per first-time pickup, exits, 300 per boss, ×2 for a Clean Shift level.

**Shift Cards.** Three daily, one weekly, 60-250 Washers each: "Clean Shift on Pappy Pepperoni's," "Reach a Break Room with zero Jerks," "Survive ten Unscheduled Events in one level," "Return a Deadweight to Door 1."

**Overtime mutators.** Lobby toggles; they multiply Washers but never count for Clean Shift records: Short Line (3 m segments, ×1.5), Skeleton Crew (Wellbeing 50, ×1.5), Dark Shift (all lights at 50%, ×1.3), Group Plan (every Juice Box transforms the whole Line, ×1.0), Hats Mandatory (every Link spawns with a physics hat, ×1.0).

### Checkpoints and Group Death

- **Downed:** Wellbeing 0 from anything but the Sump or a grab-kill. Crawl 1 m/s, can speak, 45 s bleed-out, dragged at −30% team speed. Revive: standing Link within 2 m holds interact 4 s, return at 40.
- **Dangling:** an airborne Link is 0.5 load. The holding side arrests only if its Footing beats the load; a Line-arrested fall deals no damage, only the Jerk stagger. In the Sump kill plane, 8 s before something takes them.
- **Dead and Deadweight:** 80 kg, Footing 0, still on the Line; spectate from any living camera; voice from the corpse at 10%, lowpassed. Revive at the next seal (50) or Jumper Cables (25). 50%+ Deadweight is Overloaded, team speed −40%.
- **Layoff, exactly:** the moment no living Link is standing (every Link Dead, or every living Link Downed). Solo: Downed is a Layoff unless holding a First-Aid Kit (auto-revive 5 s, once per Break Room).
- **Kept / lost:** Pocket kept, Washers since the seal at 50%; hand items lost; monsters return to patrol; random scares reroll.
- **Respawn staging:** the team reappears sealed in the last Break Room at full Wellbeing, formation reformed, Lanyard restocked from Pocket only. The door is locked 10 s while the Foreman reads the Incident; the vending machine works during it.
- **Anti-frustration:** Break Rooms every 40-60 m (5 / 4 / 6 / 5 / 4), one every 4-7 min of median climb. Mercy ladder, per Break Room, reset on seal: 2nd consecutive Layoff, Washer loss drops to 25%; 3rd, one free Common item per Link and the Hook is suppressed for the arc; 4th, the main monster's first trigger loosens 50% for the arc (Custodian Listening at Noise 55, Pappy's Step +4 s, Lantern sight 40 m, Darling Turn at 2 m). Scares, damage and lethality never change. Nothing is ever skipped.

### Scaling with Player Count

| Links | Formation | Line length | Monster HP | Loot spawns | Lantern pack (night 1) | Darlings per floor | Pappy Step | Desk leash | Mama Crust fuses |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Ballast, 1 × 4 m | 4 m | base | 16 | 1 | 1 | 14 s | 5 m (Ballast clipped in) | 1 |
| 2 | Buddy System, 1 × 3 m | 3 m | base | 20 | 2 | 1 | 14 s | 5 m | 2 |
| 3 | Conga, 2 × 5 m | 10 m | +15% | 24 | 2 | 2 | 13 s | 10 m | 3 |
| 4 | Huddle, 4 × 5 m | 20 m | +30% | 28 | 3 | 2 | 12 s | 15 m | 3 |
| 5 | Conga, 4 × 5 m | 20 m | +45% | 32 | 3 | 3 | 11 s | 20 m | 3 |
| 6 | Huddle, 6 × 5 m | 30 m | +60% | 36 | 4 | 3 | 10 s | 25 m | 3 |

The solo rule: the Ballast is a 35 kg Link that cannot die, cannot climb and can be thrown 6 m or Anchor-Spiked; it counts for Break Rooms, Door 1, levers and the Security Desk, where it holds the last camera set. Every two-Link lock in the Stack accepts a thrown Ballast as its second Link, and the throw is always the hard part. Scripted scares pick the Tail in a Conga, the lowest Wellbeing in a Huddle.

### Lobby and Drop-In / Drop-Out

- **Joining mid-level.** The joiner spawns in the last Break Room and is coupled by a new 5 m segment to the nearest Link's Deez as a dangling Tail. The segment starts in **Catch-Up**: no stop and no Bite for 30 s or until it first drops under 4 m, whichever comes first, then normal physics. During Catch-Up the joiner is hunted as Loose (2× aggression). The shape reforms at the next seal.
- **Leaving mid-climb.** The leaver becomes Deadweight on the spot (80 kg, Footing 0) until the next seal. A disconnect holds the slot 60 s; reconnecting re-enters the same body at its current Wellbeing.
- **Host migration.** The longest-connected Link becomes host inside 5 s; the Shift continues.
- **Formation re-forms** only at a seal; the host may force a legal shape at any Break Room before the door opens.

### Pace Targets

Median group: four Links, second Shift, mixed skill.

| Level | Duration (clear) | Break Rooms | Scares per 10 min (scripted + procedural) | Item pickups (of 28 spawns) | Expected Layoffs |
|---|---|---|---|---|---|
| 1. The Yellow Rooms | 25-35 min | 5 | 3.0 | 18 | 0.7 |
| 2. Pappy Pepperoni's Night Shift | 30-40 min | 4 | 3.5 | 20 | 1.1 |
| 3. Carrow Heights | 35-45 min | 6 | 4.0 | 22 | 1.5 |
| 4. Hotel Velluto | 35-45 min | 5 | 3.5 | 20 | 1.3 |
| 5. The Exit Interview | 25-30 min | 4 | 5.0 | 12 | 1.8 |

Each Layoff costs about 5 min of replay; the table's 6.4 expected Layoffs put a median Shift at 3 h, inside the 2.5-3.5 h target.

---

## 3.1 Level 1 - The Yellow Rooms

### Overview

The bottom nine floors of the Stack: an underwriting office DEEZ bought whole, staff included. Liminal-office horror: a thing in the plenum you hear through every tile and see, if unlucky, once. 0-70 m: nine floors (B9-B1) at 5.8 m with a 1.6 m plenum over every drop ceiling, then an 18 m freight shaft; 25-35 min; 5 Break Rooms. Palette: sodium-yellow tubes on a 60 Hz hum that dim near the Custodian; damp mustard carpet that swallows footsteps; flicker under 2 Hz, behind the photosensitivity toggle.

Doorways are 0.9 m wide and 6 m apart, so a 5 m segment is always in one: it pins the Rearrange, snags the frame and drags on carpet, which is Noise. This is the tutorial and nothing says so: the building, the posters and the Foreman's Safety Manual readings teach Give, Bite, Jerk, Brace, Hoist, Pinch and Layoff in that order.

### Layout, bottom to top

| Segment | Height | Space and climb | Threat pressure | Loot |
|---|---|---|---|---|
| Intake (B9) | 0-6 m; BR1 at 6 m | Sump ladder; reception; the window | Custodian Dormant | 2 Dependable Torches guaranteed |
| Open Plan (B8-B7) | 6-18 m; BR2 at 18 m | Cubicle farms; shaft 1; the Wrong Cab | First Rearrange; Rollers ×4; Listening | 6-8 in desk drawers |
| The Stairwell That Comes Back (B6-B5) | 18-30 m; BR3 at 30 m | Flooded floor; Ceiling Traverse; looping stair; ball pit | Carpet Mouths ×8; first Stalking; Hook eligible | 4-6 in lockers; the Honker under Dennis |
| Records (B4-B3) | 30-41 m; BR4 at 41 m | Cabinet rows; Vent Crawl; shaft 2; the Photocopier | Rollers ×3; Rustmaw | 6-8 under the copier |
| Management (B2-B1) | 41-52 m; BR5 at 50 m | Glass offices; Breaker Hall; badge doors | Rollers ×6; constant Stalking; Coworker possible | 4-6, Uncommon-heavy |
| Freight Shaft | 52-70 m; hatch to Level 2 | Counterweight cables, no cab | Ankle grab at 15 m | none |

### Chain-coordination climbs

**The Sump Ladder (B9).** A 6 m ladder from a grate over the water. At rung 5 the climber's segment Bites; a climber (Footing 1.5) loses to two standing Links (2), so the next Link starts up before the first tops out. Failure: Jerk, a 4 m drop for 30; boots in the water start the 8 s timer. Scaling: a Huddle climbs two on opposite rails; solo, throw the Ballast up first. Comedy: the Line snags the top rung and the first Link up goes back in feet-first.

**Shaft 1: Mat and Cable (B8-B7).** Doors open only while a Link stands on the mat; cable 6 m. The climber Bites against the mat Link, who Braces (Footing 2) until the climber tops out and Hoists the next; the mat Link goes last. Failure: doors close on a Link, 20 damage, Pinched. Scaling: a 5-Conga pivots its middle Link on the sill; solo, the Ballast holds the mat and is reeled in. Comedy: the mat Link sprints, hits the stop and swings in the shaft.

**The Ceiling Traverse (B6).** Flooded over 8 Carpet Mouths; the dry route is 30 m of T-bar grid with a runner every 5 m. On the 6 s grip meter, neighbors 1.2-4.0 m apart or the Bite pulls a hanger off, and a hanger counts as standing still. Failure: a dropped Link lands in water, 50% on a Mouth; hangers cannot pull, so two drop in and Brace. Scaling: a 6-Huddle goes as two caterpillars; solo, throw the Ballast ahead. Comedy: a hat drops and someone lets go for it.

**The Stairwell That Comes Back (B6-B5).** Two flights per floor. While every Link is on one flight, the landing above is the landing below; a segment in Bite across a landing makes the next landing real. So the team climbs stretched, a flight apart, the Tail alone. Failure: bunching closes the loop; three loops and the Custodian Stalks. Scaling: a Pair climbs in amber throughout; solo, the Ballast waits a landing below. Comedy: the sprinter hits the stop and ragdolls down a flight onto the colleague below.

**The Vent Crawl (B4).** 25 m of 0.7 m duct, two 90° bends, a 3 m vertical rise. Every bend snags slack, so each Link feeds chain forward at 3.5-4.0 m; at the vertical the top Link Braces on the lip and Hoists each Link 3 m. Failure: a snagged bend stops the Line; pulling through is a Jerk, with Rustmaw behind you. Scaling: a Huddle enters as a Line; solo, the Ballast is pushed ahead, louder. Comedy: the first Link drops from the ceiling, the second lands on them, four more follow.

### Puzzles

**Badge In, Badge Out (B1).** Two readers 2.8 m apart, both needing a badge held 5 s at once; the badges hang at opposite ends of a hall that Rearranges, and lifting one locks both offices 60 s. A Conga sends Links 1 and 2; the rest stand in doorways pinning the way back. Custodian: 5 s still inside 8 m is a Grab, so a third Link Braces beside each reader. Solo: the Ballast's name tag is a badge; throw it at reader B.

**The Breaker Hall (B2).** 30 m of dead tubes and a far-end panel that relights the hall and opens the stair (4 s, standing still). In the dark "observed" means a Torch cone; two 20 m cones cover 30 m only from the middle, so a Conga's Tail walks backward with a Torch and a Huddle rotates. Torch battery 90 s; shaking is Noise +6/s and brings Listening in 7 s. The panel Link needs a Braced neighbor. Solo: drag the Ballast ahead, which is Noise.

**The Floor Plan (B4).** After the Photocopier a last sheet prints: B4's layout with shaft 2 marked and a page counter counting down the Rearrange cycle. Route 70 m; one Link reads and calls; every hall on it must stay in a frustum or hold a segment until the team passes it. At 0 the unseen cells reroll; a reprint takes 20 s, Noise 30. Custodian: reading is standing still.

### Main threat

**The Custodian.** 3 m, blind, in the plenum and wall cavities, seen only as a bruise-colored stain where it presses on drywall or a tile. Through walls at 6 m/s in a straight line, matching a sprint (walk 3.5 m/s), and sprinting is Noise: running is a tie you lose. Noise per Link, 0-100: speaking +4/s, shouting +12/s, walking +1/s, sprinting +3/s, chain dragging +2/s per segment, gunshot +40; decay 5/s.

| State | Enter | Behavior |
|---|---|---|
| Dormant | all Links within 40 m under 20 for 15 s | Stain and dust only |
| Listening | any Link over 40 within 40 m; ends 10 s after all under 40 | Their tube dims 40%, drops a semitone |
| Stalking | any Link over 60 | Closes to 15 m; tiles bow, dust falls along its path |
| Grab | Stalking; a Link within 8 m still 3 s | Lifts the Link through a tile over 4 s against Footing 3; two standing plus one Braced (4) out-pull it, ties lose; at 4 s the Link is Dead above the tiles, cut to black |
| Retreat | Torch on the stain 2 s / 150 explosive damage | 20 s / 10 s, Noise 100 for the thrower |

It only lifts, so the Line is the only counter; if the floor side loses, the next Link leaves their feet, and Pinched Links cannot Brace. A Pair's free Link maxes at Braced 2 and loses: keep moving inside 8 m, or carry a Torch or an Anchor Spike (Footing 99). Solo: Spike the Ballast before any still task.

Counters: Torch; Squeaky Dennis (it searches above the squeak 20 s); Grease Can (no chain drag); Anchor Spike; explosives on the stain; never the Snubby. Deaths: stillness while it Stalks, gunfire, sprinting with the Line dragging, Pinched inside 8 m.

Reveal budget: stain, tiles and dust unlimited, never within 3 m of a camera outside a Grab; the Arm only during a Grab; the Face once per Shift, 0.6 s, Flinch-locked, at the first of three slots: a Grab execution, the Mat Reveal, the ankle grab.

### Roaming and secondary threats

- **Rollers.** B8 ×4, B4 ×3, Breaker Hall ×6, parked facing away. 8 m/s when unobserved; impact ragdolls 2 s and Jerks the Line.
- **Carpet Mouths.** Eight under B6's water, three on B4 and B2, one in BR3's doorway after it reopens; Footing 4 until the Line pulls at 5 or the patch takes 50.
- **Cross-level.** The Hook after BR2, every 3-6 min (two Braced neighbors stop it at 2 m); the Coworker 25% per Shift from BR3, where "check the nut" is learned; one Rustmaw in the B4 duct, teaching Loose and re-forging.

### Scripted jump scares

- **The Intake Window.** First Link within 3 m of the reception window: the stain presses over the team's reflection from the far side 0.8 s. One-time. Aftermath: everyone steps back at once, the Shift's first JERK label.
- **Tile Drop.** The Tail first stands still 3 s on B8, Noise ignored: the Arm lifts the Tail at half rate (8 s) against Footing 3; Flinch-lock; released at 8 s regardless. One-time. Aftermath: the Foreman reads Manual 7.3: "maintain tension."
- **The Wrong Cab.** A Link within 2 m of B7's call button: doors open on an empty shaft; a lit cab falls past at 20 m/s, shoving the nearest Link 1 m toward the sill. One-time. Aftermath: the doors close on the segment, the first Pinch.
- **The Buffer.** A Link at the stop in a hall over 30 m for 5 s: the distant buffer closes over 4 s, is 1 m behind them for 0.5 s, tubes cut 1 s; nothing is there. Once per floor, 180 s cooldown, Tail first. No aftermath.
- **The Photocopier.** The Line enters the B4 copy room: it prints alone, photos of the team from behind, taken now; the last is the Custodian's face over the Tail's shoulder; lights cut 1.5 s; the Line Bites hard once. One-time. Aftermath: the Floor Plan prints 20 s later.
- **The Mat Reveal.** Shaft 2's mat first stepped on: the stain bulges from the back wall 0.5 m away; if the Face is unspent it surfaces 0.6 s; it slides up the shaft at 6 m/s. One-time. Aftermath: the mat Link steps off; Pinched again.

### Procedural scare pool

Director: 1 credit per 45 s, cap 3; global cooldown 30 s; per-scare cooldown 240 s, 3 per Shift; none within 20 s of a scripted scare, during a Grab, or in a sealed Break Room. Target: the Tail in a Conga, the lowest-Wellbeing Link in a Huddle. Unseen scares refund; Layoff rerolls the seed.

| Scare | Cost | Trigger | Payoff |
|---|---|---|---|
| Tube Pop | 1 | target under a tube 2 s | 1 s dark; glass underfoot is Noise 10 |
| Desk Phone | 1 | target within 3 m of a desk | Rings; answered, breathing and Noise +20; ignored 10 s, every phone on the floor rings |
| Chair Stack | 2 | 3+ Rollers on the floor, Tail facing away 5 s | Stacked 3 high, 2 m behind the Tail, when they turn |
| The Knock | 1 | target within 1 m of drywall | Three knocks at head height from inside the wall, 0.5 s apart |
| Lights Walk | 2 | Line stretched over 12 m | Tubes die one per 0.5 s from Tail to head, then return |
| Wet Prints | 1 | dry carpet in frustum | Footprints darken toward the target, stopping 1 m away |

### Level-specific mechanics

**The Rearrange.** Each floor is a 10 × 10 grid of 6 m cells. Fixed: the Break Room, shafts, stair and set piece; the rest draw from six room types (hall, cubicles, meeting room, bathroom, storage, dead end). Timer 90 s from a Break Room door opening; at 0, every cell outside all player frustums (90°, both cameras), over 6 m from any Link and holding no segment rerolls; a Break Room seal rerolls the whole floor once. Constraints: a walkable path from every Link to the exit under 120 m; 1-3 doors per cell; no straight hall over 36 m. A segment through a doorway seam pins the cell: a Pair pins one, a Huddle two, the Conga three. A segment crossing a seam as it rotates is Pinched: both Links held until both pull away at the stop for 3 s. Dead shafts (B8, B4): doors open only while a Link stands on the mat, close 1.5 s after it clears, and a doorway segment holds them at 0.3 m; the cable is a ladder (Footing 1.5), so the 5 m segment decides who climbs and who holds.

### Loot

12 + 4 × Links spawns from the pool of 40, biased to quiet and chain tools over guns, so the first gunshot is a decision.

| Item | Weight | Where |
|---|---|---|
| Dependable Torch | 14 | Reception desk (2 guaranteed), lockers |
| Squeaky Dennis | 12 | Cubicle drawers |
| Rolling Chair | 10 | Every cubicle |
| First-Aid Kit (expired) | 10 | Kitchenettes, bathrooms |
| Grease Can | 8 | Janitor closets |
| SHIFT! Energy | 8 | Mini-fridges |
| Anchor Spike | 7 | The records cage |
| Party Popper | 5 | Party-supply closet, B5 |
| Snubby | 5 | One locked executive drawer, B1 |
| Mirror Shard | 3 | Bathroom mirrors; breaking one is Noise 30 |
| The Honker | 1 | Under Dennis, in the ball pit |
| Mystery Juice Box | 1 | Vending machines only |

### Checkpoints and exit

Five Break Rooms: Intake (6 m), kitchenette (18 m), Wellness (30 m), records cage (41 m), mail room (50 m), each directly after the floor's hardest climb. Roll Call at every door; at Wellness it counts one too many.

Exit: the freight shaft, cab missing. The Line climbs the counterweight cables 18 m at 1 m/s, Tail last, nobody over 4 m apart or the Bite peels them off. At 15 m the Custodian takes the Tail's ankle; the two Links above Hoist within 4 s or the Tail is Dead, cut to black, and 80 kg of Deadweight rides the cable the last 3 m. Solo, throw the Ballast onto the counterweight ledge at 14 m and Spike it. At 18 m a hatch opens into dry storage that smells of flour. 100 Washers, ×2 on a Clean Shift. The Foreman: "Floor one. Please mind the step."

### Comedy beats

- **Who jerked, first edition.** Five people step back from the Intake Window at once; the physics picks one and labels them JERK for 10 s. Never the one who screamed.
- **The Chair Train.** Six Rolling Chairs, a Grease Can and 4 m of Give per segment: a train through the Open Plan at 5 m/s. The first Link to stand makes a Roller; it hits the Tail.
- **The Doorway Argument.** Two Links Pinched in a seam, pulling the wrong way for 20 s, under a poster reading TEAMWORK.
- **Dennis in the Ball Pit.** The Honker is under him; firing it there launches the shooter 6 m into the ceiling grid, in the Custodian's lane.

### Audio notes

Ambience: the hum (60 Hz per tube); the hush (carpet absorbs footsteps to 3 m, voices through drywall lowpassed at 800 Hz); the buffer (never resolves). Chain: hiss on carpet, ring on tile, rattle in the duct; Give is silent.

Custodian cues, in order: the semitone drop, dust ticking along a line of tiles, a tile creaking at 1 Hz above the target, then the Grab's one sound, a wet drag, no scream. Rollers squeak only when they move.

Music: the hum alone when Dormant; a 30 Hz subharmonic under Listening; the creak track under Stalking; one sting on Grab, then nothing.

Voice: positional, 15 m, double range through the plenum. Push-to-talk is honored; a silent team still trips every threshold by sprinting with chain drag. When a hall rerolls, a teammate's voice arrives from where the hall is now. Dead Links speak from their Deadweight at 10%, lowpassed.

---

## 3.2 Level 2 - The Pizzeria Night Shift

### Overview

**Pappy Pepperoni's Night Shift**: a family pizzeria bought whole and stacked on the Yellow Rooms. 70-130 m, four floors (Dining Hall, Kitchen, Stage, Party Rooms) plus a ventilation crawl and the stage rigging; 30-40 min. Style, generically: a survival night-guard setup, with that genre's cameras, doors and draining power bank and a clock counting the hours to morning. Light: red exit signs, CRT handset glow, house lights left off. Sound: servo whine, the jukebox's party loop at half speed, a counter bell that rings itself.

The Line breaks the genre's one rule: the guard cannot sit still. One Link runs cameras while the rest climb on 5 m per segment, and shutters are held shut by two Links in Bite, not a button.

#### The Night Shift clock

Badge clock from 12:00 AM, 6 min real time per hour; pauses in a sealed Break Room, rewinds on a Layoff. Pappy is Dormant until the first camera check or 12:30. 1 AM: Tiny Tomato wakes. 2 AM: Big Dough wakes. 3 AM: second Tomato. 4 AM: the Hook every 3 min. 5 AM: Big Dough climbs between floors. 6 AM: the jukebox never stops again; Pappy loses his second tell. At 0% power: house lights die, cameras blank, the lift locks, Pappy free-roams at 2 m/s watched or not, Tomatoes double, until the next Break Room restarts the generator.

### Layout, bottom to top

```
130 m  ROOF         inflatable chef -> Carrow Heights
120 m  RIGGING      Mama Crust, fuse catwalks, exit catwalk
114 m  VENTILATION  twin ducts
104 m  PARTY ROOMS  mezzanine ring, Office, ball pit
 95 m  STAGE        band, lift shaft, wings
 83 m  KITCHEN      line, dish pit, freezer
 70 m  DINING HALL  booths, counter, loading dock
```

| Segment | Space and climb | Pressure | Loot / checkpoint |
|---|---|---|---|
| Dining Hall, 70-83 m | Booths tipped into a 7 m stair to the dumbwaiter | Nodes 4-5; Desk 1 | Torch, Big Red Button; BR 2.1 Receiving (70 m) |
| Kitchen, 83-95 m | Line, dish pit, walk-in freezer, Manager's Office; the rack to the hood deck | Nodes 6-7; Big Dough; first Tomato; Desk 2 | Grease Can, the Ladle; BR 2.2 Dry Storage (91 m) |
| Stage, 95-104 m | Band, Sound Booth, wings; lift or counterweight ladder | Home node 1; wings have no camera; Desk 3 | Popflare, Air Horn |
| Party Rooms, 104-114 m | Rooms Pepperoni and Big Slice, Office, ball pit; winch to the vent hatch | Nodes 8-10; the Birthday Song; Desk 4 | Party Poppers, Slack Jack; BR 2.3 Coat Check (106 m) |
| Ventilation, 114-120 m | Twin 0.8 m ducts, 40 m, junctions every 8 m | Tomato home; duct sag | Gum Bomb; BR 2.4 Prop Loft (120 m) |
| Rigging and roof, 120-130 m | Fly loft, her body the ladder; then the inflatable chef | Boss, then the fall | Doorknocker, the Cinch; exit |

### Chain-coordination climbs

**1. The Dumbwaiter (77-83 m).** A 1 m² car on a hand rope, one rider hauled 5 m at 1.5 s/m. The Line up the shaft holds the hatch open, so the Desk 1 Jockey, 14 m away, must unclip before the second ride. Failure: dropped rope, 30 damage, a Jerk. Scale: solo throws the Ballast onto the shelf; six is five rides, the last four blind. Comedy: Deadweight does not fit and goes up face-first.

**2. The Dish Pit Rack (85-95 m).** 10 m of pan-stacked shelving tips under 80 kg unless a far-side Link keeps a segment threaded through it in Bite as a stay. Order: climber to 4 m; stay into Bite; next climber mounts; the stay climbs once a deck Link is Braced. Failure: 8 m, 70 damage, 300 pans at Noise 100. Scale: solo wedges the Ballast in a tier; six go in two waves with two stays. Comedy: the Ladle spawns here; its arc clears the rack of teammates first.

**3. The Stage Lift (95-104 m).** A 2 × 2 m platform rises 9 m at 0.5 m/s from Desk 3 at −1%/s, rated 3 masses; a fourth stalls it with a klaxon he hears. Three ride; the rest climb the counterweight ladder at lift pace to stay under 5 m; the Jockey comes last, Hoisted. Failure: a ladder slip stalls it over his home floor. Scale: solo runs it from the handset cord; six is two waves, 36% of the bank. Comedy: a Link jumping onto the moving lift Jerks three ladder-climbers off into a chord.

**4. The Ball Pit (108 m).** 7 m across, 1.2 m deep, Footing 0.3, wade 1 m/s. One Link on each lip at full Bite; the middle Links are Hoisted through in turns while Tiny Tomato hunts under the balls and strikes anyone stationary 2 s. Failure: no lip anchors, everyone at Footing 0.3, blinded one by one. Scale: solo throws the Ballast to the far lip; a Huddle crosses as a ring, both halves in Bite. Comedy: a ragdoll surfaces wearing the birthday crown.

**5. The Twin Ducts (114-120 m).** Two 0.8 m ducts, crawl 1.2 m/s. A section sags under 2 masses and drops under 3: 4 m into the party rooms, 30 damage and a Jerk. Coordination: 3 m spacing called by voice; a Huddle sends half the ring up each duct and both halves must reach junctions together or the ring pins. Scale: solo pushes the Ballast ahead; a Pair takes one duct. Comedy: Big Lad from a Juice Box in a duct.

### Puzzles

**1. Breaker Order (Kitchen).** Four breakers on the dish pit panel must match a pattern readable only on Cam 6; the Jockey at Desk 2, 12 m away, calls, a climber flips. Each wrong flip lights a dining-hall zone 5 s (Pappy sees it within 25 m) and surges 5% off the bank. Done between Steps while Cam 1 holds him on Stage, it costs nothing.

**2. Sound Check (Stage).** Three lift-brake keys 4.5 m apart along the back wall, turned within 2 s; count = min(Links, 3). The tone is Noise 100 and a door slam, so he comes home to Stage, 6 m away: turn in the first Step after the Jockey has him on a far cam. Links 1-3 at full Bite along the wall; the rest Brace. Solo: two keys are pedals for the Ballast.

**3. Mislabeled Monitors (Party Rooms).** Desk 4's camera labels are swapped. Climbers wave in front of each of the four party cams (12-20 m out) while the Jockey relabels; until then "keep him on camera" is a guess and he walks. Three Links reach 10 m, so far cams need the Jockey unclipped; a Slack Jack (+3 m) is the designed shortcut.

### Main threat

**Pappy Pepperoni.** 2.6 m mustachioed chef animatronic, pepperoni eyes, human teeth. No Wellbeing bar; guns do nothing.

- **Movement:** only while no Link looks at him and no camera shows him, one node per Step along 11 nodes: Stage (home), two Wings, Dining Hall, Counter, Kitchen, Dish Pit, two Party Rooms, Office, and the Climb Hall shutter on the Line's floor. Step = 14 s minus 1 s per Link beyond two, minimum 8 s: 14 / 14 / 13 / 12 / 11 / 10 s for 1-6 Links. Wings and Climb Hall have no camera. At 0% he walks 2 m/s with no observation rule.
- **Senses:** light within 25 m, including the handset glow; door slams within 30 m, including the lift klaxon and the rack collapse; gunpowder: a gunshot on his floor skips his next timer. Voice is not a sense; push-to-talk never kills anyone here.
- **Tell:** servo whine rising, then the jukebox stops; he reaches the shutter within one Step.
- **Shutter:** closed, three bangs over 3 s (Noise 100), back to Stage. Open, he lunges 6 m in 1.0 s and grab-kills the nearest Link within 6 m (2 s, cut to black, Deadweight). The Jockey leash decides who is nearest; he never pulls the Line, his Deadweight on a rack does.
- **Counters:** lights off; keep him on camera; shutters in Bite; the walk-in freezer (unpathable; holds six); Dependable Torch freezes him 1.5 s (8 s cooldown); Air Horn stuns 2 s; Party Popper pushes him back a node.
- **What kills you:** a Snubby fired on his floor; unclipping with the handset lit; a shutter's Bite lapsing with a Link in the hall; sprinting past an open shutter after the jukebox stops.

### Roaming and secondary threats

- **Tiny Tomato.** Toddler-sized vent crawler, visibly a machine (tomato head on four servo legs), 60 HP, 7 m/s in ducts and across ceilings; drops onto a face for 15 damage and 3 s of blind. Hood vents from 1 AM, party ceilings from 3 AM, Ventilation always; targets the Jockey 50% of the time.
- **Big Dough.** Dough-mass strongman, 1.5 m/s, immune to guns, breaks any door in 6 s (never a sealed Break Room), stunned 5 s by a Party Popper. Dish Pit from 2 AM, between floors from 5 AM. A shutter he breaks releases the Bite holding it.
- **Cross-level:** the Hook everywhere but the rigging; Rustmaw on the rack and in the ducts; the Coworker joins at the Coat Check.

### Scripted jump scares

Targets: the Tail in a Conga, the lowest-Wellbeing Link in a Huddle. Once per Shift, rerolled on Layoff, 60 s shared cooldown.

| Scare | Trigger | Setup → payoff | Aftermath |
|---|---|---|---|
| The Counter Bell | Jockey first clips into Desk 1 | Three rings; on the third, Cam 5 shows Pappy 2 m behind the desk. Flinch: nothing there | Dormant ends |
| The Curtain | The Line crosses the stage | The curtain opens alone; the band lights up at half speed; Pappy's mark is empty | The jukebox stops: he is already out |
| The Order Window | Target within 2 m of the pass window | The shutter rolls up alone: Tiny Tomato 0.5 m from the face, drops | The blinded Link walks toward the shaft |
| The Costume Rack | Target passes the spare suits in the wings | A spare Pappy suit turns its head to follow; Flinch-lock 1.2 s | They back into the fly rail; Jerk |
| The Birthday Song | The Line enters Party Room Big Slice | Power to 0; one spotlight; the band sings the slowed birthday song by name to the lowest-Wellbeing Link; on the last word the Office door opens on Pappy's face; Flinch-lock | Blackout at 2 m/s; BR 2.3 is 20 m back |
| The Office Grille | Target crosses the duct grille above the Office | Pappy stands below looking up; the grille gives in 0.5 s | A 4 m drop into his node unless the neighbor Braces |

### Procedural scare pool

Director: 3 per in-world hour, 45 s apart, none within 20 s of a scripted scare, a shutter bang or the boss. Targets: Tail 40%, Jockey 35%, random 25%, never the same Link twice running.

| Scare | Trigger | Effect |
|---|---|---|
| Static Face | Jockey on one cam 20 s | 1 s static, then Pappy 0.3 m from the lens; the real one has not moved |
| Jukebox Skip | Any time | Stops 2 s and resumes; the real stop never resumes |
| Balloon | Tail idle 3 s in a party room | Pops behind them; the flinch Jerks the Line |
| Dough Print | A shutter held 10 s | A dough handprint spreads across its inside |
| Pepperoni Eyes | A flashlight down a hall over 20 m | Two red glints that blink out when lit; 25% they are him |
| Vent Patter | Any Link under a duct | Running feet overhead, dust falls; 20% a Tomato drops |

### Level-specific mechanics

**The Desk Jockey.** Four Security Desks: Host Stand, Manager's Office, Sound Booth, Party Coordinator.

- **Clip-in:** 1 s; the cuff hooks the desk; Footing 2. The hook holds four danglers; five drag the Jockey out, and the handset cord unplugs at 3 m (cameras reboot 10 s).
- **Handset:** a 5 kg CRT on a coiled cord, 9 cams (nodes 1, 4-10, the lift shaft); fills the screen in first person; its glow is light, hooded at the desk, visible 25 m anywhere else.
- **Power bank:** 100% per Break Room. Cameras −0.3%/s while live; lights −0.1%/s per lit zone; stage lift −1%/s moving; shutters, freezer and Break Room doors 0%/s. Cameras alone last 5.5 min.
- **Shutters** (one per landing) cost chain, not power: the Line's middle hooked on the pulley (1 s), two Links walked apart into Bite (2.4-3.0 m on a Buddy System segment); opens the instant Bite lapses.
- **Reach:** 5 m × (Links − 1) in a Conga, 5 m × floor(Links ÷ 2) in a Huddle, 3 m in a Pair, 4 m solo with the Ballast on the hook: 4 / 3 / 10 / 15 (Huddle 10) / 20 / 25 (Huddle 15) m.
- **The relay:** unclip, and cameras and lights hold their last state, every shutter opens, and the Line Hoists the Jockey up whatever the climbers just climbed: one Step for Pappy per 10-14 s.

### Loot

Spawns: 12 + 4 × Links (16 solo, 36 at six) from the pool of 40; weights multiply base rarity; guns are rare on purpose.

| Item | Weight | Where |
|---|---|---|
| The Ladle | ×3.0 | Kitchen line only |
| Party Popper, Grease Can, Big Red Button | ×2.0 | Party rooms (three in the pinata); kitchen floor; desk drawers |
| Dependable Torch, Air Horn, SHIFT! Energy, Rolling Chair, Slack Jack, Anchor Spike, Jumper Cables | ×1.5 | Desks, party rooms, kitchen fridge, Office, Coat Check, catwalks, Prop Loft |
| Squeaky Dennis, First-Aid Kit (expired) | ×1.0 | Ball pit, Dry Storage |
| Snubby, Doorknocker, Popflare | ×0.5 | Manager's safe, Prop Loft, wings |
| Mirror Shard | ×0.3 | Coat Check |

### Checkpoints and exit

Four Break Rooms, each a generator restart, so the bank is sized to one floor plus its relay: **2.1 Receiving** (70 m; the host may switch to a Huddle here), **2.2 Dry Storage** (91 m, after the rack), **2.3 Coat Check** (106 m, after the lift, before the Song), **2.4 Prop Loft** (120 m, before the boss).

**Boss: Mama Crust (122-128 m).** 4.5 m, bolted into the rigging above the stage shaft; the exit catwalk is above her and her body is the only ladder. Three catwalks ring her at 125 m, a fuse box on each, 4.5 m apart. Arms sweep every 7 s (4 m knockback, a fall, a Jerk on a Line stretched to reach the boxes); eye lamps blind first person 1 s. Pulls: min(Links, 3) boxes within 2 s; each costs a phase and opens a 3 s damage window; 600 HP, +15% per Link above two; boxes re-latch 20 s. Phase three: lights zero, she tracks by Noise, chain on grating is +2/s, so Brace between pulls. Solo: the Ballast thrown onto the lever box from 6 m. At 0 HP she locks, arms raised: 6 m up her body to the exit catwalk, 300 Washers.

**Exit: the inflatable chef.** The roof's 20 m chef deflates over 40 s from the first grab of its arm. The Line climbs bulge to bulge (2-3 m leaps); the fabric holds only segments under Bite: a Taut segment pulls the bulge flat and drops the Tail into a 3 m fold, Hoisted out by two Links. The raised hand hooks the first Carrow Heights fire escape at 142 m.

### Comedy beats

1. **The Water-Ski.** Five climbers come off the rack; the Jockey rips out of the Manager's Office and crosses the kitchen on their stomach, cord unplugging at 3 m. "Cam 6 offline. Jerk: Link 3."
2. **The Shutter Hug.** Two Links hold a shutter in Bite while Pappy bangs; Big Dough breaks it in 6 s, the Bite releases, and both holders meet in the middle at 4 m/s.
3. **The Ladle.** A 3 m ladle and a Grease Can: one swing, three teammates in the arc, a six-body slide into the dish pit at Noise 100.
4. **Pigeon on the Chef.** A Juice Box Pigeon tries to carry the Tail off the deflating arm, sinks at 1 m/s, panicking audibly, and lands everyone in the armpit.

### Audio notes

- **Ambience:** the jukebox's loop at half speed through every floor; the handset's 15.7 kHz whistle, Jockey only; the freezer compressor; the counter bell. Exit signs flicker at 1 Hz (photosensitivity toggle).
- **Pappy:** servo whine 200 → 800 Hz across the Step before a shutter arrival; the jukebox stop is a hard cut; three bangs at Noise 100; at 0% his footsteps are the only positional sound.
- **Music states:** Quiet (jukebox); Hunt (stopped: room tone and whine); Blackout (compressor, bell, breathing); Boss (her motor under the band at quarter speed, silence in phase three); Exit (the blower dying).
- **Proximity voice:** the handset pipes each camera's microphone to the Jockey with 0.5 s delay and CRT compression, so teammates are heard through the nearest cam and his servo whine through whichever cam he is on. Ducts carry voice 3× as far; the freezer muffles it to 2 m.

---

## 3.3 Level 3 - The Infected City

### Overview

Carrow Heights is a city block DEEZ bought whole and stacked at 130-220 m: twelve rooftops (tenements, a car park, billboards, a water tower, a leaning tower, a wedged overpass, a burnt-out atrium, a transmitter deck) still settling against each other. Rooftop parkour over an infected city, slow infected by day and lethal hunters by night, under a sky that is a clock. 35-45 min, six Break Rooms. Orange sodium dusk to pitch black with UV islands; wind rising with height; howls that triangulate; one dog barking that stops. The Line makes every gap arithmetic: a 5 m segment against a 6-9 m gap means someone is always airborne, a 6 m Safe Ring never holds a Conga, and a Lantern only needs the Link at the end.

### Layout, bottom to top

| Seg | Roofs (m) | Route | Pressure | Break Room |
|---|---|---|---|---|
| A. Low Roofs | R1 Tenements 130, R2 Laundry 134, R3 Parkade 145 | Count Jumps over three 3 m alleys; the parkade ramp | Shamblers 2 + Links per roof; Bloats in trunks | BR1 130, BR2 145 |
| B. Billboard Row | R4 149, R5 155 | Climb R4's frame; Chain-line 8 m from its catwalk | First sundown; UV ring on R4 | BR3 155 |
| C. Cistern Block | R6 159, R7 Water Tower 168 | Generator crank; the only ladder runs through R7's tank | Night two; the Water Tower | BR4 168 |
| D. The Tilt | R8 168-178 | Leaning tower, 25 degree roof, 30 m side drops, open lift shaft; Pendulum off the parapet | Settling lurches; sliding Shamblers | none |
| E. The Overpass | R9 176 | Wedged highway deck missing 9 m; Rope-Bridge, then zipline | Shamblers in wrecks; a Bloat in the bus | BR5 176 |
| F. The Hollow | R10 174-190, interior | Burnt-out atrium, stairs gone, 0.8 m beams, the Roost on floor 12 | Clock frozen indoors | none |
| G. Transmitter Deck | R11 190, R12 194, mast to 220 | Cable trays, three shutters, the mast, the crane | The Pack Run | BR6 190 |

Loot placement is in the Loot table. Dennis is zip-tied to the mast at 218 m; Lanterns swerve around him.

### Chain-coordination climbs

**Count Jumps (R1-R2).** Three 3 m alleys, 7 m deep (30 damage, then dangling over Shamblers). One Link airborne per segment: each jumps 0.7 s after the one ahead lands and takes exactly one step; a second step puts the segment at 5.0 m mid-jump and Jerks the jumper into the alley. Failure: the faller dangles, the catcher staggers 1.5 s, Shamblers grab the hanging Line. Solo: throw the Ballast 3 m, jump. Pair: the rear Link jumps from the lip. Huddle: two mirrored files, a jump every 0.35 s. Comedy: Link 4 jumps on "three"; the Scream Chord plays in D.

**The Billboard Chain-line (R4-R5).** 8 m gap, R5 6 m higher, from a catwalk 8 m up (a fall is 17 m: Downed). The anchor Braces; Links 2 and 3 step off as a 10 m pendulum (1.0 load; Braced holds 4); Link 3 pumps three swings (+1.5 m each), releases on the third upswing (0.4 s window) onto R5 and Braces. Between two Braced anchors every segment sits at 4.5-5.0 m and the middle Links slide across hanging from their cuffs at 2 m/s; an anchor stepping forward sags the Line and the slider hits brick for 20. The catwalk anchor goes last, Hoisted under R5's lip. Solo and Pair cannot span 8 m: a fire escape down and up (70 s, 6 Shamblers). Comedy: the slider's hat rolls along the Line ahead of them.

**The Catch (R8).** On the Tilt's 25 degree slope Footing halves: standing 0.5, Braced 1, Anchor Spike 99. Every 100-140 s the tower settles: 1.2 s tremor, anyone not Braced slides 3 m, vent stacks snag the Line. Side edges drop 30 m. A sliding Link falls 5 m in 1.0 s; the next Link up has 0.8 s to Brace (0.2 s wind-up) before the stop. Standing holds one faller, Braced two; a caught fall is the stagger, no damage. Solo: the Ballast is Spiked every 10 m. Six: two files with a Spike between. Comedy: five Links catch the sixth, then the vent stack they all hold comes off.

**The Pendulum (R8-R9).** Tilt parapet (178) to Overpass end (176): 6 m across, 2 m down. The anchor Spikes or Braces; the swinger dangles 4.5 m below, pumps, and releases at 60 degrees on the upswing (0.4 s window). Early is wall (20); late is a 4 m/s Jerk on the anchor. The lander Braces and the rest slide across. 1-2 Links: the Ballast or partner anchors, and both make it or neither does. At night a Lantern on the deck meets the swinger at the apex: flare the deck first. Comedy: the swinger shouts NOW on swing two; the anchor un-Braces to look; six voices, one chord.

**The Rope-Bridge (R9).** The deck is missing 9 m; a sagging guard cable spans it. The first crosser hand-over-hands it: 9 m at 1.5 m/s is the whole 6 s grip meter, and a Jerk from behind is a 22 m fall. Then the Line is the bridge: anchors Brace 2 m back from each lip (13 m over three segments, all in Bite) and two sliders hang 4.3 m apart so neither anchor is pulled. Deadweight cannot slide: the far anchor walks back 4 m to drag it, costing the near anchor their Brace for 2 s. Failure: a Jerk on either anchor drops both sliders 5 m under the deck. Solo and Pair take the zipline. Comedy: a Rustmaw chewing the middle segment while two people hang from it arguing about who stomps it.

### Puzzles

**The Ticket Gate (R3).** A button 10 m down-ramp opens the roof gate after 8 s for 10 s. Ten metres is two segments at full Bite: one Link on the button, one at the gate, one as slack. Shamblers (6 + Links) grab the Line within 1 m; three on a segment stops the team. Solution: button Link holds, gate Link Braces, the rest flick Shamblers off with a Jerk (sprint opposite ways). Pair: a Rolling Chair wedged on the button. Solo: the Ballast.

**The Lamp and the Crank (R6).** Crank handles sit 0.5 m outside the 6 m ring on opposite sides; two Links crank 10 s for 60 s of light; the hum drops a semitone at 10 s left. Night is 90 s: crank at the 20 s warning, re-crank 50 s in with the pack circling at 7 m. Crankers are bait: inside Links Brace and face out, because a grabbed cranker is dragged at 6 m/s and only two Bracing Links stop it. Solo rigs run 30 s.

**The Clock Window (R10).** The sky clock freezes indoors: enter the Hollow at night and it stays night until a Link is under open sky. Floor 11's window is the only sky. A Link ledge-hangs outside it (6 s grip) and the clock runs while they hang: fifteen hangs per night, each swap a two-Link Hoist, while Lanterns climb the wall at 4 m/s toward the hanger (first at 12 s; a torch under 5 m drops it). Solution: rotate hangers in Line order, torch in the free hand, or enter in the last 15 s of a day and climb in frozen daylight.

### Main threat

**The Lanterns.** 2.2 m, dim orange eyes, 250 HP (+15% per Link above 2: 400 at six). Sprint 8 m/s against a Link's 7; leap 6 m; wall climb 4 m/s. Sight 60 m under light (a torch shows at 60 m, a flare at 120 m), 10 m in the dark; hearing 30 m, woken by Noise over 20, hunting over 60; a gunshot reaches every Lantern within 100 m. States: Roost (day, inside upper floors; emerge 20 s after sundown; flee at dawn at 8 m/s, dropping whatever they hold) > Prowl (4 m/s along roof edges) > Scream (3 s; every Lantern within 100 m converges in 15 s) > Hunt (8 m/s, leaps) > Pounce (Downs an unbraced Link; a Braced Link takes 30 and holds) > Drag (runs for the edge at 6 m/s pulling the Line; only two Bracing Links stop it; otherwise the Link dangles at the 5.0 m stop and is grab-killed in 4 s unless Hoisted). Chain: a leap across a Taut segment is stopped 1.5 s; it always takes the Tail or a Loose Link; it never enters UV but circles it at 7 m. Counters: Popflare blinds 4 s and repels; Torch under 5 m blinds 2 s; Doorknocker 3 shells; Snubby 13 rounds the pack hears; Party Popper 150; Air Horn 2 s stun. Pack: 1 + floor(Links / 2) on night one, +1 each night after (six Links: 4, 5, 6). Hiding: no light, walk, Brace, stand still beyond 10 m, HVAC units, Safe Rings. What kills you: a torch at night, one Link sprinting ahead onto open roof, a flare in hand, an unbraced edge.

### Roaming and secondary threats

- **Shamblers** (1.2 m/s, 150 HP): 2 + Links per open roof on R1-R3, R6, R8 (sliding downslope at 2 m/s), R9; each grabs the Line within 1 m at Footing 1, three on a segment stops the team; frozen at night.
- **Bloats**: parkade trunks, the R8 shaft, the R9 bus, 1 per 4 Shamblers; burst at 2 m for 50 in 4 m and a ragdoll that ragdolls the Line, which on a slope is a slide.
- **The Coworker**, from R4: a seventh silhouette 5.0 m behind the Tail against the dusk. Check the nut.
- **Rustmaw**: 25% of Chain-lines and Rope-Bridges after night one; orange flakes fall into the gap.
- **The Hook**: every 3-6 min on open roofs; a lifted Link with a torch on is a beacon at 60 m.

### Scripted jump scares

All one-time per Shift except the Trunk; nothing strobes above 1 Hz and every flicker honours the photosensitivity toggle.

| Scare | Trigger | Setup and payoff | Aftermath |
|---|---|---|---|
| The Dog (R2) | Tail crosses the second laundry line | A dog has barked from the alley since arrival. It stops mid-bark; 2 s; the laundry line the Line is draped over is yanked from below, a 2 m Jerk toward the parapet; nothing there | The Tail's hat lands among three Shamblers |
| The Trunk (R3) | A Link or Taut segment touches a car | Alarm (Noise 100 m, 20 s, hazards at 1 Hz); 2 s later the trunk pops and a Bloat unfolds at 2 m. Five cars; per car, 60 s cooldown, 40% after the first | The Line snagged on a wing mirror tows the alarm with the team |
| The Billboard (R4) | First Link Braces on the catwalk | A smiling family under two sodium floods. Day: floods die 1.5 s, return with every face turned to the Line. Last 40 s of day, or night: two eyes open 2 m above the anchor, a real 3 s Scream, it leaps away | The anchor un-Braced; the slider is in the wall |
| The Water Tower (R7) | First Link clears the tank hatch | The only ladder up runs through the tank. A Lantern erupts 1 m away, roars 1.5 s, drops back in; Flinch-lock; it leads the next night's pack | The hatch Link ragdolls down the ladder onto the next (halved damage, 20 to them) |
| The Lift (R8) | Tail steps over the open shaft | The lift car drops past 1 m away, 1.2 s roar, 4 m of wind; the Tail falls in, arrested by the Line | Everyone upslope slides 3 m; the Tail dangles asking what that was |
| The Roost (R10, floor 12) | Tail reaches the walkway's far door | Twenty Lanterns hang from the trusses, eyes shut; "Quiet please. Colleagues resting." One opens its eyes, drops inverted to 0.3 m from the Tail's face, breathes, climbs back. Noise over 40 wakes all twenty and the clock snaps to night | Three Links ragdoll off the walkway, caught by the Line, in C major |

### Procedural scare pool

Director: one scare per 75 s per team, 45 s cooldown after any scare including scripted, none within 2 s of a release window (Pendulum, zipline clip, Count Jump). Target: the Tail in a Conga, the lowest-Wellbeing Link in a Huddle, a Loose Link at 2x weight. Each entry rolls once per Break Room stretch; rerolled on Layoff.

| Scare | Trigger | Rule |
|---|---|---|
| Eyes in the Window | Target looks across a 20-40 m gap for 2 s | Two orange points, one blink, gone; no pack call |
| Triangulation | Night, team stationary 10 s | Three howls from three bearings; the third from beneath the target's feet |
| Pigeons | Target grabs a ledge | Thirty pigeons erupt from under the lip; hats go with them |
| The Silhouette | Dusk, next roof in view | A Lantern-shaped figure on the far edge; 90% a chimney on arrival |
| Wet Hand | Target stands on a drain grate 3 s | A Shambler hand holds the ankle at Footing 2 for 3 s; a moving Line makes it a Jerk |
| Line Tug | Night, Tail's segment on the floor | The trailing segment is pulled 2 m at 5 m/s from the dark; 20% it is a Lantern |

### Level-specific mechanics

**Sundown.** Day 150 s, night 90 s. The sky clock runs only while a living Link is under open sky: it freezes in sealed Break Rooms and interiors (parkade ramp, the Hollow), saves at Break Rooms, restores on Layoff with the night count. Night starts whether or not you are on a safe roof. At 20 s to sundown the sky drops to amber: "Site lighting maintenance in twenty seconds. Remain within marked areas." Night: Lanterns emerge, Shamblers freeze, the wind stops. Dawn: Lanterns flee, sodium returns over 5 s. The Pack Run is the third night; every extra sundown before BR6 adds one Lantern to it.

**Safe Rings.** UV masts on R4, R6, R9 and R11 light a 6 m ring; the generator runs 60 s per 10 s two-Link crank, handles 0.5 m outside the light. Lanterns circle at 7 m and see the lamp at 60 m, so a lit ring draws the pack. A Pair fits; a Conga always leaves two Links in the dark, and the inside Links Brace to hold a grabbed outsider at the 5.0 m stop while shooting from the light.

**Chain parkour rules.** Jump in sequence: one Link airborne per segment, 0.7 s apart. Swing: anchor Braced or Spiked, +1.5 m per pump, release on the third upswing. Bridge: Braced anchors on both lips, sliders at 2 m/s, 0.5 load each. Zipline: 6 m/s, 2 masses, 0.75 s clip rhythm; a third mass snaps it. Catch: Brace within 0.8 s of a neighbour leaving an edge; standing holds two danglers, Braced four, halved on the Tilt. Any 2 m parapet carrying two standing masses crumbles after 3 s. "HANG IN THERE" hangs over every drop.

### Loot

12 + 4 x Links spawns from the pool of 40; base weights Common 45 / Uncommon 30 / Rare 18 / Legendary 7, times:

| Item | Weight | Where |
|---|---|---|
| Popflare | 30 x 2.0, plus two guaranteed | Pump house, transmitter hut |
| Dependable Torch | 45 x 1.5 | Every roof; a trap at night |
| Harpoon Reel | 30 x 1.5 | Billboard catwalks |
| Anchor Spike | 30 x 1.5 | Gap edges, the Tilt |
| Slack Jack / Bungee Nut | 30 x 1.2 / 18 x 1.2 | The Tilt, the Overpass |
| Party Popper / Gum Bomb | 45 x 1.0 / 30 x 1.0 | Parkade, the bus |
| Rolling Chair | 45 x 1.2 | Parkade only |
| Grease Can | 45 x 0.4 | Never within 6 m of an edge |
| Mystery Juice Box | 7 x 1.0 | The Roost, floor 12 |

### Checkpoints and exit

Six Break Rooms: BR1 stair head (130), BR2 attendant booth (145), BR3 plant room (155), BR4 pump house (168), BR5 toll booth (176), BR6 transmitter hut (190), each after a crossing and before a Safe Ring, because the clock freezes inside: a sealed room is the only way to choose which phase you step out into. Roll Call at BR5 is wrong by one.

**The Pack Run.** Opening BR6 forces sundown in 20 s; the pack (full night count, the Water Tower Lantern leading) spawns 30 m behind and the mast's PA broadcasts its Scream. 120 s route: 60 m of 0.8 m cable trays (single file, chain dragging), three shutters the Tail pulls in 2 s (each costs the pack 2 s), a 3 m Count Jump at speed, a 4 m ladder to the Mast Roof, the hook. Every Jerk costs 1.5 s; a clean last Link beats the pack by 8 s. Solo throws the Ballast onto the hook's lever.

**The Crane.** One Link rides the hook; the rest hang below in a 5 m column (25 m for six). The hook rises 40 m at 3 m/s; the lowest Link leaves the roof 8 s after the rider, and Lanterns climb the mast at 4 m/s to leap 6 m at them. One that connects hangs on (20 damage/s) and slows the winch to 1.5 m/s; a torch under 5 m, a flare, or a Party Popper dropped down the Line clears it. Dawn breaks as the column swings through the Velluto's second-floor window at 234 m, glass first, Line second. "Carrow Heights exit logged. Incident count carried forward."

### Comedy beats

- **NOW.** The Pendulum swinger calls it on swing two; the anchor un-Braces to look; six voices, one chord, one parapet.
- **The Umbrella.** A Corporate Umbrella at the Billboard gap carries exactly one Link; the second rips it inside out, and the Conga arrives on the street in order.
- **The Crank.** Two Links crank in the dark with the pack circling at 7 m while four stand in the light offering advice. The crankers get the JERK labels.
- **The Column.** On the crane every scream pitch-scales with its swing; the chord passes Dennis at 218 m. He is fine.

### Audio notes

Ambience: three wind beds by height (130, 160, 190 m), sodium ballast buzz on lit roofs, Shambler moans and flapping sheets by day; howls are positional, so players triangulate too. Lantern cues: a wet click 0.5 s before the Scream, a rising tone that lowpasses through walls; claws at 8 m/s on concrete; the wall-climb scrape under the window. Music: day a sodium drone; sundown the Foreman's line over a descending bass; night no music, only a sub-bass pulse whose tempo tracks the nearest Lantern's distance (capped at 3 Hz); the Pack Run is the only full cue, 120 s of drums tuned to the Scream Chord. Proximity voice carries 30 m outdoors with wind attenuation, exactly a Lantern's hearing: if a teammate can hear you, so can the thing on the next roof. Push-to-talk is honoured and every Noise state is reachable by movement alone. Corpse voice at 10% plays from wherever the Deadweight dangles, which on the crane is below everyone.

---

## 3.4 Level 4 - The Seductive Hotel

### Overview

**Hotel Velluto**, 220-330 m: fourteen 7 m floors (floor 1 at 220 m, floor 14 at 318 m) plus a ballroom dome and pool terrace to 330 m. Generic style: the grand haunted hotel, where the helpful strangers are the monster. Theme: **temptation versus trust**. Target 35-45 min. Light: 4000 K sconces every 6 m with 3 m of dark between; the one nearest a Darling is 3200 K. Sound: a lounge piano through the walls drifting 20 cents flat per minute until a Break Room resets it; voices with no reverb. The Line is the limit of temptation: a bunched team cannot be Turned on (Isolation Rule), slack rings on marble (Carpet Hush), lifts split the team by mass, Bellhop carts hook Taut segments. Darlings per floor: ceil(Links ÷ 2).

### Layout, bottom to top

| Segment | Floors / m | Space and route | Pressure | Loot | Break Room |
|---|---|---|---|---|---|
| **Atrium** | 1-3 / 220-241 | Marble lobby, reception, Velluto Bar, grand stair missing its top flight; crane window on 2 → Hush Route → Balustrade Walk | 2 Bellhop routes; 1 Darling at the bar; the Hook over the 21 m void | 6, Common-heavy | BR1 Concierge Office, 227 m |
| **Service Core** | 3-6 / 241-262 | Kitchens, laundry; Lift A 3→5; Laundry Chute 5→7 | Room Service every 15 m; Rustmaw in the chute; a Darling per lift landing | 8, plus 4 trunks | BR2 Linen Room, 248 m |
| **Guest Floors** | 7-9 / 262-283 | Door corridors; guest elevator 7→8; Mirror Mirror; Suite 909 | Darlings in doorways; 1 Bellhop on the floor-9 landing | 10, Uncommon bias | BR3 Housekeeping, 269 m |
| **Balconies** | 10-12 / 283-304 | Interior stair burned out; exterior balconies 300 m up; Balcony Pendulum | Darlings on rails; the Coworker; the Hook | 6, mobility bias | BR4 Suite 1104, 290 m |
| **Penthouse** | 13-14 / 304-318 | Lift B 12→13; Two Ears foyer; Dumbwaiter 13→14 | Darlings at every alcove; 1 Bellhop on foyer marble | 6, Rare bias | BR5 Penthouse Pantry, 311 m |
| **Dome and Pool** | 318-330 | Ballroom, 12 pillars, 3-ton chandelier, cupola; pool; drain; scaffold | Madame Velluto | none | none |

### Chain-coordination climbs

**1. The Balustrade Walk (floor 3).** Service door 30 m along a 0.3 m balustrade, 21 m over lobby marble; the Line snags every post on purpose. One Link crosses while the two behind Brace (Footing 2 beats a dangler's 0.5), lifting the trailing segment over each post; a Bellhop passes below every 40 s and hooks any Taut segment, so drop to Give as it passes. Failure: a slip with nobody Braced is 21 m, Dead. Scaling: solo throws the Ballast post to post; a 3-Conga leaves the Tail alone on the rail. Comedy: three Braced Links hold the slipper when the Hook takes the fourth.

**2. Cage and Car (Lift A 3→5, Lift B 12→13).** Rules under Level-specific mechanics. The cage party boards first; 1.25 s after release the Line goes hard and they dangle under the car for 6 s. At the top the car party Braces and Hoists before the landing's Darling finishes her sentence: she Reaches at the lowest dangler. Failure: car Links not Braced at docking go through the hatch onto the cage party (14 m, 70 damage). Scaling: six is 2 up, 4 down; three is 1 and 2; a Pair adds two trunks; solo loads the Ballast and two trunks. Comedy: four colleagues hanging in a column in the dark, auto-tuned to a major chord.

**3. The Laundry Chute (5→7, 14 m).** A 1 m steel chute (Footing 1.5), one Link per 2 m; every 8 s a 20 kg linen bundle hits the top Link (1.5 s stagger, a Jerk if the segment below is Taut). Keep Give under 3 m so the Link below catches each stagger; the top Link Braces at the floor-7 hatch. Failure: a dropped Link lands on everyone below (20 each) and the stack hits the laundry floor as a pile. Scaling: a Huddle climbs folded, two per row; solo hauls the Ballast behind and it takes every bundle. Comedy: a hat comes off and leaves by the laundry door with a Bellhop following it.

**4. The Balcony Pendulum (floors 10-12, exterior).** Balconies stagger up the facade 4 m up and 6 m across. The anchor Braces at the rail; the swinger steps off (Footing 0); the anchor pumps by walking 3 m along the rail; on the third swing the swinger releases at the apex (0.6 s window). Failure: a missed apex is arrested if the anchor is still Braced, or is 300 m if the Hook has the anchor. Scaling: one standing anchor holds two danglers, three pull them over the rail; solo throws the Ballast across and swings from it; a 6-Huddle crosses as three Pairs, the Trunk Link Jerked every swing. Comedy: the Corporate Umbrella works for 1.6 s, until the segment goes Taut and rips it inside out.

**5. The Dumbwaiter (13→14, 7 m).** A 0.8 m box on a rope; one Link fits, crouched, holding nothing. Hauled from 13 by two Links (4 s) or from 14 by one Link walking away from the hatch into Bite (7 s): the first rider from below, every later one from above. The shaft segment rings on foyer marble: the Bellhop arrives at 60 s. Failure: a dropped rope drops the box 7 m (30 damage, wedged 10 s). Scaling: solo sends the Ballast first and climbs the rope. Comedy: Big Lad does not fit.

### Puzzles

**1. Hush Route (lobby).** 30 m of marble; the red runners leave three 4 m gaps. Solution: the Links either side of a gap hold Bite, lifting the segment off the marble, while the crosser keeps feet on carpet; or two Links roll a runner (6 s) and re-lay it. Pressure: two Bellhop routes loop at 40 s; a cart snags any Taut segment and drags it toward the atrium drop at 2 m/s, so hold Bite only while the cart is on the far side. Solo: carry the Ballast; it is silent.

**2. Mirror, Mirror (floor 9).** A 40 m corridor lit only at its ends, eight doorways, ceil(Links ÷ 2) Darlings, a convex security mirror at the far end. Tells: the mirror shows each 1.5 m out of her doorway, 0.5 s late, shadow flickering at 3 Hz toward the nearest Link; teammates' voices gain 200 ms reverb within 10 m of her. Solution: one Link lights the mirror with the Torch (indirect light does not Turn her) and calls positions; the Line walks the far wall, 3.5 m from any doorway, every Link inside 4 m of a neighbor so the Isolation Rule never applies. Pressure: 90 s of Torch battery; each Darling steps 0.5 m per 2 s unobserved, and six steps put the far wall inside 3 m.

**3. Two Ears (penthouse foyer).** 30 m, pitch dark; four doors 4 m apart; three women call from three; the fourth is the Pantry stair, announced by the Foreman's PA for 2 s every 15 s. Tells: Darling voices are non-positional, 40 ms stutter every 6 s, no reverb; the PA is positional with reverb. Solution: two Links at least 5 m apart each report the PA's bearing; the bearings cross at the door. Pressure: at 20 m the three enter Draw; the bell-pull takes two Links for 3 s while the neighbors at 4 m Reach and say both names; a puller who steps sideways enters the 2.0 m Leash, so the other must Brace, not pull.

### Main threat

**The Darlings**, ceil(Links ÷ 2) per floor at doorways, rails and bar stools. Full rules in The Succubi; level specifics:

- **Senses.** Sight 40 m, tracking the nearest Link by name tag; footsteps ignored. Noise 40 or more within 30 m sends every Darling on the floor to Draw.
- **States and speed.** Hail, Draw, Reach, Turn per The Succubi; she never moves while watched, and in Reach the nearest Link's Bite threshold drops to the 2.0 m Leash. Vacancy: 7 m/s, 5 m lunge, drags at 6 m/s toward the nearest edge, and this level is edges. Retreat after 20 s, rebuilt 60 m higher.
- **The Line.** Isolation Rule: she Turns only on a Link 4 m or more from every other Link; two arriving together get a smile and a step back. One Bracing teammate stops a Reach at the Leash; a Bracing team holds her drag at the 5.0 m stop, a lone standing Link does not (grab Footing 3 beats standing 1). A knee-height Taut segment trips her 4 s.
- **Items.** Torch: 1 s stagger (8 s cooldown), or a deliberate Turn from 20 m with the team Braced. Popflare: flees 10 s. Mirror Shard: true form at 40 m, 2 s stun. Squeaky Dennis: holds Draw 20 s at 15 m. Salt Cellar (level-local Common, 3 throws): 2× damage 5 s.
- **What kills you.** The last 8 m alone; the Torch on her face at 5 m; shooting a Darling (120 HP) before the floor's others are located; answering.

### Roaming and secondary threats

- **Bellhops.** Marble zones only (lobby, floor-9 landing, penthouse foyer), 1 + floor(Links ÷ 3) routes per zone on 40 s loops; 3 s of marble ring calls one within 20 m; impact ragdolls 3 s; the cart snags Taut segments and drags them toward the atrium drop at 2 m/s.
- **Room Service.** Every 15 m in the Service Core and at every Break Room door: 30% a Rare, 70% the hand (40 Wellbeing, 3 s under).
- **The Coworker**, floors 10-12, 5.0 m behind the Tail. **Rustmaw**, the laundry chute, once per Shift. **The Hook**, atrium and balconies, every 3-6 min. **Dennis** sits at the bar beside the floor's Darling; she is not talking to him.

### Scripted jump scares

Targets: the Tail in a Conga, the lowest-Wellbeing Link in a Huddle.

| # | Name | Trigger | Setup → payoff | Repeat / cooldown | Aftermath |
|---|---|---|---|---|---|
| 1 | The Piano | Line crosses the mezzanine lounge | A grand piano plays itself, stops; a hand on the Tail's shoulder: the floor's Darling, already in Reach, says "You're early." The Tail is inside 4 m of a neighbor, so she backs away smiling | Once | The Tail's Jerk pulls three Links into the piano |
| 2 | The Lift Mirror | Guest elevator 7→8, doors close | Lights cut 1 s; the mirror shows a Vacancy folded over the nearest Link; lights return, mirror empty, the car drops 2 m and catches (Jerk, everyone) | Once | Six people ragdolling in a 2 m box |
| 3 | Counterweight Passing | Danglers under any lift car | The empty cage passes at 0.5 m with a Bellhop standing in it, face level | Every ride, no cooldown | Scream Chord in a shaft |
| 4 | The Turndown | Tail passes Room 812 | The door slams and a hand under it takes the Tail's ankle (Footing 3, 2 s) | Once | Two Links Hoisting a colleague out from under a door |
| 5 | Suite 909 | Any Link enters | A Darling on the bed brushing her hair, facing away. She never turns. The wardrobe mirror shows her already standing behind the Tail | Once | The Tail's camera flinches toward a door nobody closed |
| 6 | The Pool | Last Link enters the water | The reflection shows twelve Darlings at the pool's edge; look up, nobody; pool lights off | Once | Everyone wades for the drain and the Line pulls two under |

### Procedural scare pool

Director: one scare per 75 s per floor on average; 45 s minimum after any scare; never the same Link twice running; weight ×2 on a Link 4 m from everyone; off in Break Rooms, shafts and the ballroom; rerolled on Layoff; lights under 3 Hz, behind the photosensitivity toggle.

| Scare | Trigger | Effect |
|---|---|---|
| Do Not Disturb | Link passes a closed guest door | Door opens 20 cm; a hand hangs the sign on the Link's cuff until the next Break Room |
| The Knock | Link's hand on a wall | Three knocks from inside at hand height; 3 s later, three from the Link's other side |
| Housekeeping | Line in a corridor over 20 m | A trolley crosses the far end pushed by nobody; 50% a Darling steps out behind it and counts toward the floor |
| Wrong Mouth | Two or more Links | A teammate's voice, 2 s old, says the target's name from directly behind |
| The Blink | Link alone in a dark gap | Sconces go out one by one toward the Link at 1 Hz and relight behind them |
| Stopped Clock | Link looks at any clock | 3:11. It ticks once |

### Level-specific mechanics

**Counterweight Lifts.** Lift A (3→5, 14 m) and Lift B (12→13, 7 m): a car and a counterweight cage on one cable. The brake releases only when cage mass exceeds car mass by 80 kg or more (Link 80, Deadweight 80, trunk 40, Ballast 35); the motor then runs the car to the next landing at 2 m/s. The Line goes hard 1.25 s after release (relative speed 4 m/s: a Jerk); the cage party lifts off the cage floor (Footing 0) and hangs under the car's floor hatch for the ride. At the top the car party Hoists them: one standing Link holds two danglers, a Braced Link four. Hence 2 up and 4 down for six, 1 and 2 for three, 2 and 3 for five, 1 up and 3 down Braced for four; a Pair adds two trunks; solo loads the Ballast and two trunks.

**Carpet Hush.** Red carpet: the Line is silent. Marble: each dragging segment rings at Noise +6/s; 3 s of ringing calls the nearest Bellhop route within 20 m. A segment in Bite is off the floor and silent; a Link can carry 2 m of adjacent slack in one hand (a hand slot, no sprint). The trade: Hush rewards Bite, and Bellhop carts snag only Bite.

### Loot

Spawns: 12 + 4 × Links from the pool of 40. Weight multipliers:

| Item | Weight | Where |
|---|---|---|
| Mirror Shard | ×3 | Guest floors, penthouse |
| Dependable Torch, Squeaky Dennis | ×2 | Atrium, Break Room lockers |
| Popflare, Corporate Umbrella, Harpoon Reel, Anchor Spike | ×2 | Balconies |
| Salt Cellar (level-local Common), Rolling Chair | ×2 | Kitchens, bar, lobby |
| Slack Jack, The Cinch, Jumper Cables | ×1.5 | Service Core, penthouse |
| Air Horn | ×0.25 | Bar storeroom |
| Room Service trolley | 1 per 15 m | Service Core, Break Room doors |

### Checkpoints and exit

Five Break Rooms, each one floor above a set piece: BR1 Concierge Office (227 m, after Hush Route), BR2 Linen Room (248 m, after Cage and Car), BR3 Housekeeping (269 m, after the guest elevator), BR4 Suite 1104 (290 m, mid-balconies, balcony door bricked), BR5 Penthouse Pantry (311 m, before the ballroom). Roll Call at BR3 counts one too few.

**Boss: Madame Velluto** (600 HP, +15% per Link above 2). Rooftop ballroom 40 m across, twelve pillars on a 15 m ring, a mirror behind each, the 3-ton chandelier 12 m up on a 10 m chain to the cupola. Doors lock; no Hook.

- **Phase 1, the Receiving Line.** Twelve hostesses, one per mirror, waltzing in place; the real one's reflection moves 0.5 s late and her shadow flickers toward the nearest Link. Shooting her: stun 6 s, during which she takes the nearest Link's hand and waltzes at 4 m/s around the pillars, the Line snagging each one; on the third pillar she is tangled, cannot let go, and takes damage for 8 s. The waltzed Link's segment sits at the 5.0 m stop; after 3 s there the Deez tears and that Link is Dead. Untangle (reverse-walk each wrap, 2 s per pillar, or Slack Jack, or the Cinch) and she lets go. Under 50% ends the phase.
- **Phase 2, Last Dance.** She drops the hostess: 4 m, the Vacancy geometry, the face folding last; lights fall to twelve candelabra. Her sweep every 8 s (25 damage, 4 m knockback, a fall if you are on the chain) dislodges the chandelier, which drops 6 m and swings (150 damage on hit). The climb is the chandelier chain into the cupola; she takes the lowest Link's ankle (Footing 3) and a two-Link Hoist from above frees them. The hatch opens only while one Link above and one below hold the chain in Bite for 3 s; solo, the Ballast goes through the bell-rope first.
- **Exit.** The cupola stair reaches the pool terrace at 326 m. Every Link in the water adds 20 kg to the Line. The 1.2 m drain opens when ceil(Links ÷ 2) Links stand on the grate; the pool drains in 8 s and takes the Line down in formation order, Tail last, onto the Stack's exposed scaffold 4 m below, then a scaffold ladder to the Level 5 Nut Station at 330 m. Level exit 250 Washers, boss 300.

### Comedy beats

1. **Who rides down.** Every lift is a vote; the losers hang in a column in the dark, screaming in a major chord, while the car party argues about who Braces.
2. **The bridal train.** Six Links tiptoe across marble carrying their own chain like a hem, silent, until a hat falls off and rings like a dinner bell. Hats are physics.
3. **The waltz.** Madame takes one Link's hand and the other five become a maypole, reverse-walking wraps while a colleague is spun at 4 m/s, until the Deez tears.
4. **Umbrella at 300 m.** The swinger floats down at 3 m/s, serene, for 1.6 s. Then the segment goes Taut.

### Audio notes

- **Ambience.** One lounge standard at 72 bpm through the walls, drifting 20 cents flat per minute, reset at each Break Room. Nothing in a corridor has reverb except your teammates.
- **Darling cues.** Hail: a normal, worried voice, non-positional, 40 ms stutter every 6 s. Reach: the piano stops on one held note. Turn: a tape reel rewinding for 0.8 s, then nothing. Vacancy: no footsteps, fabric drag and a dry joint-click at 7 m/s.
- **Bellhops.** Wheels squeal on marble; on carpet, only the brass bell every 4 s.
- **Music states.** Lobby (piano, in tune), Draw (drift), Reach (held note), Vacancy (string cluster, tape hiss, 20 s), Ballroom phase 1 (16-bar waltz loop; the real Madame is 0.5 s behind the beat), phase 2 (one violin, half speed), Pool (nothing, then the drain).
- **Proximity voice.** Teammates gain 200 ms of reverb within 10 m of a Darling: a friend who suddenly sounds like a cathedral is standing next to her. Darlings read name tags, not microphones; push-to-talk changes nothing. Wrong Mouth and the Coworker both replay a teammate 2 s late: anyone who repeats you is behind you.

---

## 3.5 Level 5 - The Final Ascent

### Overview

**The Exit Interview**, 330-420 m: the top of the Stack, built from offcuts of the four businesses below when DEEZ ran out of things to buy. Generic style: the finale mashup, every horror style in the building stitched together at hard seams and ending in a boss chase. Six **slices** of 15 m, each a corrupted remix of one zone with the zone below bleeding into it, each ending at a **Nut Station** that re-forges the Line into a new shape. 25-30 min; 4 Break Rooms. Light: every palette at once with no transition (sodium tubes end at a tile line and red exit signs start; a hotel sconce lights a gravel parapet). Sound: every monster's cue overlapping, and the Foreman no longer in the ceiling but 2 m away. The Line changes this space because the space keeps changing the Line: formation is forced every 15 m, the only thing that cuts chain operates the stations, the tempo rises slice by slice (60 s Rearrange, 8 s Steps, a 60 s night), and the exit door opens only to the whole team pulling one way.

### Layout, bottom to top

```
420 m  ROOF          Door 1; dawn; the field
405 m  SLICE SIX     The Chairman's Shaft: the Spiral (Conga)        BR 5.4 Boardroom, 405 m
390 m  SLICE FIVE    The Audit Stair (Huddle)                        BR 5.3 Interview Room, 390 m
375 m  SLICE FOUR    Hospitality: the Folded Corridor (Conga)
360 m  SLICE THREE   Fire Drill: one roof, one night (Buddy System)  BR 5.2 Walk-in, 360 m
345 m  SLICE TWO     Back of House: kitchen under tiles (Huddle)     BR 5.1 Onboarding, 345 m
330 m  SLICE ONE     Orientation: Yellow Rooms with a pass window (Conga)
```

| Slice | Origin | Space and route | Pressure | Loot |
|---|---|---|---|---|
| One, Orientation (330-345) | Yellow Rooms | Three 5 m floors of 6 m cells; the Rearrange every 60 s; every roll puts one doorway onto the pizzeria pass window or a hotel stair; exit by the Shaft That Rearranges | Custodian at Bleed; Rollers ×6 at 12 m/s; the Hook from 335 m | Torch, Squeaky Dennis, Spare Nut; Dennis stands in the pass window |
| Two, Back of House (345-360) | Pappy's | Kitchen line and dish rack under office drop tiles; one Security Desk at the pass; one shutter; the Hood Lift; the hood duct onto the roof | Pappy at Bleed on 5 nodes; Tiny Tomato ×2 at 10.5 m/s | Ladle, Party Popper, Anchor Spike |
| Three, Fire Drill (360-375) | Carrow Heights | One rooftop split by a 5.5 m gap, hotel carpet on gravel, a walk-in freezer standing in the open, a UV ring round the far Nut Station | Day 100 s / night 60 s; one Lantern pack; Bloats 1 + floor(Links ÷ 2) at 1.2 m/s | Popflare ×2 guaranteed, Harpoon Reel; no Break Room |
| Four, Hospitality (375-390) | Hotel Velluto | A 40 m corridor folded into a switchback stair: carpet flights, 4 m marble landings, a doorway per landing, a 15 m open well | Darlings ceil(Links ÷ 2); Bellhops at 10.5 m/s on marble; the Coworker | Mirror Shard, Salt Cellar, Spare Nut |
| Five, The Audit (390-405) | New | A 10 m square well, the stair hugging its walls, 4.5 m rise per 28 m lap; no roamers | The Auditor hunting; the Hook | Snubby ×2, Doorknocker, Gum Bomb |
| Six, The Chairman's Shaft (405-420) | New | The Spiral: 350 m of 1.2 m catwalk, 3.5 laps, 15 m rise; Door 1 at the top | The Chairman; no Hook | None; the Honker guaranteed in BR 5.4 |

### Chain-coordination climbs

**1. The Shaft That Rearranges (slice one, Conga).** A dead shaft, cable 15 m at 1 m/s (Footing 1.5), a pressure mat at each door; doors open only while a Link stands on the mat and close 1.5 s after. The Rearrange rerolls every 60 s, and the top door's cell is unpinned until someone stands up there. Order: Link 1 climbs (15 s) and stands on the top mat; the bottom mat Link holds; the rest climb 4 m apart between two pinned doors; the bottom Link goes last, Hoisted by two Braced on the top mat. The hall behind the bottom mat is a Roller lane at 12 m/s, so the Tail faces it. Failure: the top cell rerolls to a wall with a climber 1 m under it; they hang Pinched until the next roll, 60 s, with the Custodian Listening. Scaling: solo throws the Ballast from the 9 m mark onto the top mat; a Pair puts one Link on each mat and the second climber's segment holds the bottom door at 0.3 m; six climb two at a time. Comedy: the roll puts the party room on top; the first Link out wears the birthday crown, and the stain is already in that ceiling.

**2. The Hood Lift (slice two, Huddle).** Desk at the pass; bank 100% (cameras −0.3%/s, lift −1%/s moving); a 2 × 2 m lift rated 3 masses rises 4.5 m at 0.5 m/s to the hood deck; one shutter on the lift hall, held by the Line's middle hooked to the pulley and two Links walked into Bite. Huddle reach is 5 m × floor(Links ÷ 2); the desk is 10 m from the lift. Order: the shutter pair hooks; three ride (9 s, 9%); the deck three Brace; the Jockey unclips and sprints 3 s to the pulley; the pair releases (the shutter opens) and all three are Hoisted 4.5 m in 5 s. Pappy's Step is 8 s at Bleed and the shutter is two nodes from his home, so the opening buys him 16 s: 8 s spare. Failure: a late Hoist, he enters the hall, nearest Link within 6 m, grab-kill. Scaling: solo hooks the Ballast on the pulley and rides; a Pair skips the shutter and rides together with the lights off; six takes two rides, the second without cameras. Comedy: a fourth Link jumps on the moving lift; the klaxon; three ring-mates on the floor rise 4.5 m into a chord; he hears all of it.

**3. The Buddy Zip (slice three, Buddy System).** A 5.5 m gap, the far roof 2 m lower (5.9 m point to point), a zipline rated 2 masses, the slice floor 15 m down. A Pair's 3 m segment cannot span the gap, so Pairs ride together, clipping 0.75 s apart, while the 6 m Trunk to the next Pair spans it only if that Pair stands on the lip: a step back leaves the riders dangling 1 m short. The landed Pair Braces to catch the next Pair's landing Jerk; the last Pair rides with nobody behind them. Failure: a third mass on the cable snaps it (a Downed Link dragged aboard counts); a Jerk on the Trunk mid-ride swings the riders into the far wall for 20. Scaling: solo clips with the Ballast (2 masses); three or five send the odd Link second, alone on the Trunk; four is two rides. Comedy: the odd Link at five rides alone, the Trunk hits 6 m with them 1 m short, and four colleagues on two roofs argue about who walks forward.

**4. The Folded Corridor (slice four, Conga).** Five carpet flights and five 4 m marble landings, a doorway on each, Darlings in ceil(Links ÷ 2) of them, a 15 m well in the middle. Carpet Hush: a dragging segment on marble rings at Noise +6/s and 3 s calls a Bellhop at 10.5 m/s within 20 m. The Conga crosses each landing with its segments in Bite (lifted, silent), except the Tail, who would then be 4 m from everyone and a Darling's by the Isolation Rule: the Tail carries 2 m of slack in one hand (no sprint) and stays inside 4 m of the Link ahead. Order: head to carpet, each Link lifting the segment behind them as they step onto marble, Tail last with the hand-carry. Failure: 3 s of ring; the cart snags any Taut segment and drags the Line toward the well at 2 m/s; impact ragdolls 3 s. Scaling: solo carries the Ballast, silent; a Pair's 3 m segment is in Bite at 2.4 m, so nobody is isolated and nothing rings, the only shape this corridor is kind to; six is a 25 m train with three segments on marble at once. Comedy: the bridal train, six people tiptoeing with their own chain as a hem, until a hat rings like a bell and a cart arrives wearing everyone's hats.

**5. The Audit Stair (slice five, Huddle).** A 10 m square well, the stair on its walls, 4.5 m of rise per 28 m lap; the Auditor on the stair below at 3 m/s, never stopping. A ring in Bite is six Links 4.5 m apart along the stair with the closing segment hanging 4.6 m vertically across the void: every segment over the drop, nobody inside 4 m of anybody. The climb is a wheel: everyone walks at 2 m/s in order, calling steps; the Line snags each corner post on purpose, which holds chain length around corners rather than losing it. The Hook (every 3-6 min) is the designed disaster: a lifted Link's two segments go Taut, their neighbors' far segments drop into Give, and the Auditor cuts the slacker one 1.2 s after reaching it. Failure: a stopped Link (stagger, revive, a hat) makes 1 m of slack; the cut Link is Loose with 60 s. Scaling: three and five climb as a Conga 4.5 m apart; four is a 4.5 m square across the well; a Pair holds 2.0-3.0 m; solo drags the Ballast 3 m behind. Comedy: the ring climbs perfectly and the Auditor walks up through the middle of it, stepping over segments, reading, and waits at the top station.

**6. The Spiral (slice six, Conga).** 350 m of catwalk, 1.2 m wide, 3.5 laps, 15 m up; chase numbers under Checkpoints and exit. Coordination: single file at a called 3.5 m/s, sprints only on the head's call (a sprinter who hits the stop ragdolls 1 s against the rail); the **Gap** on lap 2 (3 m) is a Count Jump at speed, one Link airborne per segment, 0.7 s apart; the **Dead Lines** on lap 3 (previous teams' chains hung across the walkway at 1.2 m) are crouched under in sequence or snag a Taut segment 1.5 s; two **switchbacks** stack the head 3 m above the Tail with the Line hanging over the rail, where the Chairman's thrown chains cuff on. Failure: every lost second is 3.5 m of gap. Scaling: solo has 4 m of Ballast on a 1.2 m walkway (carry it at 2 m/s or drag it ringing); a Pair runs clean; six is 25 m of Line across two switchbacks at once. Comedy: the Gap on "three"; the Scream Chord in the shaft; the Chairman throwing the chord back a beat late.

### Puzzles

**1. Three Doors, One Line (slice one).** The shaft's top door is bolted; the bolt is pulled from a storeroom cell 12 m from the mat by a Link standing still 4 s, and 3 s still inside 8 m of the Custodian is a Grab. Solution: a Conga pins storeroom, hall and shaft with segments in seams; Link 4 pulls while Link 3 Braces beside them (two standing plus one Braced, 4, beats grab Footing 3). Time: the Rearrange at 60 s rerolls any unpinned cell; a lost storeroom returns adjacent to the shaft on every third roll. Pair: one on the mat, one at the limit, wait for the adjacent roll. Solo: Spike the Ballast on the mat before the 4 s.

**2. The Wrong Shutter (slice two).** Two halls fork from the kitchen, a shutter on each; one is the lift hall, the other opens onto a Yellow Rooms wall that was not there last roll. Four cams carry Velluto labels (floors 7-9 and "Pool"); Cam 3 shows the fork node. Solution: hold nothing until the jukebox stops; he commits to a hall within one Step (8 s), and a hook (1 s) plus a 2 s walk into Bite beats him. Six holds both shutters, two pairs 9 m apart inside the 15 m reach; four holds one and must read Cam 3. Threat: a Tiny Tomato at 10.5 m/s drops on a holder for 3 s of blind; Bite does not need eyes, so the blind Link stands still. A gunshot skips his timer, which ends the puzzle.

**3. The Ledger of Daylight (slice three).** The clock starts at dawn when the first Link leaves the hood duct: 100 s of day, 60 s of night, frozen inside the freezer. The Nut Station at 375 m sits in a 6 m UV ring on the far roof; its generator cranks (two Links, 10 s, 60 s of light) are beside it. A full crossing is 12 s per Pair plus 5 s reset, 10 s crank, 6 s station: 67 s at six. Solution: cross at once. Fallback when night catches Pairs outside the ring (it holds one): two Popflares at 0 s and 25 s make 12 m of UV for 50 s, the ring covers the rest, and the dark Pairs Brace to hold a grabbed outsider at the 5.0 m stop. Threat: the pack (1 + floor(Links ÷ 2)) climbs the Stack's outside 20 s after sundown; a Loose Link during the station's 6 s is hunted at 2×; a Bloat on the near roof bursts across the cable.

### Main threat

**The Auditor.** 4 m, hi-vis vest, a clipboard in one hand and shears for the other; 800 HP (+15% per Link above 2: 1,280 at six). Sight 40 m, 110° cone; no hearing, so Noise, push-to-talk and Squeaky Dennis mean nothing to it. It is at every Nut Station from 330 m up, operating it (Level-specific mechanics), and does not hunt until the BR 5.3 door opens on slice five. There it has no Idle and no Retreat: Hunt at 3 m/s, always, toward the slackest visible segment; Attack is a 1.2 s shear close on the Deez of the Link who made the slack (higher closing speed over the last 1 s; tie, the nearer Link). That Link is **Loose**: both their segments fall away, the neighbors' segments re-forge to each other, and they have 60 s to hold interact 2 s within 1 m of any Link, re-attaching as a dangling Tail. At 60 s the Auditor takes them and the body is gone: no Deadweight, no Jumper Cables, no Break Room revive.

| Segment | Bite from | Cut when closer than |
|---|---|---|
| 5 m (Conga, Huddle) | 4.0 m | 4.0 m |
| 3 m (Pair) | 2.4 m | 2.0 m |
| 6 m (Trunk) | 4.8 m | 5.0 m |
| 4 m (Ballast) | 3.2 m | 3.0 m |

Speed: 3 m/s against walking 3.5 and sprint 7, so you can leave it behind, and you cannot, because a Line in Bite moves at its slowest Link and every stagger is slack. It never grabs, so the Line is never pulled; it steps over segments and walks through a ring in Bite without touching it. Items: any gun stuns 3 s per 100 damage (Snubby five rounds, Doorknocker two shells, Honker 12 s); Party Popper and Gum Bomb one stun each; Anchor Spike pins one Link so both their segments hold Bite; Spare Nut re-couples in 3 s with a second Link. Reviving needs a Link within 2 m, 4 s of slack: revive only inside a 6 s stun (200 damage) or behind a door (it cuts hinges, 4 s). Slack Jack, the Cinch and the Bungee Nut are cuts on a timer. At 0 HP it sits against the wall for the rest of the slice, shears in its lap, and is at the 405 m station regardless. What kills you: bunching at a door, stopping to argue, reviving in the open, a Hook with nobody Braced, the Rolling Chair.

### Roaming and secondary threats

- **Rollers** (slice one, ×6, 12 m/s unobserved): impact ragdolls 2 s and Jerks the Line; the Tail faces the lane.
- **Tiny Tomato** (slice two, ×2, 10.5 m/s, 40 HP): hood vents and the lift shaft; 15 damage and 3 s blind; targets shutter holders 50%.
- **Bloats** (slice three, 1 + floor(Links ÷ 2), 1.2 m/s, 60 HP): the near roof; a burst inside 4 m ragdolls the Line, which on a zipline is a snapped cable.
- **Bellhops** (slice four, 1 + floor(Links ÷ 3) routes, 10.5 m/s, cart 100 HP): marble landings only; the cart snags Taut segments toward the well at 2 m/s.
- **The Coworker**: slice four, 5.0 m behind the Tail, and the Roll Call extra at BR 5.3. **Rustmaw**: one on the Folded Corridor's carpet, drawn by the Tail's hand-carried slack. **The Hook**: every 3-6 min in slices one to five, never in the Spiral.
- **Bleed monsters**: the Custodian (slice one, full rules), Pappy (slice two, five nodes, 8 s Step), one Lantern pack (slice three, one night, 8 m/s), the Darlings (slice four), each confined to its slice. Dennis stands at the Spiral's last switchback in a hi-vis vest; the whip goes round him.

### Scripted jump scares

Targets: the Tail in a Conga, the lowest-Wellbeing Link in a Huddle, the Trunk Link in a Buddy System. All one-time per Shift, rerolled on Layoff, 60 s shared cooldown.

| # | Name | Trigger | Setup → payoff | Aftermath |
|---|---|---|---|---|
| 1 | The Reprint | Line passes the slice-one copier | One sheet: the team from behind, now, in this hall, and at the far end of the hall in the photo the Auditor, writing. Lights cut 1.5 s; the Line Bites once | A JERK label on whoever stepped back first |
| 2 | The Third Bang | Shutter held with Pappy at it | Bang, bang; on the third a Tomato at 10.5 m/s drops on a holder (3 s blind); if they step, Bite lapses and the shutter rolls up on his face at 1 m. Flinch-lock | The other holder sprints and hits the stop |
| 3 | The Freezer on the Roof | First Link touches the freezer handle | The clock freezes; the door swings out; the Water Tower Lantern is inside, 1 m away, roars 1.5 s, climbs out over the Link and away. It leads the night | The handle Link ragdolls into the Pair behind, halved, 20 to them |
| 4 | The Returning Guest | Line reaches the third landing | A Darling at the doorway calls by the name of a Link who died this Shift, in that player's recorded last 2 s; nobody dead, she uses the Tail's name in the Tail's own voice, 2 s old | The Tail answers; their segment rings on marble |
| 5 | Roll Call | BR 5.3 punch clock | The Foreman counts one too many. The extra stands in the Line between two Links, shackled in, in a player's model and name tag, 3 m from both neighbors. It smiles. The door opens; the Auditor reaches in, the shears close, the extra is Loose and gone; the neighbors' segments re-forge. "Headcount corrected." | Everyone checks their own nut; the door is open onto slice five |
| 6 | Clock-In | The 405 m station finishes | The shaft lights lap by lap from the bottom; a 12 m knot of cuffs and name tags climbs at 3.5 m/s, 70 m of catwalk below; the camera flinches down. "The Chairman will see you now." | The first sprint; the first Jerk; the first lost second |

### Procedural scare pool

Director: 1 credit per 40 s, cap 3; global cooldown 25 s; per-scare cooldown 180 s, 3 per Shift; none within 15 s of a scripted scare, a Nut Station or a Break Room; off in the Spiral. Target: Tail in a Conga, lowest-Wellbeing in a Huddle, Trunk Link in Pairs, Loose Links at 2×. Each slice may draw one scare from its origin level's pool at 2× cost (slice one from 3.1, two from 3.2, three from 3.3, four from 3.4); new entries:

| Scare | Cost | Trigger | Payoff |
|---|---|---|---|
| Wrong Cue | 1 | Target still 2 s | Another slice's cue, positional: a semitone drop on the roof, servo whine in the corridor, a tape reel in the kitchen; no monster |
| The Clipboard | 2 | Target looks through a seam window | The Auditor beyond the glass, writing; look away and back, 10 m closer; never through the glass |
| Nut Rain | 1 | Target under open vertical space | A Deez falls from above and bounces off their hat; 10% the Hook follows in 5 s |
| Previous Intake | 2 | Target near a shaft opening | A limp ragdoll in company overalls, name tag blank, lowered past on a chain, then raised |
| Stitched Voice | 1 | Two or more Links, a seam within 10 m | A teammate's voice from the next slice says the target's name, 2 s old |
| Jerk: Link 7 | 1 | Line still 5 s | A JERK label floats over empty space 5.0 m behind the Tail for 10 s; the scoreboard counts it |
| Badge | 1 | Target opens the badge | Wellbeing reads 0 for 0.5 s and the name tag is a dead Link's, or a name not on the team |

### Level-specific mechanics

**Slices.** Six 15 m rule sets with their origin level's full mechanics at raised tempo: Rearrange 60 s; Steps 8 s; day 100 s, night 60 s; Darling Draw steps 0.75 m; roamers at 1.5× speed; Bleed monsters cannot cross seams. Seams are hard: light, sound and floor change at a tile line, and a segment across a seam obeys both sides (one half silent on carpet, the other ringing on marble).

**Nut Stations.** One at every seam (330, 345, 360, 375, 390, 405 m): a wall-mounted DEEZ torque rig with six cuff sockets. Every living Link and every Deadweight sockets a cuff; the Auditor steps out of the wall, cuts every segment (all are slack at a station), re-threads the Line in the slice's shape and torques every Deez: 6 s, during which every Link is Loose, the Foreman reads the names, and nothing else can be done. Shapes: 330 Conga, 345 Huddle, 360 Buddy System, 375 Conga, 390 Huddle, 405 Conga. Legality: a Conga station makes a Line of (Links − 1) × 5 m at any count; a Huddle station at three or five gives the Conga; a Buddy System station at three or five adds the odd Link as a 3 m Tail on the Trunk; two Links are always a Pair, one is always the Ballast. Drop-ins attach as a Tail until the next station; Deadweight is threaded back in place. The station is not a checkpoint and cannot be skipped: the next slice's door is bolted until the torque reads complete.

**Door 1.** A 400 kg counterweighted hatch with a pull-ring sized for a Deez. The head Link hooks their cuff in; it swings open only when every living Link is in Bite in the same direction (every segment 4.0-5.0 m, every Link's velocity within 30° of the pull line) for 5 s continuous; any lapse resets the timer. Downed Links count as living and are dragged into Bite; Deadweight does not count. Solo: the Ballast is dropped down the counterweight shaft beside the door and its 4 m segment makes the pull.

### Loot

12 + 4 × Links spawns from the pool of 40, biased toward chain tools and stuns, with the slack-makers made rare on purpose.

| Item | Weight | Where |
|---|---|---|
| Spare Nut | ×3.0 | Every Nut Station alcove, Break Room lockers |
| Anchor Spike | ×2.5 | Slice five landings and corner posts |
| Snubby, Doorknocker | ×2.0 | Slice five (two Snubbies guaranteed), the Boardroom safe |
| Popflare | ×2.0 plus two guaranteed | The freezer's shelf, slice three |
| Mirror Shard, Salt Cellar | ×2.0 | Slice four doorways |
| Mystery Juice Box | ×2.0 | BR 5.4 vending machine; a Goat is the Chairman's counter |
| Party Popper, Gum Bomb | ×1.5 | Kitchen pinata, Velluto trolleys, Boardroom |
| Dependable Torch, Squeaky Dennis | ×1.0 | Slice one desks |
| Rolling Chair | ×0.5 | Slice one; a Roller at 12 m/s when you stand |
| Slack Jack, the Cinch, Bungee Nut | ×0.3 | Slice four Room Service only |
| The Honker | 1 guaranteed | BR 5.4 locker, one round |

### Checkpoints and exit

Four Break Rooms: **5.1 Onboarding** (345 m, after the Shaft That Rearranges), **5.2 the Walk-in** (360 m, a freezer that smells of flour, after the Hood Lift), **5.3 the Interview Room** (390 m, after the Folded Corridor; Roll Call), **5.4 the Boardroom** (405 m, before the Spiral; the Honker in the locker). No room between 360 and 390 m: slices three and four run back to back, one night into one corridor, the rising tempo made of distance. A sealed room stops the slice clock (day, Step, Rearrange).

**The Chairman (slice six).** Clock-In starts the chase: a 12 m knot of every previous team's chains, cuffs and Deez Nuts, no HP, hauling itself along the Spiral's rail at 3.5 m/s, 70 m of catwalk behind the Tail (20 s). The route is 350 m and 15 m up: a clean walk at 3.5 m/s is 100 s, the Door 1 pull is 5 s, and the Chairman reaches the door at 120 s whether or not you are through it. The margin is 15 s of stalls, spent at 1.5 s per Jerk, 1 s per whip ragdoll, 2 s per cut chain, and bought back at 1 s per second the whole Line sprints together.

| Gap to the Chairman | What it does |
|---|---|
| over 40 m | Climbs; plays your own team's last 2 s of voice back at 10%, lowpassed |
| 40-20 m | Every 10 s throws a chain that cuffs the nearest Taut segment (those hanging over switchback rails first) and reels at 1.5 m/s; two Braced Links hold it at the stop while a third cuts: any gun 2 s, any explosive, a Goat 2 s |
| under 20 m | Every 6 s the 20 m chain-whip sweeps the lap at head height: 30 damage and ragdoll, or crouch, or Brace and hold; it goes round Dennis |
| 0 m | Grab-kills from the Tail up, one per 2 s, cut to black: Layoff to 5.4 |

Fail points: Switchback 1 (the Line over the rail is the first chain's target); the Gap (a double step is a Jerk into the shaft, arrested by the Line, 1.5 s); the Dead Lines (a Taut segment snags 1.5 s, three in a row is a whip); the door pull, where one Link turned to look resets 5 s with the Chairman at 20 m. Honker: 400 into the lead knot stalls it 3 s, once. The Cinch: 10 s in which nothing can be reeled, at the cost of a six-body pile. Lift Assist Unit: 3 masses up the shaft core at 4 m/s with the rest dangling, and the Line is still 25 m long.

**Door 1 and the endings.** The hatch swings out onto the roof at 420 m at dawn, a field below, a bus stop, the Stack's shadow across it. The shift timer reads "Shift Complete," every Deez unscrews itself and bounces (Deadweight pulled through is reinstated at 50 as its nut falls), and the Foreman reads the Incident total, flat. Three endings: **Shift Complete** (every Link alive through the door: the bus stop light comes on); **Reinstated** (any Deadweight dragged through: the Separations are read by name, "reinstated at clock-out"); **Clean Shift** (no Layoff all Shift: ×2 on the 300 exit and 300 boss, and the nuts roll into a line in formation order). A Layoff on the Spiral returns to 5.4; the Chairman re-rolls which switchback it throws at first.

**Credits gag.** The credits are a crane manifest: a chain lowers past the camera from above the roof, a cuff per name, the team's own names last. The last cuff is the Hook. It snags the Tail's bare wrist, lifts them 10 m at 3 m/s, holds 4 s, lets go. "Incident logged. File a report when safe." The roof stays playable through the whole crawl; hats remain physics.

### Comedy beats

1. **The Self-Audit.** A Spare Nut bolted onto the Auditor chains it to the Line at 3 m: under 4 m, an infraction. It cuts itself free, writes it up, resumes. Logged against the bolter.
2. **The Wheel.** A six-ring walks the Audit Stair in perfect step and the Auditor climbs up through the middle of it, reading, while everyone whispers "don't stop" at someone who has not stopped.
3. **The Wrong Way.** Five Links in Bite at Door 1 and the sixth facing the Chairman to see how far away it is. The timer resets at 4.8 s. Twice.
4. **The Last Jerk.** The nuts are off, the roof is safe, a Traffic Cone hat blows toward the edge and its owner dives; for the first time in three hours nobody is attached to them.
5. **Goat Logic.** A Juice Box Goat chews the Chairman's reel-chain in 2 s, then the nearest segment of the Line in 4 s, then eats the Honker.

### Audio notes

- **Ambience:** every slice's bed runs inside its own 15 m with a 2 m crossfade at the seam, so a Link standing in a seam hears the fluorescent hum in one ear and the half-speed jukebox in the other. The lounge piano drifts flat under slices four to six and never resets. The Spiral has only the shaft: wind from below, chain on steel from below, the team's own voices coming back up.
- **The Foreman** is positional now: the PA is a speaker in the Auditor's vest, so Roll Call, the names at every station and "The Chairman will see you now" come from 2 m, and in slice five every line comes from wherever the shears are.
- **Monster cues** keep their origin values (semitone drop, servo whine, wet click, tape reel) and overlap in the wrong slice via Wrong Cue. New cues: the Auditor's pen on paper, continuous while it has a target, and the shear's 1.2 s hydraulic close with no impact sound; the Chairman's 12 m rockfall of chain, every cuff ringing on the rail, under a chorus of previous teams at 10%.
- **Music states:** Orientation (the hum plus the jukebox); Fire Drill (sodium drone, then the sub-bass pulse tracking the nearest Lantern, capped at 3 Hz); Hospitality (the piano, flat); the Audit (nothing but the pen; a 30 Hz subharmonic rises with each cut); the Spiral (the Pack Run's drums at 140 bpm tuned to the Scream Chord, gaining a bar of chain percussion each time the gap closes a band); Door 1 (silence for the 5 s pull, then dawn: one sustained major chord built from this team's own ragdoll screams this Shift).
- **Proximity voice:** 15 m, carried across seams at the seam's attenuation (carpet to marble is an 800 Hz lowpass; roof to kitchen is open). The Nut Station re-pans teammates to their new positions in the Line mid-sentence. The Chairman replays every Link's last 2 s of voice at 10%, lowpassed, from the knot: whoever is talking hears themselves gaining. Corpse voice restores to full through Door 1 as the nut falls. Push-to-talk is honored; the Auditor cannot hear, the Chairman cannot be outrun by silence, and every fail state here is reachable by movement alone.

---

## 4. Items - "Go Stupid With It"

Every item has a number on it and a second number for what it does to the five people tied to the holder. Nothing below plays the same without the Line; where an item would, its side effect is the Line.

### Inventory & handling rules

**The Lanyard.** Two hand slots and one **Pocket** per Link; the Pocket holds one one-handed item and is the only slot kept through a Layoff. Pocket swap 1 s, silent.

**Pickup, drop, throw.** Interact 0.3 s within 1.5 m; both hands full drops the active item. Items are rigid bodies (1-4 kg; Honker 14, Longboy 30) that persist in place for the Shift; the Sump keeps what falls in. Hold throw 0-1 s for 5-15 m (Ballast 6 m); a thrown item does 10 to a monster, 5 and a 0.5 s stagger to a Link, and knocks any hat off. A Jerk during the wind-up drops it at your feet, fuse and all. No ammo pickups exist; an empty gun is a 10 dmg throwable.

**Passing along the Line.** *Hand-off:* interact 0.5 s on a Link within 2 m, silent; on 5 m segments that is walking into Give, which the Auditor counts. *Line Pass:* hold interact on your own Deez 1 s to clip a one-handed item to the cuff; it slides to your neighbor at 2 m/s while the segment is in Bite, hangs in the sag in Give, snags on corners, and anything with reach (Lantern, Shambler, Rustmaw) can take it in transit. One item per segment.

**Two-handed (2H)** items fill both hands; drop them to Brace. The Longboy takes one hand from each of two adjacent Links; if either lets go it falls, and one Link cannot lift it.

**Hats** are physics, not items: a knocked-off hat fills a hand slot until re-worn (0.5 s).

**Downed:** hand items scatter 1 m, the Pocket stays. **Dead:** hands drop, the Pocket stays on the Deadweight. **Loose:** nothing drops. **Layoff:** Pocket kept, hands lost.

**Friendly fire** is full, always, no lobby toggle: every gun, blast, swing, flame and salt hits Links at listed values. The Foreman logs each as a "workplace injury"; the scoreboard counts them beside Jerks.

### Rarity tiers & loot rules

| Tier | Weight | Share of draws | Lanyard color |
|---|---|---|---|
| Common | 45 | 45% | caution yellow |
| Uncommon | 30 | 30% | white |
| Rare | 18 | 18% | hazard orange |
| Legendary | 7 | 7% | hex-nut chrome |

**Spawn count:** 12 + 4 × Links per level (16 solo, 20, 24, 28, 32, 36 for six), drawn at level load from the 40-item pool across 40 authored spawn points, without replacement, at most 2 Legendaries per level from floor spawns. Small teams draw proportionally more awkward loot.

**Spawn point types (40 per level):**
- **On-Path (24):** within 3 m of the critical climb. Draw weight 1.0.
- **Stretch (10):** 4-5 m off the path, behind a railing, across a gap or past a Rearrange seam: one Link at full Bite while a neighbor stands or Braces. Draw weight 1.2. Solo, throw the Ballast onto the ledge first.
- **Bait (6):** within 10 m of a threat node (Custodian cavity, Pappy graph node, Lantern roost, Darling doorway). Rare weight doubled. Draw weight 1.5.

**Lockers.** The 3 per Break Room are outside the count: one item (Common 60 / Uncommon 30 / Rare 10), one hat, one empty that bangs once. **Pity:** a level's third Break Room with no Rare or Legendary yet forces the next locker item Rare. **Vending Machine:** 5 Washers for 60% a Common, 25% a warm sausage (heals 5; thrown 10 m, it baits the crab, Tiny Tomato and Shamblers for 3 s), 10% a live crab, 5% a Legendary. **Room Service** (Velluto): 30% a Rare, outside the count. **Solo pool:** items needing a second Link (the Longboy, the Transfer Form) leave the pool.

**Level bias** (multipliers on pool weight; unlisted stays 1.0):

| Level | ×2 | ×0.5 |
|---|---|---|
| The Yellow Rooms | Dependable Torch, Squeaky Dennis, Grease Can, Rolling Chair | Snubby, Doorknocker, Air Horn |
| Pappy Pepperoni's Night Shift | Party Popper, Big Red Button, Salt Shaker, Anchor Spike | Lift Assist Unit, Popflare |
| Carrow Heights | Popflare, Harpoon Reel, SHIFT! Energy, Bungee Nut, Corporate Umbrella | Rolling Chair, Grease Can |
| Hotel Velluto | Mirror Shard, Salt Shaker, Doorknocker, Slack Jack | Squeaky Dennis, Air Horn |
| The Exit Interview | Spare Nut, Jumper Cables, The Cinch, Mystery Juice Box (weight 14) | Slack Jack, Bungee Nut, The Longboy |

### Weapons

Every shot is Noise +40 (a scream to the Custodian, a skipped timer for Pappy, a fix for Lanterns at 30 m); every muzzle flash is a full Flinch for Links within 6 m.

**Snubby** — Pistol · Common · 12 rounds, no reload, 0.4 s per shot. 20 dmg, 40 m. *Line:* six Links Flinching toward one muzzle at the stop is a Jerk from every side. *Backfires:* one shot takes a quiet Link from 21 Noise past 60. *Funny:* the smallest thing in the game, and the first thing anyone shoots a friend with.

**Doorknocker** — Shotgun · Uncommon · 6 shells, 1.0 s pump. 90 dmg within 5 m, 30 at 10 m; two shells for a Vacancy, three for a Lantern. Recoil shoves you 1.5 m back. *Line:* in Give the shove is free; in Bite it Jerks your neighbor; on a ledge it is their fall. *Backfires:* a Chain-line anchor who fires shoves the anchor. *Funny:* being caught by someone who did not agree to it.

**The Honker** — Oversized gun · Rare · 2H · 1 round. A 1.4 m revolver: 400 dmg, 60 m, through 3 bodies. Recoil launches you 6 m backward, airborne, Line attached; empty, a 14 kg club (30 dmg). *Line:* you hit the stop at 8-10 m/s; an unbraced neighbor comes too, a Braced one holds and you swing from the segment into whatever is below. *Backfires:* on a catwalk, 6 m back is off it. *Funny:* the only label reads BRACE.

**The Longboy** — Oversized weapon · Rare · two adjacent Links, one hand each · 4 rounds, 8 s two-Link reload. 3 m rifle: 250 dmg, 100 m; the front Link aims, the rear fires; recoil shoves both carriers 1 m backward at once, which in a Conga Jerks both outer segments; both move 2 m/s and cannot climb, jump or Brace. *Line:* a rigid 3 m bar, so the carriers' segment never Bites, and on the Auditor's slice 3 m apart is a cut. A Jerk on either carrier drops it (30 kg, two to lift). *Backfires:* the rear Link cannot see the target. *Funny:* "FIRE" shouted down 3 m of rifle by two people who can hear each other fine.

**The Ladle** — Oversized melee · Rare · 2H · 3 s cooldown. 3 m cast iron: 120 dmg, 180° arc over 2.5 s, monsters knocked 8 m; held out it blocks a Vacancy lunge; laid flat it bridges 2.5 m at Footing 1. *Line:* the arc launches any Link in it 8 m, and a Huddle at rest always has a neighbor inside it. *Backfires:* in a hallway it hits the hallway. *Funny:* a hit Link rings like a bell, and the Scream Chord tunes to it.

### Explosives

Blasts ragdoll every Link within radius + 2 m for 1 s, a Jerk on everyone in Bite; Noise +60, and Pappy smells it.

**Party Popper** — Bomb · Common · 1, 3 s fuse. 150 dmg, 4 m, throw 15 m; stuns Big Dough 5 s. The fuse starts on pickup if you are sprinting. *Line:* a Jerk mid-throw drops it lit at your feet, and the Line keeps four other people within 5 m of them. *Backfires:* sprinting Links pick things up without reading them. *Funny:* the Foreman calls the explosion "the party."

**Gum Bomb** — Sticky explosive · Uncommon · 1, remote detonate at any range. Sticks to the first thing it touches (walls, Lanterns, Pappy, teammates, hats, the Line): 150 dmg, 3 m. A stuck Link cannot peel it alone: a second Link within 1.5 m holds interact 2 s, and peeled gum re-arms in 10 s. *Line:* on a segment it rides the Line and detonates on both its Links. *Backfires:* thrown from Bite, the Jerk puts it on a neighbor's hat. *Funny:* a hat with a bomb on it is still a hat.

**Severance Package** — Parcel bomb · Uncommon · 1, 15 s timer from first pickup, +4 s per hand-off to a new Link. Throwable (15 m; 250 dmg, 5 m, breaks any door, 8 m ragdoll) only once every living Link has held it; Dead count as signed, Downed cannot sign, the Pocket does not pause it. *Line:* six signatures at 2 m reach is a 25 m Conga closing to 10 m and reopening inside 15 s. *Backfires:* that closing is Give, and the Auditor is walking toward it. *Funny:* six adults sprinting at each other to sign a bomb.

### Consumables

**SHIFT! Energy** — Energy drink · Common · 1 can. +50% speed for 15 s, 110° FOV, 1° camera jitter (photosensitivity toggle: HUD wobble only); then a 10 s crash at −30% and a yawn heard 12 m (Noise +20) that drops your held item. *Line:* a +50% Link reaches the stop in 1.2 s, and sprinting into the stop is a 1 s ragdoll. *Backfires:* the crash lands mid-Chain-line. *Funny:* the yawn is contagious, every Link within 3 m yawning 1 s later, in order, down the Line.

**First-Aid Kit (expired)** — Consumable · Common · 1. Heals 50 over 3 s on yourself or a Link within 2 m; interrupted by damage. Solo, in the Pocket: self-revive 5 s after Downed, once per Break Room. 15% it is a sticker: heals 1, says GOOD JOB, stays on the cuff. *Line:* unusable in Bite; your hands are holding on. *Backfires:* healing the Tail stops the Line. *Funny:* the most common reason a Link says "oh no" calmly.

**Salt Shaker** — Consumable · Common · 3 shakes, 2 m cone. A salted Vacancy takes 2× damage for 10 s; a 1 m salt line holds a Carpet Mouth shut 20 s, and a Darling will not step over it, she asks you to. Ends a Snail form (2 s ragdoll). *Line:* the Line dragged across a salt line scatters it in 2 s. *Backfires:* 25% the loose lid dumps all three on first use. *Funny:* salting the teammate carrying the team up a wall as a snail.

**Jumper Cables** — Revive · Rare · 1. Clip to Deadweight (2 s, 1.5 m): revive at 25. The current runs the whole Line: 20 dmg to any monster touching it (a Shambler lets go, Rustmaw drops, a Vacancy grab breaks), and every Link takes 10 and a 2 s stagger. *Line:* the only moment nobody is Jerking anyone. *Backfires:* any Link at 10 or under is Downed by the revive. *Funny:* the revived Link wakes to the whole team twitching in unison.

### Mobility & tools

**Lift Assist Unit** — Jetpack · Rare · 2H · 10 s fuel. 2,000 N lifts 3 masses at 4 m/s, 4 at 2, 5 at 1, 6 at 0.5; hold to thrust, look to steer, 0.4 s lag. *Line:* the lightest-Footing Link rises first, which is always the one already dangling; standing Links hold the pack down, so the Line rises only when everyone jumps on a count; a Huddle spins 30°/s; at empty everyone drops from wherever they are. *Backfires:* the lag makes every correction a 2 m wobble by second 5. *Funny:* the sticker reads NOT A FLIGHT DEVICE.

**Harpoon Reel** — Grappling hook · Uncommon · 3 shots, 2 s re-reel. 25 m line, pulls you at 8 m/s; pulls 2 masses, and a third on the Line snaps the cable into your face (10 dmg). *Line:* a Pair rides it whole; in a Conga the third Link is the snap, so give the pull Give first. *Backfires:* harpoon a Bellhop cart and you are attached to a cart doing 7 m/s. *Funny:* the hook sticks to Dennis, and the reel pulls Dennis.

**Dependable Torch** — Flashlight · Common · 90 s battery, 20 m cone. Custodian stain 2 s on, 20 s retreat; Pappy frozen 1.5 s (8 s cd); Lantern 2 s under 5 m; Vacancy 1 s (8 s cd); the Coworker's bare cuff flees 60 s; a Darling's face 2 s, the Turn. Shake 3 s for 10 s of battery at Noise +6/s; Lanterns see it at 60 m, Pappy at 25 m. *Line:* carried mid-Conga, 20 m covers both Tails; every scare flinches the beam 0.4 s off its target. *Backfires:* on in the Pizzeria you are a lit Link on Pappy's graph. *Funny:* the switch clicks at Noise +2, and six people flinch at a click.

**Popflare** — Flare gun · Uncommon · 3 UV flares. 40 m shot, 12 m light, 25 s; Lanterns blinded 4 s and will not enter it, a Vacancy flees 10 s, nothing despawns; a flare at a Lantern's feet makes it drop the Link it carries. *Line:* burning carpet or a burning teammate ignites the Line: 5 dmg/s for 5 s, traveling 1 m/s to each neighbor unless they crouch-spam (3 in 2 s). *Backfires:* fired onto Yellow Rooms carpet, the whole Line burns in order. *Funny:* the Foreman counts "colleague on fire" one at a time, calmly.

**Squeaky Dennis** — Decoy noisemaker · Common · 1 throw. A rubber Dennis head: throw 15 m, squeaks 20 s at Noise 40 m; the Custodian reads it as a Link at Noise 60, Pappy as a slammed door, Lanterns hear it at 30 m, a Darling at 15 m stays in Draw 20 s, Rustmaw comes from 20 m. In the Pocket it squeaks on every ragdoll. *Line:* a Conga falling together squeaks in sequence. *Backfires:* thrown from Bite it lands at your feet, and so does the Custodian. *Funny:* it is Dennis.

**Air Horn** — Noise · Uncommon · 3 blasts. Stuns every monster within 12 m for 2 s, bosses included; Noise 100 m; Links within 6 m deafened 5 s, no proximity chat, no tells. *Line:* 12 m covers a Huddle: one blast stuns everything on the team and deafens the team. *Backfires:* in the Yellow Rooms the Custodian goes straight to Grab on the holder. *Funny:* the Foreman files it as a noise complaint, against you.

**Big Red Button** — Tool · Uncommon · 1 press. 20% each: opens the nearest door; seals every door on the floor 30 s; calls the nearest lift; summons the Hook onto a random Link; plays the Birthday Song, targeting the presser. *Line:* sealing doors with the Line through one Pinches both Links; the Hook lifts the Line. *Backfires:* two outcomes are a threat and one is the worst scare in the level. *Funny:* it says DO NOT and nothing else.

**Mirror Shard** — Tool · Uncommon · 3 stuns (8 s cd). Held up, a true Darling shows as a Vacancy silhouette at 40 m; shown to a Vacancy within 5 m, 2 s stun. Also shows the Coworker behind you, whether or not you wanted to know. *Line:* the Tail carries it; the Coworker walks 5.0 m behind the Tail. *Backfires:* a Jerk drops it, 10% shatter. *Funny:* it shows the holder's hat sitting slightly worse than it does.

**Grease Can** — Deployable · Common · 1 pour, 120 s. A 4 m slick at Footing 0 for Links and monsters (Lanterns slide 4 m, Big Dough falls 3 s, Bellhop carts turn 90° half the time); the Line stops snagging inside it. *Line:* six Links on 4 m of slick on a slope is a six-body slide, which is a Scream Chord. *Backfires:* grease on the stairs of the Corpse Commute. *Funny:* the slide.

**Corporate Umbrella** — Mobility · Uncommon · 60 s of use. Deploy 0.5 s; the holder falls at 3 m/s from any height, no damage. A second mass on the holder's segment rips it inside out for good. *Line:* it holds one, so the team lowers the umbrella Link 5 m at a time like a bucket. *Backfires:* Carrow Heights wind adds 2 m/s of drift toward the gap. *Funny:* one person floats and five are a counterweight.

**Rolling Chair** — Mobility · Common · unlimited. Sit 1 s; roll 5 m/s on flat ground, hands free, silent on carpet, Noise +3/s on marble; stairs are a fall; seated Footing 0.3. Stand up and it is a Roller: 8 m/s unobserved, 2 s ragdoll on impact. *Line:* a walking Link tows a seated one, so seat the Downed Link and the −30% luggage penalty is gone. *Backfires:* look away. *Funny:* the Yellow Rooms chair is waiting on a Carrow Heights rooftop.

### Chain gadgets

**Spare Nut** — Chain · Uncommon · 1. Re-couples a Loose Link in 3 s with a second Link within 1 m. Bolted onto a monster (3 s, 1.5 m) it chains that monster to you on a 5 m segment: a Lantern that cannot leave, a Shambler that is 150 HP of Deadweight with teeth. *Line:* the monster counts for load and it Jerks. *Backfires:* its pack still comes. *Funny:* Roll Call counts it.

**Slack Jack** — Chain · Uncommon · 1, 60 s. +3 m Give on one segment (Give to 7 m, stop at 8 m): reaches an 8 m Stretch spawn, lets the Desk Jockey stay clipped 3 m longer. Ends with a 2 m snap-back that pulls both Links together at 6 m/s. *Line:* jacking the Trunk stops the Trunk Link being the Jerk for a minute. *Backfires:* the Auditor now cuts under 7 m instead of 4 m. He loves it. *Funny:* the snap-back collides two Links the moment they relaxed.

**The Cinch** — Chain · Rare · 1, 10 s. A 4,000 N winch reels every Link to 1.5 m of the user over 2 s, beating any Footing under 99; hauls a dangler, a Deadweight, or a Link in a Lantern's grip; segments reopen over 2 s. *Line:* everyone arrives at once into a 1 s ragdoll pile, and while cinched every segment is Give the Auditor can cut. *Backfires:* solo, 35 kg of Ballast arrives at speed. *Funny:* the pile.

**Anchor Spike** — Chain · Uncommon · 2 spikes, 15 s each. Hammer 1 s: your cuff is pinned at Footing 99; you cannot move but can shoot, Brace and use items. Anchors a Chain-line, a Pendulum, a shutter pull, a Lantern grab; the Hook still tries, strains 4 s and lets go. *Line:* a spiked Link is a wall, and whichever side of a Pinch holds the spike cannot pull. *Backfires:* you spiked the only Link who could have helped. *Funny:* the spike goes through the cuff, not the wrist, and the Foreman records "no injury."

**Bungee Nut** — Chain · Rare · 1, 45 s. One segment's stop becomes elastic: Give to 5 m, stretch to 10 m, snap-back at 12 m/s, which is ragdoll speed. Crosses a 9 m gap (jump, land, Brace, the neighbor is snapped across); Pendulums reach 10 m. *Line:* the snap-back ignores walls, railings and the teammate in between. *Backfires:* on the Auditor's slice, 10 m of elastic is 9 m of Give. *Funny:* six people, one elastic, one wall.

**Transfer Form** — Chain · Uncommon · 1. Two Links within 3 m hold interact on their own Deez 2 s: their positions on the Line swap. Bodies stay; the Line re-threads in 0.5 s through whatever is between them, wrapping a pillar, snagging a railing, tripping a teammate 1 s. Moves the Tail off the Tail before a scripted scare, puts the Desk Jockey at the front. *Line:* both Links are Loose for 0.5 s, and Rustmaw and the Auditor both know. *Backfires:* either Link Downed and the form is spent. *Funny:* it is in triplicate, and the Foreman says "Transfer approved."

### Transformation Item

**Mystery Juice Box** — Transformation · Legendary · 1 drink, 1.5 s through the straw. Pool weight 7 (14 in the Exit Interview; 5% from any Vending Machine). Pocketable, throwable, hand-off-able; whoever drinks, rolls: **hero 30%** (five forms at 6% each), **animal 70%** (seven forms at 10% each), then **10% Group Plan** on top: every living Link takes the same form at once. The label flavor is random and means nothing.

Rules for every form:
- Lasts its duration or until Downed; ends with a 1 s ragdoll back to human wherever you are, at whatever height. Forced third person throughout.
- The model swaps in 0.8 s, a 0.4 s Flinch for Links within 5 m. The Line does not scale: the Deez stays on the equivalent limb at the same 5 m, which is why Big Lad hangs five people off one wrist and the Snail is a wall anchor with a Line on it.
- Forms with their own HP (Big Lad 500, Pigeon 20) use that pool; reaching 0 in-form ends the form Downed. Forms that cannot hold items drop both hands; the Pocket stays.
- Solo, the Ballast never transforms, and Group Plan is just you.

#### Hero forms

| Form | Duration | Abilities | Effect on the whole chain | Weakness / comedy |
|---|---|---|---|---|
| **The Dome** (bald one-punch hero) | 20 s | One punch (2 s wind-up) kills any non-boss; bosses lose 25% HP; walks 3 m/s | Immovable, Footing 99: the Line is anchored to a wall that walks; everything Jerks off him | The punch wind knocks every teammate 10 m and deletes the door, wall or floor you needed; every Link lands as a fall |
| **The Hurry** (speedster) | 10 s | 18 m/s, 12 m jumps, phases through Shamblers | Teammates water-ski behind, airborne after 2 s, ragdolling at 9 m/s, each Jerking the next | Cannot turn sharper than 30°; stops only by hitting something, and so does everyone behind |
| **The Lifter** (flying strongman) | 15 s | Flies 6 m/s, lifts all six Links, throws one Link or monster for 200 dmg | The whole Line dangles from one wrist in a 15 m column; the lowest Link is at Lantern height | Cannot hover; says "I've got you" and lands at 6 m/s, which is a fall, for everyone, in order |
| **Mister Slack** | 20 s | Arms extend 10 m to grab ledges, levers and Links; pulls 2 masses | Own segments elastic to 10 m, so neighbors get Give they did not ask for | Snap-back Jerks neighbors at 2×; cannot hold items; the Auditor reads the elastic as Give |
| **Big Lad** | 15 s | 4× size, 500 HP, ignores knockback, 3 m/s; breaks any door he can reach | Everyone hangs from his cuff like keys, 6 m off the floor | Does not fit through any door built so far; when he ends, the keys drop 6 m |

#### Animal forms

| Form | Duration | Abilities | Effect on the whole chain | Weakness / comedy |
|---|---|---|---|---|
| **Snail** | 45 s | 0.8 m/s; sticks to walls and ceilings; immune to Jerks; 0 Noise | A living Anchor Spike that carries the dangling team straight up any wall at 0.8 m/s; the trail is Grease | Salt ends it; 45 s is a long time to be screamed at by five people hanging under you |
| **Pigeon** (bird) | 20 s | Flies 5 m/s; carries 1 Link | Tries to carry five people: each extra Link cuts speed to 0.3 m/s and it sinks 1 m/s, panicking audibly | 20 HP; one Tiny Tomato (15 plus 3 s blind) leaves it blind at altitude, and the next contact ends it mid-air |
| **Cat** | 30 s | 0 Noise, 2× climb, always lands on feet, nine lives (9 free fall-deaths) | The cat lands on its feet; the other five do not, each at listed fall damage | Freezes 2 s to stare at the Custodian's stain; cannot hold items |
| **Goat** | 30 s | Climbs 70° slopes at 3 m/s; headbutt 30 dmg; chews the Chairman's thrown chains in 2 s | Hauls two Links up any slope | Also chews the Line: 4 s of nibbling sets a Link Loose; eats one held item per 10 s |
| **Frog** | 25 s | 8 m hop; 6 m sticky-tongue grab of items and Links | Every hop Jerks the Line unless Give is 3 m or more, so the Line learns to hop on a count | Sticks to the first thing the tongue hits; Lanterns consider it food |
| **Elephant** | 20 s | 2,000 kg, Footing 99, immune to grabs; 2 m/s | Holds the entire Line against anything, including the Hook and a Vacancy drag | Every floor, plank, catwalk and inflatable chef it stands on fails in 3 s; cannot climb |
| **Bat** | 25 s | Echolocation pings monsters through walls at 30 m every 2 s; flies 3 m/s; carries nobody | Everyone sees what the Bat pings; the Line hangs 5 m under a 3 m/s bat | Flashlights blind it 3 s; idle 2 s and it hangs upside down, inverting the Line |

### Master stat table

| Item | Category | Rarity | Effect | Duration / uses | Side effect |
|---|---|---|---|---|---|
| Snubby | Pistol | Common | 20 dmg, 40 m, Noise +40 | 12 rounds | Muzzle Flinch; Pappy skips a timer |
| Doorknocker | Shotgun | Uncommon | 90 dmg within 5 m | 6 shells | 1.5 m recoil shove Jerks the Line |
| The Honker | Oversized gun | Rare, 2H | 400 dmg, 60 m, 3 bodies | 1 round | Launches you 6 m, Line attached |
| The Longboy | Oversized weapon | Rare, two Links | 250 dmg, 100 m | 4 rounds, 8 s reload | 1 m recoil on both carriers; segment fixed at 3 m |
| The Ladle | Oversized melee | Rare, 2H | 120 dmg, 8 m knockback; bridge | 3 s cd | 2.5 s arc launches any Link in it |
| Party Popper | Bomb | Common | 150 dmg, 4 m, throw 15 m | 1, 3 s fuse | Fuse starts on pickup if sprinting |
| Gum Bomb | Sticky explosive | Uncommon | Sticks anywhere, remote, 150 dmg, 3 m | 1 | Sticks to Links, hats, the Line |
| Severance Package | Parcel bomb | Uncommon | 250 dmg, 5 m, breaks doors | 1; 15 s + 4 s per signature | Throwable only once every living Link has held it |
| SHIFT! Energy | Energy drink | Common | +50% speed, 110° FOV, jitter | 15 s, then 10 s crash | Crash yawn drops held item |
| First-Aid Kit (expired) | Consumable | Common | Heals 50 over 3 s; solo self-revive | 1 | 15% sticker heals 1 |
| Salt Shaker | Consumable | Common | Vacancy 2× dmg 10 s; salt line | 3 shakes | 25% lid dumps all; ends a Snail |
| Jumper Cables | Revive | Rare | Deadweight revives at 25; 20 dmg to monsters on the Line | 1 | Every Link takes 10, 2 s stagger |
| Lift Assist Unit | Jetpack | Rare, 2H | 2,000 N; 3 masses at 4 m/s | 10 s fuel | 0.4 s lag; dangler rises first; drops all at empty |
| Harpoon Reel | Grappling hook | Uncommon | 25 m, pulls 2 masses at 8 m/s | 3 shots | A third mass snaps it into your face (10) |
| Dependable Torch | Flashlight | Common | 20 m cone; stuns listed monsters | 90 s; shake 3 s = 10 s | Seen at 60 m by Lanterns; shake is Noise +6/s |
| Popflare | Flare gun | Uncommon | UV 12 m; repels Lanterns, Darlings | 3 flares, 25 s | Fire travels the Line at 1 m/s |
| Squeaky Dennis | Decoy noisemaker | Common | Noise 40 m for 20 s | 1 throw | Squeaks on every ragdoll; draws Rustmaw |
| Air Horn | Noise | Uncommon | Stuns monsters within 12 m, 2 s | 3 blasts | Noise 100 m; deafens Links 5 s |
| Big Red Button | Tool | Uncommon | Door / seal / lift / Hook / Birthday Song | 1 press | You never know which |
| Mirror Shard | Tool | Uncommon | True Darlings at 40 m; Vacancy stun 2 s | 3 stuns, 8 s cd | Shows the Coworker behind you |
| Grease Can | Deployable | Common | 4 m slick, Footing 0; no snagging | 120 s | Six-body slide |
| Corporate Umbrella | Mobility | Uncommon | Holder falls at 3 m/s | 60 s | A second mass rips it inside out |
| Rolling Chair | Mobility | Common | Roll 5 m/s; tows a Downed Link | Unlimited | A Roller when you stand up |
| Spare Nut | Chain | Uncommon | Re-couples a Loose Link in 3 s | 1 | Bolts a monster onto the Line |
| Slack Jack | Chain | Uncommon | +3 m Give on one segment | 60 s | 2 m snap-back Jerk; Auditor cuts under 7 m |
| The Cinch | Chain | Rare | Reels every Link to 1.5 m | 10 s | Ragdoll pile; every segment cuttable |
| Anchor Spike | Chain | Uncommon | Pins a cuff at Footing 99 | 2 × 15 s | Cannot move; the Hook still tries |
| Bungee Nut | Chain | Rare | One segment elastic to 10 m | 45 s | 12 m/s snap-back, ragdoll speed |
| Transfer Form | Chain | Uncommon | Two Links swap positions | 1 | Re-threads through obstacles; both Loose 0.5 s |
| Mystery Juice Box | Transformation | Legendary | Random form: hero 30%, animal 70% | 10-45 s by form | 10% Group Plan |

---

## 5. Enemies, Bosses & Combat

### Combat rules

**Damage model.** 100 Wellbeing per Link, no regen. Falls: under 4 m none; 4-8 m 30; 8-14 m 70; over 14 m Downed; over 20 m or the Sump Dead. Fire 10/s. Landing on a teammate halves yours and deals them 20. At 0: **Downed** (crawl 1 m/s, 45 s bleed-out; revive 4 s within 2 m, return at 40). A grab-kill, the Sump or a Loose timer skips Downed: Deadweight (80 kg, Footing 0, still on the Line). Grab-kills cut to black. Monster HP is the 2-Link base, +15% per Link above 2.

**Four outcomes.** Every item-on-monster interaction is a **Kill** (HP to 0), a **Stun** (frozen; no re-stun inside the source's cooldown), a **Repel** (forced Retreat) or a **Distract** (re-target to a louder source). **Permanent Staff** (marked Unkillable below) have no HP and only Repel.

**Noise.** 0-100 per Link, decay 5/s. A monster hears a source when Noise × (1 − distance ÷ hearing radius) exceeds its threshold, and goes to the loudest source, not the nearest.

| Source | Noise | Source | Noise |
|---|---|---|---|
| Walk / sprint | +1/s / +3/s | Snubby / Doorknocker | +40 / +55 |
| Chain dragging | +2/s, both Links | Honker / Longboy | +80 / +60 |
| Speak / shout | +4/s / +12/s | Explosive / Air Horn | +70 at 60 m / 100 at 100 m |
| Ragdoll scream / door slam | +8/s / +25 | Squeaky Dennis | 40 at the decoy, 20 s |
| Braced | 0, silences own segments | SHIFT! yawn / Torch shake | +12 / +6/s |

Push-to-talk is honored: sprinting with a dragging Line (+5/s) reaches every threshold without a microphone.

**Friendly fire** is full, always, at monster numbers.

**How the Line changes a fight.**
- **No kiting.** A sprinting Link who hits the 5.0 m stop ragdolls 1 s, a free hit for whatever was behind them.
- **A grabbed Link drags the Line.** Grab Footing is tested against the holders' total (standing 1, Braced 2, each airborne Link 0.5 load). Grabs over 4 m/s (Lantern, Vacancy) Jerk unbraced holders, so only Braced Footing counts; slow grabs (the Custodian) are held by standing Links.
- **Segments are hitboxes.** Shamblers hold the Line, Rustmaw chews it, carts snag it, the Auditor cuts it; a knee-height Taut segment trips a Vacancy, a head-height one denies a Lantern's leap.

### Enemy senses & states

One six-state machine with per-monster numbers; the canon state names are skins on it.

| State | Entry | Behavior | Exit |
|---|---|---|---|
| **Idle** | Default | Patrol or dormancy | Stimulus over Suspicious threshold |
| **Suspicious** | Stimulus under Hunt threshold | Walks to the source; the tell plays (light dims, servo whines, piano fades) | Empty → Search; louder → Hunt; 8 s quiet → Idle |
| **Search** | Lost target | Sweeps 10 m for 15 s; hearing ×1.5 | Stimulus → Hunt; timer → Idle |
| **Hunt** | Seen, or Noise over Hunt threshold | Full speed to last known position, refreshed by any sight or sound | 6 s quiet → Search; in reach → Attack |
| **Attack** | In reach | Grab, pounce, bite, cut | Resolved → Hunt; stun → frozen; repel → Retreat |
| **Retreat** | Repel, or 20 s of combat (Vacancy) | Full speed to nearest hide point; immune to Distract | Timer → Idle |

**Perception.** Sight: 110° cone, range per monster, full range only on a lit Link; in darkness a Link is seen at 5 m, a Torch beam at 60 m, a flare at 120 m. Touching a Link or the Line is an instant Hunt. Memory 6 s, then Search follows chain drag.

**Proximity voice** is positional Noise at the speaker's Link (+4/s speaking, +12/s shouting); corpse-voice is 0. Monsters parse loudness, not words. The only non-positional voice is a Darling's.

### Level monsters

#### The Custodian (Level 1)
- **Profile:** 3 m, in the drop ceiling and wall cavities; a bruise-colored stain through drywall, once per Shift a face. Blind; hearing 40 m, thresholds 40 (Listening: the fluorescent over the loudest Link dims a semitone) and 60 (Stalking: through walls at 6 m/s to within 15 m). Grab: a Link within 8 m still for 3 s is lifted through a tile over 4 s at grab Footing 3. Permanent Staff.
- **Chain:** the lift is slow, so standing Footing counts: two standing plus one Braced (4) beats 3. Lose and the Link is executed above the tiles and dropped back as Deadweight.
- **Items / counterplay:** Torch on the stain 2 s repels 20 s; an explosive within 2 m repels 30 s, then its Noise restarts Stalking; Squeaky Dennis distracts 20 s. Walk, Brace, never shoot.
- **Scare role:** the Photocopier; the freight-shaft ankle grab.

#### Pappy Pepperoni (Level 2)
- **Profile:** 2.6 m mustachioed chef animatronic, pepperoni eyes, human teeth. Sees light within 25 m, hears door slams within 30 m, smells gunpowder (any shot on his floor skips his next timer). Moves only unseen by Link or camera, one node per Step on an 11-node graph (14 s minus 1 s per Link beyond two, minimum 8 s). Shutter node closed: three bangs (Noise 100), back to Stage; open: he grab-kills the nearest Link within 6 m. Permanent Staff.
- **Chain:** the Desk Jockey leash (5 m × (Links − 1)) and the shutter pulley (Line hooked, two Links in Bite) make the Line the door; a Link who lets Bite drop opens the shutter he is behind.
- **Items / counterplay:** Torch freezes 1.5 s (8 s cooldown); explosives and the Ladle shove him one node back; Air Horn stuns 2 s but skips his timer. Lights off, camera on him, freezer.
- **Scare role:** the Birthday Song; the doorway that was empty last look.

#### The Lanterns (Level 3)
- **Profile:** 2.2 m night hunters, dim orange eyes, 250 HP. Sight 60 m on a lit Link; hearing 30 m, threshold 30. A sighting is a 3 s scream; every Lantern within 100 m converges in 15 s. Hunt at 8 m/s, 6 m leap, 4 m/s wall climb; a pounce Downs an unbraced Link (Braced takes 30 and holds), then grab-and-run for the nearest edge at 6 m/s. Pack = 1 + floor(Links ÷ 2) on night one, plus one each night after.
- **Chain:** the grab-run Jerks standing holders; only two Bracing Links stop it. The Link who out-sprints the Line into open roof is the one taken.
- **Items / counterplay:** Popflare blinds 4 s and UV repels; Torch under 5 m blinds 2 s; Doorknocker three shells; a Gum Bomb on a running Lantern kills it and frees the carried Link. Go dark before the 150 s day ends.
- **Scare role:** the Water Tower; the Pack Run (night three, 120 s, pack 12 m behind).

#### The Darlings (Level 4)
Full rules in The Succubi. Count per floor = ceil(Links ÷ 2).

#### The Auditor (Level 5)
- **Profile:** 4 m, hi-vis vest, clipboard, shears, 800 HP. Sight 40 m, no hearing; it targets any segment with over 1 m of Give (two Links closer than 4 m). No Idle, no Retreat: Hunt at 3 m/s, always, toward the slackest segment; Attack is a 1.2 s shear close; stunned 3 s per 100 damage.
- **Chain:** the only thing that cuts the Line. A cut Link is Loose: 60 s to hold interact 2 s within 1 m of any Link; at 60 s it takes them and the body is gone, no Deadweight, no Jumper Cables. Slack Jack and the Cinch are lethal here.
- **Items / counterplay:** any gun stuns per 100 (the Honker's 400 is 12 s); Spare Nut re-couples in 3 s; Anchor Spike guarantees Bite on both of one Link's segments. Never bunch at a door.
- **Scare role:** the Roll Call cut; the first time it stops to write your name.

#### Level roamers
Rollers (L1, 8 m/s, no HP) move only unwatched; impact ragdolls 2 s and Jerks the Line, so the Tail walks backward. Carpet Mouths (L1, 50 HP) hold an ankle at Footing 4. Tiny Tomato (L2, 7 m/s, 40 HP) drops on a face for 15 and 3 s blind. Big Dough (L2, 1.5 m/s, 400 HP) ignores guns and breaks doors in 6 s; Party Popper stuns him 5 s. Shamblers (L3, 1.2 m/s, 150 HP) hold the Line itself at Footing 1 each, three per segment stopping the team until a Hoist lifts it clear. Bloats (L3, 60 HP) burst at 2 m for 50 in 4 m; shoot from 10 m. Bellhops (L4, 7 m/s, no HP, cart 100 HP) answer marble ring within 20 m and drag a snagged Taut segment toward the atrium at 2 m/s; stay on carpet. Room Service (L4) is 30% a Rare item, 70% a 60 HP hand for 40.

### Roaming threats

#### The Coworker (all levels)
- **Profile:** a seventh Link in a random player's model, hat and chain skin, no Deez on its cuff, 5.0 m behind the Tail. It closes at 2 m/s only while unobserved and grab-kills at 1.5 m. Torch on the bare cuff: it flees at 10 m/s for 60 s. Permanent Staff.
- **Chain / counters:** it speaks a 2-second-old copy of a teammate's words from its own position; in a Conga it stands where the next Link should be, and Roll Call counts it. Mirror Shard shows it behind you; a Spare Nut bolted onto it chains it to the Line. "Check the nut."

#### Rustmaw (all levels)
- **Profile:** 0.4 m iron-colored crawler, 30 HP; tell: grinding, orange flakes falling from the Line. Hearing 20 m, drawn to chain drag and Squeaky Dennis. Hunt at 3 m/s to the nearest dragging segment; latches and chews one physics link per second; at 10 the segment parts and one Link goes Loose. Guns do nothing while it is on the chain.
- **Chain / counters:** stomp (any Link within 1 m, 1 s), fire, or the Jerk: two Links sprint opposite ways until the Bite flicks it off, into a wall or a teammate (10 damage). The Line re-forges when the Loose Link touches another Link.

#### The Hook (all levels, outside boss rooms)
- **Profile:** every 3-6 minutes a crane hook drops from the dark, snags one random Link's cuff, lifts 10 m at 3 m/s, holds 4 s, lets go.
- **Chain / counters:** two Braced neighbors stop it at 2 m; otherwise the team hangs under one wrist for 4 s and drops, and 10 m is 70 unless the Line arrests it. 50 damage to the cable cuts it early; Anchor Spike pins the cuff and the Jerk fires on everyone else.

### The Succubi

**Name:** the Darlings; Turned, a **Vacancy**. Guests of the Velluto who never checked out.

**At distance (20-40 m):** a warm pool of light, a fully dressed woman in evening wear or staff uniform at a doorway or balcony rail, waving every 6 s, calling in a normal, worried voice: "Darling, over here, the door's jammed." Real loot sits behind her.

#### Approach phases
| Phase | Distance | Behavior | Chain |
|---|---|---|---|
| **Hail** | over 20 m | Waves, calls, does not move | Decide here |
| **Draw** | 20-8 m | Asks for one specific thing; steps to the edge of cover; moves 0.5 m closer each time no Link looks; a lounge piano fades in | Brace before anyone crosses 8 m |
| **Reach** | 8-3 m | Extends a hand, says the nearest Link's name, asks them to come alone | That Link's Bite drops to **2.0 m** (the Leash); one Bracing teammate stops them |
| **Turn** | under 3 m, touch, or 2 s of Torch on her face | Transformation | Isolation Rule |

**Isolation Rule:** she Turns only on a Link at least 4 m from every other Link; two arriving together get a polite, backing-away smile.

#### Tells
1. **Wrong reflection:** mirrors, windows and puddles show her 0.5 s late, 1.5 m closer, always standing; chrome shows nothing.
2. **Flickering shadow:** 3 Hz (photosensitivity toggle: steady), pointing at the nearest Link whatever the light.
3. **Glitching audio:** a 40 ms stutter every 6 s, one clipped word per sentence, no room reverb; teammates' voice gains 200 ms of reverb within 10 m of her.
4. **Non-positional voice:** teammates hear her from their own Link's position.
5. No footsteps, no footprints in dust, dry clothes on wet carpet.
6. The light nearest her is 3200 K; every other light is 4000 K.
7. She blinks in sync with whichever Link she watches, and rotates three lines without answering a question.
8. The clock behind her is stopped at 3:11.

#### Transformation (0.8 s)
0.00-0.25 s: the smile holds while the body stretches to 2.8 m. 0.25-0.55 s: joints bend backward; arms reach the floor. 0.55-0.80 s: the face changes last, folding inward like wet paper. Audio: a tape reel rewinding; the piano stops mid-bar. At 0.80 s the lights die and every Link within 10 m takes Flinch-lock. 3× damage during the 0.8 s.

#### Combat (Vacancy)
- 300 HP, 7 m/s, 5 m lunge. Grabs one Link (20 damage/s, grab Footing 3) and drags toward the nearest edge at 6 m/s; the drag Jerks standing holders; a Bracing team holds her at the 5.0 m stop until staggered.
- **The Line against you and for you:** the Leash isolates; the drag pulls everyone toward the atrium drop; in a Huddle she walks the grabbed Link around a pillar so the Line pins their neighbors. A knee-height Taut segment trips her 4 s; a Braced Link ends the Reach; the Cinch yanks a grabbed Link out of her hand.
- **Items and counters:** Torch stagger 1 s (8 s cooldown); Popflare light repels 10 s; Mirror Shard stuns 2 s; salt 2×; Doorknocker two shells (two tells spotted, shoot from 10 m); Squeaky Dennis at 15 m holds her in Draw 20 s. After 20 s she retreats to the nearest dark doorway and rebuilds 60 m higher with a new face; killing her as a Darling (120 HP) wakes every Darling on the floor.

**Variants.** *The Guest:* evening wear, balcony rail; the Reach stands over a 10 m drop. *The Staff:* uniform, service corridor; she asks you to hold a door, and it closes on the segment behind you at Footing 2. *The Returning Guest* (Exit Interview, slice four): she calls by the name of a Link who died this Shift, in that player's last words.

### Bosses

#### Mama Crust (Level 2, the stage shaft)
- **Arena and phases:** a 40 m shaft, catwalk rings at 8, 16 and 24 m, her 4.5 m frame bolted into the rigging between them; the exit catwalk at 32 m is reached up her arm. Phase 1 (600-400 HP): arms sweep the catwalks every 7 s (4 m knockback, which is a fall, which is a Jerk); eye lamps blind first person 1 s. Phase 2 (400-200): sweeps every 5 s; a Tiny Tomato every 20 s. Phase 3 (under 200): lights zero; she tracks by Noise (hearing 40 m, threshold 30).
- **Chain mechanic:** fuse boxes on three catwalks pulled within 2 s of each other, count = min(Links, 3); catwalks are 8 m apart, so a Conga spans them with two Links hanging in Bite while three pull; the Ballast is thrown onto a lever. Each pull drops a phase and opens the 3 s damage window; boxes re-arm after 20 s.
- **Items / fail / reward:** the Honker is 400 in one window; its recoil puts the shooter off the catwalk, so Anchor Spike first. Every Link on one catwalk is a Layoff on the next sweep. 300 Washers; the roof.

#### Madame Velluto (Level 4, the rooftop ballroom)
- **Arena and Phase 1, the Reception (600-300 HP):** a 40 m round ballroom, twelve pillars in a ring, twelve mirrors between them, a 3-ton chandelier on a 12 m chain under the dome hatch. Twelve copies; the real one's reflection moves 0.5 s late. A shot false one shatters and rings a Bellhop. Shooting the real one stuns her 6 s, during which she takes the nearest Link's hand and waltzes at 4 m/s, winding the Line around pillars; on three pillars she cannot let go and takes damage. Untangle, Braced Links releasing in order, before the waltzed segment hits 5.0 m against a Footing 99 pillar wrap and tears the cuff: that Link is Dead.
- **Phase 2, the Last Dance (under 300):** she drops the hostess form (a 3 m shape, candles only), sweeps every 5 s (30 damage, ragdoll), and her first sweep drops the chandelier chain to 2 m off the floor. The Line climbs it 12 m; three or more Links hitting Bite on one beat ram the chandelier into her for 150. She climbs after the Tail at 2 m/s; a Jerk from the top knocks her off.
- **Items / fail / reward:** Mirror Shard shows the real one at 40 m; salt 2×; a Gum Bomb on a pillar wrap frees the Line and takes 20 from everyone on it. 300 Washers; the rooftop pool.

#### The Chairman (Level 5, the final shaft)
- **Arena and behavior:** the last 90 m of the Stack, Door 1 at the top, 120 s. A 12 m knot of every previous team's chains, cuffs and Deez Nuts climbs behind the team at 3.5 m/s; no HP, the clock is the fight. Every 6 s its 20 m chain-whip sweeps the shaft (30 damage, ragdoll; Braced Links hold). Every 10 s it throws a chain that cuffs onto the nearest segment and reels at 1.5 m/s; cut by any gun in 2 s, any explosive, or a Goat.
- **Chain mechanic:** a reeled segment pulls the team back down; two Braced Links hold it at the stop while a third cuts. Door 1 opens only when every living Link is in Bite in the same direction for 5 s; solo, the Ballast is dropped down the counterweight shaft to make the pull.
- **Items / fail / reward:** the Honker's 400 into the lead knot stalls it 3 s, once; the Cinch is 10 s in which nothing can be reeled. At 0 m it grab-kills from the Tail up: Layoff. 300 Washers, 300 for the exit, Shift Complete, every Deez off and bouncing.

### Quick-reference table

| Enemy | Level | Speed | Kill / stun methods | Signature scare |
|---|---|---|---|---|
| The Custodian | 1 | 6 m/s in walls | Unkillable; Torch 2 s → 20 s; explosive → 30 s | The Photocopier |
| Rollers | 1 | 8 m/s | Gum Bomb; Anchor Spike | A chair that was not there |
| Carpet Mouths | 1 | 0 | 50 damage; fire | The held ankle |
| Pappy Pepperoni | 2 | 1 node per Step | Unkillable; Torch 1.5 s; explosives push 1 node | The Birthday Song |
| Tiny Tomato | 2 | 7 m/s | 40 HP; stomp | The vent above the Tail |
| Big Dough | 2 | 1.5 m/s | 400 HP, fire and explosives; Party Popper 5 s | The door that lasts 6 s |
| Mama Crust | 2 (boss) | Sweep every 7 s | 600 HP in 3 s windows after fuse pulls | Phase 3 blackout |
| The Lanterns | 3 | 8 m/s, 6 m leap | 250 HP; flare 4 s, Torch 2 s; UV repels | The Water Tower |
| Shamblers | 3 | 1.2 m/s | 150 HP; Ladle 8 m | Three hands on one segment |
| Bloats | 3 | 0.8 m/s | 60 HP; shoot from 10 m | A burst inside a Huddle |
| Darlings / Vacancy | 4, 5 | 7 m/s, 5 m lunge | 120 / 300 HP; Torch 1 s, Mirror Shard 2 s, flare 10 s | The Turn; Suite 909 |
| Bellhops | 4 | 7 m/s | Unkillable; cart 100 HP; Anchor Spike | The marble ring |
| Room Service | 4 | 0 | Hand 60 HP | The lid |
| Madame Velluto | 4 (boss) | 4 m/s waltz | 600 HP; stun 6 s per hit; chandelier 150 | The twelve mirrors |
| The Auditor | 5 | 3 m/s | 800 HP; stun 3 s per 100 | Roll Call |
| The Chairman | 5 (boss) | 3.5 m/s climb | Unkillable; Honker stalls 3 s once | The first whip |
| The Coworker | All | Team speed | Unkillable; Torch on bare cuff → flees 60 s | "Check the nut" |
| Rustmaw | All | 3 m/s | 30 HP; stomp, fire, the Jerk | Orange flakes on the Line |
| The Hook | All | 3 m/s lift | 50 damage to the cable; two Braced stop it | No tell at all |

---

## 6. Horror Director, Jump Scares & Audio

### Scare philosophy

The game is funny because it is scary. The scare lands at full force; the comedy is what the Line did during it. Every scare has three beats:

| Beat | Window | What happens |
|---|---|---|
| **Scream** | 0-1.5 s | Flinch-lock, 0.4 s camera flinch toward the source, lights or music cut, the Jerk the panic causes. The game says nothing. |
| **Laugh** | 1.5-10 s | Physics resolves: ragdolls, the Scream Chord, the JERK label, hats rolling, the Foreman filing the Incident. |
| **Reset** | 10-45 s | Group Tension decays to its floor, ambience returns, nothing happens. |

Rules that keep the monsters sharp:

- No monster has a comedy animation, line or idle. A monster being laughed at is a bug.
- The Foreman speaks no earlier than 1.5 s after a trigger, and only in Incident format.
- Lethality never scales down for comedy: a ragdolling Link is still grabbable, Noisy and a load.
- A procedural scare seen 3 times by the same team is retired from their pool for 5 Shifts. Scripted scares never retire.
- Fake-outs use the same cues as real scares, so no cue is ever safe.

### The Director

Server-side, ticks once per second.

**Group Tension (0-100), shared.** +1/s while no Link is lit, +2/s while any monster is Stalking or a Darling is in Draw, +3/s while any segment is in Bite, +10 per Jerk, +0.5/s per Downed Link. Decays 2/s during Reset. Floor 20 in levels 1-4, 40 in The Exit Interview.

**Dread (0-100), per Link.** +1/s while more than 4 m from every other Link, +2/s holding a lit torch, +0.5/s with Noise under 10, +15 when a teammate is grabbed within 10 m, +25 on being the Flinch-lock target. Decays 1/s; freezes while Downed or Dead.

**Budget** of Director-fired scares (procedural, audio-only, peripheral, environmental, fake-out), on top of scripted scares and monster behavior:

| Level | Per 10 min | Global cooldown | Per-Link cooldown | Fake-out ratio |
|---|---|---|---|---|
| The Yellow Rooms | 3 | 60 s | 150 s | 1 in 3 |
| Pappy Pepperoni's Night Shift | 4 | 45 s | 120 s | 1 in 4 |
| Carrow Heights | 2 by day, 0 by night | 60 s | 120 s | 1 in 3 |
| Hotel Velluto | 4 | 45 s | 120 s | 1 in 2 |
| The Exit Interview | 6 | 30 s | 90 s | 1 in 5 |

A scare needs Group Tension 35+ and the global cooldown elapsed; it fires immediately at Tension 70+, otherwise at 10%/s. A scripted scare or grab-kill sets the global cooldown to 90 s. Nothing fires within 20 m of a monster already Stalking or in Draw.

**Targeting.** Each living Link scores +4 if more than 4 m from every other Link (the wanderer), +3 if lowest Dread (the calm one), +2 holding a lit torch, +2 as the Tail in a Conga, +2 as lowest Wellbeing in a Huddle, −5 if targeted by either of the last two scares. Highest score wins; ties go to lower Wellbeing. Solo, the Ballast is the target 20% of the time: it has rolled away, or turned to face the wall.

**Payoff debt.** Each fake-out adds 1; at 2 the next scare is real, involves a monster and ignores the global cooldown; any real scare resets it to 0.

**Unpredictability.** Each Shift rolls a 64-bit seed. Each level has a pool of 24 procedural scares; the seed draws 10, ordered. A Layoff rerolls the draw. Each level also rolls one of six mutators, posted on the Break Room notice board: **Longer Shift** (Rearrange every 60 s, Step −2 s, night +30 s, Darlings +1 per floor), **Earplugs** (monster hearing −30%, sight +30%), **Open Office** (Break Room doors seal in 4 s), **Understaffed** (vending Legendary 10%, sausage 10%), **Night Audit** (scares target the Link carrying the most items), **Dennis Everywhere** (Dennis appears three times per level instead of once).

### Scare taxonomy

| Type | Rule | Example A | Example B |
|---|---|---|---|
| **Scripted** | One per level, fixed place, always fires; canon targeting. | The Photocopier (L1). | Suite 909 (L4). |
| **Procedural** | Seeded pool; built from a real monster's cue. | *Tile Drop*: a tile falls 0.5 m ahead of the target while Custodian dust tracks toward the Line and stops at 8 m. | *Cart Return*: a Bellhop cart rolls out behind the Tail at 7 m/s and stops 1 m short. The next one does not. |
| **Audio-only** | Nothing spawns; binaural, within 3 m, 1.5 s or less. | *Hold Music*: the target's cuff plays 4 s of hold music, then a dial tone. | *The Dog*: the one dog in Carrow Heights stops; one bark 2 m behind the lowest Link. |
| **Peripheral** | Outer 25° of the FOV; gone when looked at; never within 10 m. | Dennis at a window three floors up, facing in. | A Darling's silhouette at a rail that is a coat stand under the torch. |
| **Environmental** | The building acts; costs something physical. | The tube over the Tail bursts; the glass is a 2 m Grease patch. | The counter bell rings; exit signs die 2 s; a shutter nobody closed is closed. |
| **Monster reveal** | Real, in reach; lethal pressure follows. | The Custodian's once-per-Shift face above the calm one. | Pappy filling an open Shutter node. |
| **Fake-out** | Same cue, no payoff; builds debt. | A hanging jacket the torch resolves as a jacket. | A copier that prints one blank page. |
| **Item-triggered** | The team did this; "workplace injury." | Big Red Button rolling the Birthday Song in a lit room. | Squeaky Dennis squeaking in a pocket on ragdoll, 12 m from a Listening Custodian. |
| **Teammate-triggered** | A Jerk, torch or Hoist at the wrong moment; "Jerk: Link N." | A Jerk fires as a Link peers through a door, staggering them 1.5 s and through the doorway. | A neighbor's torch crosses a Darling's face for 2 s and Turns her. |
| **Post-death** | For spectators and the Deadweight's dragger. | A Dead Link hears breathing from their own corpse, 10% volume, lowpassed. | 1 in 8 Corpse Commutes, the Deadweight's hand closes on the dragger's ankle 1 s (Footing 4, no damage). |

### Audio design

**Proximity voice.** Full level to 8 m, linear falloff to silence at 25 m. Occlusion: −12 dB and a 2 kHz lowpass per wall; two walls is silence. The Line conducts: a Link's voice reaches each adjacent Link at −6 dB through the cuff, walls or not, so a Conga whispers down the Line but not across a Huddle. **Company Handset** (Common tool): a two-piece walkie; holders hear each other at any range, unoccluded, with a 0.4 s squelch tail at Noise +8 on both ends. Monsters hear the receiving end.

**Voice is Noise.** Mic input above −30 dBFS is speaking (+4/s), above −12 dBFS shouting (+12/s). Push-to-talk is honored; mic off, Noise comes from movement and the Scream Pack supplies the screams.

**Distant whispers.** Every 90-180 s, 30-50 m out, one of 60 lines in the Foreman's voice at 70% speed ("...the nut...", "...clock in...", a Link's name). 70% come from the nearest monster's direction ±30°, 30% from anywhere. In Hotel Velluto, 1 in 5 whispers is a teammate's line 2 s late, 10% volume, 15 m behind the Tail: the Coworker's cue.

**Binaural cues.** Every monster source is HRTF-rendered, behind walls at its occluded level. The Darling's non-positional voice is the one exception.

**Music states.** *Hush* (ambience only), *Listening* (one sustained tone), *Stalking* (pulse 60 BPM rising to 120 over 20 s), *Event* (3 s stinger, then nothing), *Aftermath* (level theme at half speed, 20 s). Transitions follow monster state, never player state.

**Silence.** The Director may call a *Drop*: ambience −20 dB over 3 s, held 6-15 s. 40% of real scares follow a Drop; 30% of Drops resolve to nothing.

**Signature sounds.** Custodian: fluorescent semitone drop, tile creak. Pappy: rising servo whine, jukebox stop. Lanterns: the 3 s scream. Darlings: tape reel rewinding. Rustmaw: grinding, flakes. The Hook: cable whine, 2 s before contact. The Auditor: shears clicking each step. The Chairman: ten thousand chains. The Coworker: a teammate, 2 s late. Nothing is shared or remixed.

**The chain rattle.** Noise is read per segment: dragging +2/s, Bite creak audible to monsters at 15 m, Jerk clang +15 one-shot at 30 m, marble summons a Bellhop within 20 m. Monsters path to the loudest segment, not the loudest Link: a silent Link beside a dragging segment gets found. Brace zeroes that segment. Line skins change the sound, never the Noise.

### Camera and scares

First person (90° FOV) delivers face scares: 30% of Director scares spawn just outside the FOV so the 0.4 s flinch brings them in. Third person sees the Line, so the Director moves the source into the 60° cone behind the camera, or puts the scare on the Line itself: a segment pulled taut at 1,600 N for 0.5 s by something unseen, then released. Scripted scares and face-grabs Flinch-lock to first person 1.2 s; ragdoll, Downed, transformation and airtime over 1 s force third, then restore. V toggles any time (0.25 s blend), but a toggle within 0.5 s of a scare trigger is deferred until Flinch-lock ends: no scare is dodged by switching.

### Comedy systems

**Ragdoll rules.** Over 9 m/s off your feet ragdolls until under 4 m/s; a sprinter at the stop ragdolls 1 s; a Jerked Link staggers 1.5 s. Ragdolls have Footing 0 and collide with the Line, hats and each other; three or more Links within 1 m is a Pile, one Incident. Ragdoll never adds damage beyond the fall table.

**Chain chaos.** The Director relies on these and never touches them: the Scream Chord, the Corpse Commute, the Pinch, the Trunk Jerk, the six-body Grease slide, a Hoist that over-pulls into a Pile.

**Scream mechanics.** With the mic on: a peak above −12 dBFS within 0.3 s of a scare lengthens that Link's flinch to 0.6 s and gives a 25% chance of a *Fumble* (held item dropped). A shout held over 1.5 s opens the character's mouth, shakes the camera 2° and counts as shouting Noise. In a ragdoll the louder of mic and Scream Pack is pitch-scaled with velocity and joins the Scream Chord.

**Post-wipe replay.** On a Layoff, an 8 s replay (6 s before the fatal event, 2 s after) from a camera 4 m behind the last logged Jerk culprit, JERK label frozen on. The laminated Incident Report lists cause of Separation, the Jerk, peak fall velocity and the Scream Chord's key. Skippable by majority vote.

### Accessibility & safety

- **Scare Intensity:** *Standard*; *Reduced* (scare audio peaks −6 dB, Flinch-lock keeps the hold but drops the camera snap); *Minimum* (Director budget 50%, no face-grab framing, no Drops). Monsters stay lethal in all three.
- **Flash safety:** no strobe above 3 Hz. The photosensitivity toggle turns every flicker into a smooth ramp: fluorescent dim, the Darling's shadow (static, still pointing wrong), Mama Crust's lamps (fade, still blinding), muzzle flash (camera kick, no white frame).
- **Mute and kick:** per-Link voice mute (their Noise still counts); host kick; vote-kick at 3+ Links. A kicked Link becomes Deadweight.
- **Content toggles:** six-bus mixer (voice, monsters, Foreman, Line, music, scares), monster-cue subtitles on the badge ("Servo whine, behind, 20 m"), hide Deadweight faces, whisper bed off, Tension HUD (off by default).
- **Not toggleable:** the Line and its physics, friendly fire, monster lethality, the existence of jump scares, Jerk logging, Roll Call being wrong, Noise from movement, the Coworker's tell, the Sump, the Incident counter.

---

## 7. Multiplayer & Chain Physics

### Chain simulation

The Line is a hybrid rope: a position-based-dynamics chain for shape, wrap and collision, plus one distance constraint between the two cuffs for the hard stop, on the host's 60 Hz fixed tick at 8 substeps and 4 iterations. A segment is **24 physics links** (0.5 kg capsules, radius 0.03 m, 12 kg per segment) ball-jointed to each cuff. Links are 80 kg, the Ballast 35 kg. Rest length L is 5.0 m, 3.0 m for a Pair, 4.0 m for the Ballast, 6.0 m for a Trunk. **Give** is 0-80% of L, the **Bite** 80-100%, the stop at L (4.0 / 5.0 m by default), measured along the rope path, so a wrapped segment Bites early and the stop re-anchors at the snag.

Give applies no force. The Bite is a spring on both cuffs, 0 N at 80% of L to **1,600 N** at L, damped 200 N·s/m. At the stop the constraint is rigid and **Footing** decides who moves: airborne 0, Downed 0.3, standing 1, on ladder 1.5, Braced 2, ledge-hanging 1 (6 s grip), Anchor-Spiked 99; the Ballast is 0.5 resting, 99 Spiked. Every Link off the ground is **0.5 load** (the Ballast 0.25). The host sums Footing on each side of a segment at the stop; the lower side moves, a tie moves both at half speed. A ring sums both routes round the loop, so the Huddle catches falls and a Trunk does not.

A **Jerk** fires when a segment reaches L at 4 m/s or more of relative cuff speed: the caught Link staggers 1.5 s (no damage), a sprinting Link who hits the stop ragdolls 1 s, and the Link moving faster into the stop wears the JERK label 10 s.

The rope collides with world geometry, doors, railings, pillars, props over 5 kg and monsters, not with Link capsules or other segments, so it never knots. A segment bent over 60° round an edge for 1 s is **Snagged** and frees when either end walks back 1 m or the far end Tugs. Rope sliding on floor is Noise +2/s to both ends. The Line never breaks; only the Auditor's shears, Rustmaw at 10 chewed links, 4 s of Goat nibbling and Madame Velluto's waltz at 5.0 m part a segment, setting a Link Loose.

### Configurations by player count

Formation is a 15 s lobby vote among shapes legal for the count, majority wins, default on a tie; the host may force any legal shape in the lobby or at a Break Room. Shapes re-form only on a seal.

| Links | Default | Segments | Climbing notes |
|---|---|---|---|
| 1 | Ballast | 1 × 4 m | 35 kg, thrown 6 m, Spiked for Footing 99; counts as a Link for Break Rooms, levers and Door 1; unspiked, it follows you off any edge |
| 2 | Buddy System | 1 × 3 m | Fits a Safe Ring, pins one Rearrange door; 2.4 m of Give, every jump Bites |
| 3 | The Conga | 2 × 5 m | 10 m of reach for Chain-lining, pins three doors; both ends are Tails |
| 4 | The Huddle | 4 × 5 m | No Tail, a fall splits across two neighbors; folds in every doorway. Option: two Pairs on a 6 m Trunk, whose Links Jerk most |
| 5 | The Conga | 4 × 5 m | Middle Link is the pivot; two Tails and 20 m of Line across every gap |
| 6 | The Huddle | 6 × 5 m | Two Brace while four climb; 30 m of rope is Noise, no lift cage fits. Option: three 3 m Pairs on a 6 m Trunk ring |

**Drop-in:** the joiner spawns in the last Break Room on a new 5 m segment to the nearest Link's Deez as a dangling Tail. The segment starts in **Catch-Up**: no stop and no Bite for 30 s or until it first drops under 4 m; meanwhile the joiner is hunted as Loose (2× aggression). **Drop-out:** the leaver is Deadweight where they stood until the next seal; a disconnect holds the slot 60 s and a reconnect re-enters the same body. The sole living Link leaving is a Layoff.

### Movement with the chain

| Input | Action |
|---|---|
| WASD / Shift / Space | Walk 4 m/s, sprint 7 m/s, jump 1.2 m up, 3.5 m across at sprint |
| Hold Ctrl (crouch) | Brace: 0.2 s wind-up, Footing 2, cannot move |
| Hold E at a segment in Bite | Hoist: reel the far end 0.75 m/s per Hoisting Link |
| Tap E at a segment in Bite | Tug: 0.5 m at 6 m/s; flicks Rustmaw, frees a Pinch, pulls an ankle from a Carpet Mouth |
| F / V / Q / G / T | Flashlight / camera / swap hand / drop / push-to-talk |

**Climb:** ladders are Footing 1.5 and hold 3 Links; cables are hand-over-hand at 1 m/s, Footing 1. **Mantle:** ledges to 1.4 m are automatic in 0.6 s; 1.4-2.2 m is a ledge-hang then a 1.0 s pull-up plus 1.0 s per 0.5 load on your own segments. **Swing:** a dangler pumps W/S, 1.5 m per pump to 6 m (the Pendulum). **Pulling a teammate up:** Brace, then Hoist; a standing Link out-Footings one dangler, two need a Braced Hoister, two Hoisters reel 1.5 m/s. **The human rope-bridge** is Chain-lining: a Braced Link each side at full Bite, middle Links hand-over-hand along the taut segments at 1 m/s; either anchor Jerking drops everyone. **Stamina:** 100; sprint −10/s, Brace −2/s, Hoist −8/s; regen 15/s after 1 s idle; at 0 no sprint, a Brace collapses to Footing 1, a Hoist stops.

### Falling and dragging

Fall damage by vertical drop: under 4 m none; 4-8 m 30; 8-14 m 70; over 14 m Downed; over 20 m or the Sump, Dead. A fall is **arrested** only if the holding side's Footing beats the load, and then deals no damage, only the Jerk stagger. One standing Link holds two danglers, a Braced Link four; five danglers pull anyone off anything. If the holders lose, the whole side falls and each Link takes damage by their own drop. Landing on a teammate halves your damage and deals them 20. Any Link over 9 m/s off their feet ragdolls until under 4 m/s. In the Sump's kill plane a Link has 8 s.

**Dangling rescue:** the dangler stops pumping, the holders Brace, one Hoists. A 5 m reel takes 7 s, so a holder who is themself ledge-hanging (6 s grip) needs a second Hoister or loses the ledge with everyone on it. A **Downed** Link is luggage: Footing 0.3, dragged whenever their segment hits the stop, −30% team speed. **Deadweight** is 80 kg at Footing 0, dragged face-first up every staircase; 50%+ Deadweight is Overloaded (−40%).

### Downed, death, revive and checkpoints

Wellbeing 100, no regen. At 0 (not from the Sump or a grab-kill): Downed, crawl 1 m/s, 45 s bleed-out; a standing Link within 2 m holds E 4 s to revive at 40; solo, Downed is a Layoff unless a First-Aid Kit self-revives after 5 s, once per Break Room. Dead is Deadweight until the next seal (revive at 50) or Jumper Cables (25). A **Layoff** (every Link Dead, or every living Link Downed) respawns the team sealed in the last Break Room at full Wellbeing, formation reformed: Pocket kept, hand items lost (they lie where you died for the Shift), Washers since the seal at 50%, monsters to patrol, scares rerolled. A seal needs every living Link and every Deadweight inside and one Link on the clock 2 s: Deadweight revives at 50, everyone heals to 100, progress saves.

### Camera

V toggles first and third person any time, 0.25 s blend, per player. First person: 90° FOV, the Bite shown as the cuff tugging the screen edge toward the segment. Third person: 80° FOV, 2.2 m behind, 0.4 m over the right shoulder on a spring arm with a 0.3 m sweep sphere, the whole Line visible. Segment colors (green Give, amber Bite, red stop) show in both modes. Scripted scares and face-grabs force first person 1.2 s (Flinch-lock); ragdoll, Downed, transformations and airtime over 1 s force third person, then restore; every scare flinches the camera 0.4 s toward its source. **Six bodies in a hole:** a spring arm under 0.8 m for 1 s with three or more Links within 2 m blends 0.5 s to **Pile Cam**, 4 m above the pile's centroid looking down 65°, returning 1 s after either clears.

### Netcode

**Authority:** a listen server on the host Link's machine, headless-capable from month 1 for dedicated servers later. The host simulates the Line, Footing, monsters, the scare director, doors, power, Noise, Wellbeing, loot and props over 5 kg, and alone attributes Jerks, by one reliable RPC. Clients own input, camera and voice and predict their own movement, jump, Brace and item use.

**Chain sync:** the host replicates 5 control points per segment (every 6th link, 3 × 16-bit at 2 cm) plus a 2-bit state (Give / Bite / Stop / Pinched) at 20 Hz. Each client runs a local PBD rope between the cuffs pulled toward those points. The host's Bite force is authoritative, but the client pre-applies the same spring from the last points and the neighbor's interpolated position, so the tug lands the tick the player sprints; corrections over 0.25 m smooth over 100 ms. An unpredicted host Jerk staggers on receipt; a predicted Jerk the host rejects is cancelled, so a false stagger never exceeds 150 ms.

**Rates:** host physics 60 Hz; Links 30 Hz; chain points and ragdoll bones 20 Hz; monsters 20 Hz in view, 5 Hz out; 100 ms interpolation buffer. **Bandwidth:** 40 kbps down, 8 kbps up per client at six Links, hard cap 64 kbps, voice separate. **Latency:** 80 ms round trip target; at 150-250 ms the predicted tug halves to hide corrections; public lobbies refuse joins over 200 ms.

**Host migration:** the lowest-ping client is the **Understudy**, snapshotted every 5 s and at every seal. On host loss: 3 s freeze, "Incident: supervisor separated. Deputy assigned.", then play resumes on the Understudy at most 5 s rewound, velocities zeroed; monsters within 10 m of a Link return to patrol start; a boss keeps its HP and restarts its phase at the arena entry. If the Understudy also drops, the lobby reloads at the last Break Room.

**Cheating stance:** cosmetic-only unlocks and host authority, so no kernel anti-cheat. The host validates speed (18 m/s cap outside the Hurry), item ownership, Wellbeing writes and Washer grants, kicking after three failed checks in 60 s. Public lobbies need a matching build hash; modded builds play friends-only.

### Lobby & sessions

The lobby is the punch-clock wall; punching in is readying. Sessions are **Public**, **Friends-only** or **Invite-only** (6-character code), 1-6 Links. **Join-in-progress** follows the drop-in rule; joins are refused during a boss, a scripted scare's 10 s window and the Exit Interview's sixth slice. **Kick:** by the host, or a majority of the other living Links in a 20 s vote; the target is then immune 10 min. A kicked Link is Deadweight until the next seal. **AFK:** 90 s without input drops a Link to Footing 0.3 and luggage speed; 300 s prompts a kick.

### Voice

EOS Voice, Opus 24 kbps per speaker: full within 8 m, logarithmic to −24 dB at 25 m, silent at 30 m; occlusion traced every 100 ms, blocked −12 dB with a 1.2 kHz lowpass, a sealed Break Room door −30 dB. No global channel outside a sealed Break Room and the lobby. **Noise feed:** the client measures its own mic RMS every 100 ms and sends a 2-bit level with its inputs: silent under −40 dBFS, speaking −40 to −14 (Noise +4/s), shouting over −14 (+12/s); no audio reaches the host. **Push-to-talk (T) is the default**; open mic sits behind a −40 dBFS gate. Nothing requires a microphone: movement, chain drag and gunfire earn Noise alone, and a mic-less Link has an 8-phrase callout wheel at Noise +4 each. Downed Links speak normally; Dead Links speak from the corpse at 10%, lowpassed. The Coworker replays a 2 s in-memory ring buffer of a teammate's voice; nothing is stored.

### Edge cases

| Case | Resolution |
|---|---|
| A Link disconnects while dangling | Deadweight in place, slot held 60 s; holders' Footing re-checks that tick and the side falls if it no longer beats the load |
| Two Links fire Lift Assist Units at once | Thrusts sum (4,000 N lifts 6 masses) through 0.4 s lag: a Huddle spins 1 rev per 2 s; two units on one segment hold both at the stop as a mid-air bar; all drop at fuel end |
| Host leaves mid-boss | Understudy promotes; the boss keeps HP and restarts its phase; team at the arena entry |
| Six Links enter one Velluto lift cage | Cage holds 3; a fourth trips the overload bell and the door stays open; Links 4-6 ride below on the leash at 0.5 load each |
| A Pappy shutter closes on a segment that is not the pulley | It stops on the chain and reads Open; Pappy enters; a Tug clears the Line and the shutter drops |
| Every Link Braces at once | Nobody moves; after 10 s the Foreman logs "Team stationary. Proceed when able." and the nearest patrol paths to them |
| Two Links Hoist against each other | Forces cancel; the higher Footing side reels; a tie reels nothing and drains both stamina bars |
| A Loose Link disconnects | The 60 s timer runs on; at 0 the Auditor takes the body; the player rejoins as a drop-in at the next Break Room |
| Every living Link is Downed while one holds a First-Aid Kit | Layoff at once; the self-revive is solo-only |
| A Link joins while the Line is a Chain-line | The Catch-Up segment has no stop or Bite, so it hangs slack without loading the anchor; the joiner waits on the near roof until the crossing ends |

---

## 8. Progression, Unlockables & Cosmetics

### Currency and XP: Washers and Tenure

Two numbers live on the badge. **Washers** are spent; **Tenure** is never spent and never lost.

Washers are one pool per Shift, the same number on every badge; the Vending Machine draws 5 per pull. At clock-out (Door 1, or leaving the lobby) every Link banks the full pool to their own account: everyone on the Line is paid the same.

| Source | Washers | Rule |
|---|---|---|
| New team height | 1 per m | Split evenly; 420 m per full Stack |
| Break Room sealed | 25 | 24 per Stack |
| Unscheduled Event survived | 5 | No Separation within 10 s of it |
| First-time item pickup | 2 | Per account, per item |
| Level exit | 100 / 150 / 200 / 250 / 300 | Levels 1-5 |
| Boss | 300 | Mama Crust, Madame Velluto, the Chairman |
| Clean Shift | ×2 | A level's total at its exit, if no Layoff in it |
| Layoff | −50% | Of Washers earned since the last Break Room |

A full Stack with two Layoffs banks about 3,000; a Clean Shift about 5,500.

**Tenure** is XP: gross Washers before the Layoff deduction and the Clean Shift multiplier. A Layoff takes your pay, not your hours. Per account, banked the moment a Link leaves, it drives Pay Grades and buys nothing.

### Unlock Tracks

Bought at the Lobby's vending wall or granted by a Commendation. Every unlock renders for every Link; the point of owning a thing is that five other people have to look at it.

#### Player cosmetics
- **Outfits**: Orientation Polo (default), Employee of the Month (Dennis's shirt), Pizzeria Server, Velluto Housekeeping, Middle Management.
- **Hats** (each a 0.5 kg rigid body with its own collider; a dropped hat persists for the Shift; none changes hitbox or Noise): Traffic Cone, Hard Hat, Chef Toque, Bellhop Cap, Birthday Cake, Colander, Dennis's Visor.
- **Emotes** (all two-Link: the initiator targets a Link within one segment; solo, the Ballast is the partner): High-Five, Trust Fall (a real 1 m drop), the Conga (the whole Line joins in turn), Tug-of-War (lower Footing loses), Jump Rope (two Links swing a segment, a third skips it).
- **Scream Packs** (all pitch-scale with fall velocity and tune into the Scream Chord): Default, Opera Tenor, Slide Whistle, Kazoo, Very Calm (a level "oh no" at every velocity).
- **Deez styles** (engraving and finish on the nut, the one cosmetic the Coworker cannot copy): Galvanized (default), Gold-Plated, Chrome, Wingnut, Re-Orientation stamps I-V.
- **Ballast skins** (35 kg, same collider): Smiley (default), Wedding Edition Ball and Chain, Kettlebell, Garden Gnome.
- **Foreman Announcement Packs**: the same voice, a different manual. Standard; Holiday Party; Night Shift (identical lines, whispered). Never a different tone.

#### Line skins
A Line skin changes the chain's mesh, material and audio set only; length, mass, Bite, snag geometry and chain-drag Noise never change. The one exception is the Glow Stick Line, visible to Lanterns at 80 m: a penalty, never an advantage, and its store card says so.

| Line skin | Visual | Audio | Unlock |
|---|---|---|---|
| Standard Issue | Galvanized steel, DEEZ stamp every 12 links | Clink; floor scrape | Default |
| Glow Stick Line | Translucent chem-light segments in team color | Soft plastic knock | 900 W; seen by Lanterns at 80 m |
| Spaghetti Line | Render-only sag, sauce drip | Wet-noodle slap on every Jerk | Commendation: Al Dente |
| Caution Tape | Yellow-black tape twisted on steel | Crackle; tape squeal in Bite | 300 W |
| Velvet Rope | Red stanchion rope, brass hooks at each cuff | Hushed; brass ting on marble | 600 W |
| Sausage Links | Butcher's string | Squelch; sizzle when a Popflare burns it | Commendation: Crab Rave |
| Anchor Chain | Oversized rusted links, barnacles | Deep clank; heavy drag | 1,200 W |
| Paper Chain | Construction-paper loops | Rustle; a tearing sound at the stop (nothing tears) | 450 W |

#### Item skins
Visual and audio only; same stats, same silhouette so teammates read the item at 10 m. Snubby "Stapler"; The Honker "Office Party" (confetti muzzle flash, same Flinch); Dependable Torch "Desk Lamp"; Squeaky Dennis "Squeaky Gerald".

#### Lobby toys
Physics objects that only work with the Line attached, bought once, present in every lobby you host: Tug-of-War Mat (3 v 3, losers go into the Ball Pit); Ball Pit (Dennis is in it); The Scale (prints "6 Links, 2 Deadweight, 1 hat not yours"); Claw Machine (5 Washers for a Ballast plush that is a 0.5 kg hat). Break Room posters and vending faceplates follow the host.

#### Titles
Under the name on the badge, earned only: Probationary (default), Jerk, Load-Bearing, Independent Contractor, Deadweight, Al Dente, Shift Lead, Rehired, Dennis's Friend, Lifer.

### Commendations

Achievements, filed by the Foreman with an Incident-style number. Each pays 200 Washers, 200 Tenure and the listed item.

| Commendation | Condition | Reward |
|---|---|---|
| Who Jerked? | Logged as the Jerk 100 times | Title: Jerk; Scream Pack: Kazoo |
| Load-Bearing | While Braced, hold 4 airborne Links for 10 s | Title: Load-Bearing; Hat: Hard Hat |
| Barbershop | Trigger the Scream Chord 25 times | Scream Pack: Opera Tenor |
| The Corpse Commute | Drag Deadweight 1,000 m lifetime | Title: Deadweight; Scream Pack: Very Calm |
| Nobody Left Behind | Seal a Break Room with every hat the team entered the level with | Hat: Traffic Cone; Clause: Heavy Hats |
| Check the Nut | Flashlight the Coworker's bare cuff before 3 m, 5 times | Deez: Chrome; Clause: Wrong Count |
| Al Dente | Hold every segment of a Huddle in Bite for 30 s | Title; Line: Spaghetti Line |
| Crab Rave | Buy the crab 10 times | Line: Sausage Links |
| Return to Sender | Jerk a Rustmaw off the Line into a teammate | Item skin: Squeaky Gerald |
| Independent Contractor | Clock out at Door 1 solo | Title; Ballast: Wedding Edition Ball and Chain |
| Clean Shift | Full Stack, no Layoffs | Deez: Gold-Plated; Title: Shift Lead; Clause: Skeleton Crew |
| Dennis's Friend | Find Dennis in all five levels in one Shift | Outfit: Employee of the Month; Title |

### Shift Clauses (Mutators)

Riders on the Shift contract, set by the host in the lobby, applied to every Link. Never sold; up to 3 stack. Each sets a Washer multiplier; Tenure is unaffected. Every Clause is harder or sideways, none easier.

| Clause | Rule | Washers | Unlock |
|---|---|---|---|
| Short Leash | Segment max 3.5 m; Bite from 2.5 m | ×1.3 | Pay Grade 5 |
| Heavy Hats | Hats weigh 8 kg; a falling hat counts as a Jerk | ×1.1 | Nobody Left Behind |
| Skeleton Crew | Every second Break Room is locked | ×1.6 | Clean Shift |
| Wrong Count | Roll Call is wrong at every Break Room; the Coworker always spawns | ×1.5 | Check the Nut |
| Payday Loan | A Layoff takes 100%; no Clean Shift credit | ×2.0 | Pay Grade 30 |
| Casual Friday | No Pocket; a Layoff loses every item | ×1.2 | Re-Orientation I |

### Pay Grades and Re-Orientation

Pay Grades run 1-40 at a flat 1,500 Tenure each (60,000 total, about 18 full Shifts). Every 5 Grades the badge border changes color, white to caution stripe to gold; every Grade grants one item from a fixed list. At Grade 40, **Re-Orientation**: Pay Grade returns to 1, a Roman-numeral stamp (I-V) is engraved on the Deez, Casual Friday and the title Rehired unlock; everything else is kept. After stamp V the Deez reads LIFER and the Foreman uses your name at Roll Call.

### What Progression Never Touches

Wellbeing, every Line number, Footing, item stats, drop weights, Noise, monster HP, speed and counts, Pocket count, Vending Machine odds, scare rates, revive timers. Level entry is gated by the Shift reaching the level, never by Washers or Grade. No boosts, no Washer or Tenure doublers, no cosmetic that reduces visibility, hitbox or Noise. Clauses change the Shift for the whole lobby, and only harder.

### Monetization Stance

One price, the whole game. Levels, items and monsters ship free to everyone so lobbies never split. Cosmetic packs (a Line skin, Deez style, hat and Scream Pack) sell flat; every pack item reaches the vending wall at a Washer cost within 90 days, so money buys time, not exclusivity. No loot boxes, no paid currency, no Washer or Tenure sales, no battle pass, no timed exclusives, no ads.

### Retention Loop: Memos and the Performance Review

- **Memos** (3 dailies, one free reroll), each completable in one level: "0 Jerks between two Break Rooms" (60 W); "Seal a Break Room with a hat on every Link" (50 W); "Buy the crab" (25 W). All three: +50 Tenure.
- **The Performance Review** (weekly): one featured Clause at an extra ×1.2, one featured level at a doubled exit bonus. Completion: 500 W, 300 Tenure and that week's Break Room poster; missed posters reach the vending wall at 200 W after four weeks. No streaks, no penalty for days off.

### Example Unlocks and Costs

| Unlock | Track | Cost |
|---|---|---|
| Hat: Birthday Cake | Hat | 450 W |
| Outfit: Middle Management | Outfit | 600 W |
| Deez: Gold-Plated | Deez style | 2,500 W or Clean Shift |
| Line: Anchor Chain | Line skin | 1,200 W |
| Scream Pack: Slide Whistle | Scream Pack | 600 W |
| Emote: Jump Rope | Emote | 750 W |
| Lobby toy: Claw Machine | Lobby toy | 2,500 W |
| Clause: Short Leash | Mutator | Pay Grade 5, never sold |

---

## 9. Engine & Tech Stack

> **Decision (2026-10-15): the project is built in Godot 4.3+ with GDScript.** The team chose Godot after this analysis was written; `CLAUDE.md` records the binding architecture rules. The Unreal recommendation below is kept as a record of the trade-offs. The parts that carry over to Godot unchanged: a host-authoritative listen server, server-simulated chain and enemies with client interpolation, Steam Networking Sockets relay, FMOD-style audio states, and the scare director as data. The parts that change: ENetMultiplayerPeer replaces Unreal replication, a verlet rope plus distance constraints replaces Chaos constraints, and Godot lighting (SDFGI or baked lightmaps) replaces Lumen. Revisit the engine only if a six-player physics test on min-spec hardware fails.

### Requirements driving the choice

- **1-6 Links online**, drop-in/drop-out, a 2.5-3.5 h Shift saved at Break Rooms; co-op only, so one machine can hold authority.
- **The Line is the simulation:** a six-Link Huddle is 6 segments × 24 physics links (144 rope bodies) plus six 80 kg players, and "Jerk: Link 2" must be the same accusation on every screen.
- **Ragdolls everywhere** (players, Deadweight, Rollers, hats), **voice that feeds Noise** without an open microphone, **nothing baked:** hallways re-roll every 90 s and fluorescents dim with the Custodian.
- **15 people, PC first on Steam**, consoles 12-18 months later. Min spec, which is also the listen host: a 6 GB GPU of 2016 class, a 6-core CPU, 1080p/60.

### Engine comparison

| Criterion | Unreal Engine 5.5 | Unity 6 | Godot 4.3 |
|---|---|---|---|
| Netcode maturity | Replication, relevancy, prediction built in; Iris for scale; Steam and EOS NetDrivers | NGO young; FishNet (free) strong; Photon Fusion excellent but per-CCU | ENet high-level API; no relay, prediction or interpolation |
| Physics determinism, rope | Chaos joint chains, cable component, networked physics prediction; non-deterministic | PhysX articulations solid; Obi Rope the best PBD rope sold; non-deterministic | Jolt fast and stable; no rope; non-deterministic |
| Horror visuals, lighting | Software Lumen plus Virtual Shadow Maps; one flashlight in a dark hall looks right by default | HDRP matches with tuning; URP flatter | SDFGI and fog credible; fewer shadow tools |
| Team skills | C++ plus Blueprint; designers author scares alone; seniors harder to hire | C# everywhere; largest pool | Fewest shipped multiplayer-horror veterans |
| Cost | Free to $1M lifetime revenue, then 5%; EOS free | Per-seat subscription plus netcode and rope assets | Free, MIT |
| Tooling | Sequencer, PCG, Horde, Insights | Timeline, ProBuilder, Profiler, asset store | Light editor; thin profiling and cinematics |
| Console path | First-party on all three; porting houses Unreal-first | First-party on all three | Porting partners only |

### Recommendation

**Unreal Engine 5.** The game cannot compromise on replicated physics at six Links or dark dynamic lighting on a min-spec host, and Unreal ships both without a purchase: replication with relevancy and prediction, Chaos networked physics for host-authoritative bodies, software Lumen for dynamic GI at 1080p/60, and Virtual Shadow Maps so a single flashlight casts the hard, crawling shadows the Custodian's stain and the Darling's flicker tell depend on. Blueprint matters as much as rendering: every Unscheduled Event is a data asset a designer authors and previews in Sequencer, not an engineering ticket. EOS adds relay, lobbies and voice free for the console builds; Steam Sockets serve launch.

**What flips it:** a team already shipped in C# with no Unreal senior on staff, or a handheld PC at 60 fps as a hard requirement; both push to Unity 6 with FishNet, Obi Rope and URP. Godot flips nothing at this scope.

### Networking architecture

- **Topology: listen server** on the host Link's machine, headless-capable from month 1 so dedicated servers stay a hosting decision, not a rewrite.
- **Transport:** Steam Networking Sockets with Steam Datagram Relay (NAT traversal, free); EOS P2P relay for non-Steam builds; one NetDriver interface over both.
- **Authority:** the host owns the Line, Footing, monsters, the Director, Noise, Wellbeing, loot, Incidents and the Foreman; clients own input, camera and voice. The host alone attributes Jerks (the Link moving faster into the stop) over one reliable RPC.
- **Chain sync: server-simulated, client-interpolated.** The host simulates 24 links per segment and replicates 5 control points (every 6th link, 3 × 16-bit at 2 cm) plus a 2-bit state (Give / Bite / Stop / Pinched). Clients run a local PBD rope between the cuffs pulled toward those points, pre-apply the Bite spring locally and smooth corrections over 0.25 m across 100 ms. Rollback is rejected: 144 rope bodies plus ragdolls cannot be rewound in budget.
- **Rates and bandwidth:** host physics 60 Hz fixed; Links 30 Hz; chain points and ragdoll bones 20 Hz; monsters 20 Hz in view, 5 out. Per client at six Links: 40 kbps down, 8 up, cap 64; voice separate at Opus 24 kbps per speaker.
- **Host migration:** the lowest-ping client is the **Understudy**, snapshotted every 5 s. On host loss: 3 s freeze, Foreman: "Incident: supervisor separated. Deputy assigned." The Understudy promotes at most 5 s rewound; if it also drops, the lobby reloads at the last Break Room.

### Physics & chain tech

- **Options:** a rigid-body joint chain snags correctly but explodes at the 5.0 m stop with six ragdolls attached (4-6 ms a frame); a pure verlet/PBD rope runs under 1 ms but cannot push bodies or snag.
- **Chosen: hybrid.** PBD rope for shape and wrap; one Chaos distance constraint between the cuffs for the 5.0 m hard stop; the Bite as a spring on both cuffs (0 N at 4.0 m, 1,600 N at 5.0 m); per-substep sphere-casts along the rope catch corners and re-anchor the constraint there. 8 substeps per 60 Hz tick, 4 iterations, 0.5 kg per particle. Rustmaw deletes one particle per second; the segment parts at 10.
- **Ragdolls:** kinematic capsules until a trigger (airtime over 1 s, over 9 m/s off their feet, sprint Jerk, Downed), then a 15-body host ragdoll replicated as 6 key bones at 20 Hz that clients drive a local ragdoll toward.
- **Host budget at 16.6 ms:** physics 5.0 (Line 1.5, ragdolls 1.8, monsters 1.0, hats and loot 0.4, broadphase 0.3); game thread 4.0; render 6.0 (software Lumen 2.5, VSM 1.5); 1.6 headroom.

### Voice

- **Options:** EOS Voice (free, Opus, cross-platform, client-side 3D mixing); Steam Voice as fallback. Vivox rejected as a second account system, Dissonance and Photon Voice as Unity-only.
- **Attenuation and occlusion:** full within 8 m, logarithmic to −24 dB at 25 m, silent at 30 m; traced every 100 ms, blocked is −12 dB and a 1.2 kHz lowpass, a sealed Break Room door −30 dB.
- **Voice-as-Noise:** the client measures its own mic RMS every 100 ms, classifies silent (under −40 dBFS), speaking (−40 to −14, Noise +4/s) or shouting (over −14, +12/s), and sends a 2-bit level with its inputs. The host owns Noise and adds movement, chain drag, gunshots and decay. No audio reaches the host; released push-to-talk reads as silent, so every threshold stays reachable by sprinting and dragging chain.

### Horror & audio tech

- **Lighting:** software Lumen on min spec, hardware Lumen on RT GPUs, Virtual Shadow Maps on every flashlight and sconce. Every light is 4000 K except the Darling's single 3200 K lamp.
- **Flicker system:** every light carries a Flicker Profile (intensity, color-temperature and hum-pitch curves); the validator rejects anything over 3 Hz. The photosensitivity toggle replaces every profile with a smooth ramp; the Darling's shadow goes static but still points wrong.
- **Audio middleware: FMOD Studio.** The Scream Chord (fall velocity to pitch, 3+ fallers to chord), the 60 Hz hum's semitone drop, the Director's Drops and the Darling's 40 ms stutter are FMOD parameters.
- **The Director** (host service, 1 Hz; rules in Section 6): Dread, Group Tension, the per-level budget, cooldowns, targeting and payoff debt run host-side; Tension replicates at 1 Hz for FMOD. Each Shift's 64-bit seed draws 10 of each level's 24 procedural scares; a Layoff redraws. A scare is a data asset: trigger, target rule, source placement, FMOD event, 0.4 s flinch, Flinch-lock flag, fake-out variant, Foreman line. Scripted scares are Sequencer timelines bound to roles (Tail, lowest Wellbeing), never to players.

### Backend & platform

- **Steamworks:** 6-slot lobbies (public, friends-only, invite code), Steam Cloud for Washers, unlocks and settings, achievements (Clean Shift per level, Dennis found on all five). Unlocks are HMAC-signed; Shift progress lives on the host and the Understudy.
- **Crash reporting:** Unreal's Crash Reporter Client to Sentry, tagged with Shift seed, level, formation and the last 10 Incident numbers.
- **Scare telemetry (opt-in, never audio):** per scare: id, level, formation, Link count, target, camera yaw delta over 0.5 s, mic level delta over 2 s, Jerks within 3 s, Layoff within 60 s. ClickHouse flags any scare whose median yaw delta falls under 20°.
- **Anti-cheat:** none at kernel level: cosmetic-only unlocks and host authority mean a cheater ruins only their own lobby. Public lobbies need a matching build hash, and host-side sanity checks (speed, Wellbeing, item ownership) kick after three failures in 60 s; EAC through EOS is the fallback.

### Content pipeline & tools

- **Modular level kit:** 4 m grid, five per-zone sets of 12-28 pieces on shared sockets (the Exit Interview reuses the other four with 15 m seam pieces); every piece declares Line snag edges and carpet or marble for Noise.
- **Rearrange tool (Level 1):** 9 floors of 12 × 12 cells at 4 m. Designer-painted **spine** cells (shaft doors, Break Rooms, the copier, Dennis) never move; **swappable** hall cells re-roll outside every client frustum every 90 s, skipping any doorway with a segment through it; A* validates reachability to the next shaft under 2 ms, and an editor batch of 1,000 re-rolls must report 0 unreachable.
- **Scare authoring tool:** a Scare Stage map: drop 1-6 dummy Links in any formation, place a scare asset, press Play to see flinch, Flinch-lock, audio and Foreman line; the 3 Hz and photosensitivity validator runs on save.
- **Version control: Perforce Helix Core** (exclusive checkout) for the Unreal project, Git for tools. Git LFS is rejected: 200 GB of binaries without file locking loses `.uasset` merges.
- **CI:** Unreal Horde, self-hosted; nightly Win64 client and headless server. Gates: the **Jerk fixture** (1,600 N at 5.0 m, Jerk at 4 m/s, none at 3.9 m/s), a 30 min six-bot Huddle soak of Level 1 that fails on any client desync over 10 cm for 1 s, and the 64 kbps cap.

### Team & budget

| Role | Count | Owns |
|---|---|---|
| Producer | 1 | Roadmap, milestones |
| Designers | 4 | 1 lead (the Foreman, Do-Not List); 2 level; 1 systems (items, Noise, scares) |
| Engineers | 4 | 3 gameplay / network (one the lead); 1 physics (the Line, ragdolls, hats) |
| Artists | 4 | 1 tech (lighting, flicker, budgets); 2 environment (kits); 1 character / animator |
| Audio designer | 1 | FMOD, Scream Chord, the Foreman |
| QA | 1 | Plus an outsourced pass per milestone |
| Contract | - | Composer, concept artist, Foreman actor, porting partner |

**15 FTE, 12 months, about $2.0M:** $1.71M salaries at $9,500 blended per FTE-month, $160K contractors, $70K software and hardware, $60K demo and events, plus $300K contingency. **Key hires, in order:** a network lead who has shipped replicated physics in Unreal, a physics engineer for the PBD solver, a horror audio designer, a lighting tech artist.

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Chain desync blames the wrong Link | High | High | Host-only attribution; CI desync gate |
| Min-spec host misses 60 Hz with six ragdolls and Lumen | Medium | High | Frame budget; ragdoll LOD |
| Host migration loses a Shift | Medium | High | 5 s Understudy snapshots; weekly host-kill tests |
| Photosensitivity compliance | Medium | High | 3 Hz validator; external review before demo |
| Five levels in 12 months | High | Medium | Shared kit; Hotel Velluto is the cut candidate |

---

## 10. Prototype Roadmap

### Build-first principle

The Line must be fun before it is scary, and fun with nothing else on stage: no monster, no items, no art, no sound beyond the Scream Chord stub. If four people tied together at 5 m cannot make a greybox stairwell funny, the Custodian will not save it and no item on the roster plays without it. M0 builds only the rope, the four verbs (Jerk, Brace, Hoist, Tug) and the fall table, and tests them on **the Stair Test**: a greybox of the Sump Ladder, the Stairwell That Comes Back, a shaft cable on a pressure mat and a 7 m gap, 2-4 Links, 15 minutes.

**Kill criteria (end of week 4, after two tuning passes).** The project returns to pitch, and nobody ships a chain-off toggle, if either holds across 12 Stair Test sessions: laughs per minute under 1.5 at 4 Links (mic peaks counted client-side, nothing recorded), or fewer than 60% of testers rating "the Line was the best part" 4 or 5 of 5. Tunable: L (5.0 m), the Give share (80%), the Bite spring (1,600 N), the Jerk threshold (4 m/s), the Footing table. Not tunable: the stop, the cuff, or any option that plays a level unchained.

### Milestones

Thirty-two weeks from first commit to the public demo, inside the 15-FTE, 12-month plan in Section 9; team counts are FTEs from that roster.

#### M0 Chain-feel prototype — weeks 1-4
- **Goals:** prove the Line is the comedian, locally, 1-4 Links.
- **Deliverables:** Godot 4.3+ (GDScript, ENet) on the listen-server skeleton, LAN clients, headless-capable from day 1; the hybrid rope (24-link PBD, distance constraint, Bite spring, snag casts); Footing, the four verbs, the JERK label, fall table, ragdolls, Pile Cam, V toggle; the Stair Test greybox; Ballast, Buddy System, Conga, Huddle.
- **Exit:** the Jerk fixture passes (1,600 N at 5.0 m, Jerk at 4 m/s, none at 3.9); the Line under 1.5 ms per host tick with 4 segments and 4 ragdolls; kill criteria not met.
- **Team (6):** physics engineer, network lead, gameplay engineer, systems designer, tech artist, producer.
- **Biggest risk:** the rope explodes at the stop with ragdolls attached; the hybrid is the mitigation, the fixture the proof.

#### M1 Networked chain — weeks 5-10
- **Goals:** the same Jerk on every screen over the internet, 4-6 Links.
- **Deliverables:** Steam Sockets with SDR; 5 control points per segment at 20 Hz; client PBD with pre-applied Bite; host-only Jerk attribution with predicted-Jerk cancel; lobby vote, every formation, Catch-Up drop-in, Deadweight drop-out; Understudy snapshots every 5 s; EOS Voice with the 2-bit Noise feed; the six-bot Huddle soak in Horde.
- **Exit:** 30 min soak with no desync over 10 cm for 1 s; 100% Jerk-blame agreement across 6 clients at 80-150 ms; 40/8 kbps under the 64 kbps cap; a host-kill resumes at most 5 s rewound.
- **Team (6):** 3 gameplay/network engineers, physics engineer, systems designer, QA.
- **Biggest risk:** desync blames the wrong Link, the one joke the game cannot miss.

#### M2 First horror vertical slice — weeks 11-16
- **Goals:** one scare that lands at full force with the Line attached.
- **Deliverables:** Intake and Open Plan (B9-B7, 0-18 m), Break Rooms 1 and 2 with seal, Roll Call and Layoff; the Sump Ladder and Shaft 1 climbs; the Rearrange tool; the Custodian with Noise, five states, Grab out-pull, Torch retreat; Rollers ×4; the Director and Scare Stage tool; scripted **the Wrong Cab** (the first Pinch), procedural **Desk Phone**; Flinch-lock; Flicker Profiles and the 3 Hz validator; Lumen and VSM on min spec; FMOD hum and Drops; a provisional Dependable Torch.
- **Exit:** the Wrong Cab's median yaw delta over 0.5 s is 20° or more across 10 four-Link sessions; a Grab is out-pulled by two standing plus one Braced Link and by nothing less; 1,000 re-rolls, 0 unreachable; the min-spec host holds 60 fps with 6 Links and 6 ragdolls.
- **Team (11):** 2 level designers, systems designer, lead designer, 2 environment artists, tech artist, audio, 2 gameplay engineers, physics engineer.
- **Biggest risk:** a blind thing you never see is not frightening in greybox, and nobody can tell until lighting and audio are final; the slice gets final lighting first, layout second.

#### M3 Items and transformation — weeks 17-20
- **Goals:** the minimum funny set, each item with its Line side effect.
- **Deliverables:** the Lanyard, throw, hand-off, Line Pass, friendly fire logged as "workplace injury"; loot spawns 12 + 4 × Links from 40 points with the Level 1 bias; lockers; twelve items (Dependable Torch, Squeaky Dennis, Rolling Chair, Grease Can, First-Aid Kit, SHIFT! Energy, Anchor Spike, Party Popper, Snubby, Mirror Shard, The Honker, Mystery Juice Box); five forms (Snail, Pigeon, Cat, The Hurry, Big Lad), Group Plan at 10%; three physics hats.
- **Exit:** every number matches the Section 4 master table on an Item Stage map; a 4-Link session logs one workplace injury per 5 minutes unprompted; Big Lad does not fit a 0.9 m doorway.
- **Team (7):** systems designer, 2 gameplay engineers, physics engineer, character artist, audio, QA.
- **Biggest risk:** five forms with the Line on the equivalent limb is five rigs; one shared skeleton, scaled bones, one bespoke animation each, and a form is cut before the Juice Box.

#### M4 Playable demo — weeks 21-26
- **Goals:** all of Level 1, Sump to hatch, 1-6 Links, plus a Level 2 teaser.
- **Deliverables:** B9-B1 and the freight shaft; 5 Break Rooms with vending machines; six scripted scares, 12 procedural with the seed drawing 6; Carpet Mouths, Rustmaw, the Hook, the Coworker at 25% from BR3; the three puzzles; Dennis; Washers and a demo vending wall; two mutators; post-wipe replay; Steam lobbies and Cloud, Sentry, opt-in telemetry; accessibility; the teaser: Pappy's kitchen, one Security Desk, three Steps of Pappy on camera, one shutter pull, ending on the Birthday Song's last word.
- **Exit:** first-time 4-Link teams finish in a 25-35 min median, 1 and 6 Links within 20%; 99.5% crash-free hours; 0 validator violations and an external photosensitivity review passed.
- **Team (15):** everyone.
- **Biggest risk:** the teaser eats Management and the freight shaft; it is timeboxed to 2 people for 2 weeks and is the first cut.

#### M5 Closed playtest and polish — weeks 27-30
- **Goals:** hit the playtest thresholds with strangers.
- **Deliverables:** three waves of 8 teams (friends at 4 Links; matchmade at 1, 2, 4 and 6; mic-on creators), three runs each; tuning of Jerk attribution, Rearrange weights, Custodian thresholds, scare cooldowns and the onboarding order (Give, Bite, Jerk, Brace, Hoist, Pinch, Layoff); a Do-Not List review of every string and model.
- **Exit:** every Playtest plan threshold met in wave 3; a team's third run still peaks Group Tension over 70 in Records.
- **Team (15):** everyone plus the outsourced QA pass.
- **Biggest risk:** scare fatigue on the third run; the seeded pool, the retire rule and payoff debt are proven here or not at all.

#### Demo release — weeks 31-32
Steam demo, 1-6 Links, telemetry live, two hotfix slots. Day-7 criteria: 99.5% crash-free hours, 95% of Understudy promotions without a lobby reload, median session over 40 min, wishlist conversion above 20%. Two engineers on live; everyone else starts Level 2.

### Demo scope

| In | Out |
|---|---|
| Level 1 complete: 9 floors, 70 m, 5 Break Rooms, 5 chain climbs, 3 puzzles, the freight-shaft exit | Levels 2-5 beyond the teaser; every boss |
| The Custodian, Rollers, Carpet Mouths, Rustmaw, the Hook, the Coworker | Pappy outside the teaser, Big Dough, Tiny Tomato, Lanterns, Shamblers, Bellhops, Darlings, the Auditor, the Chairman |
| 6 scripted scares; 12 procedural, seed draws 6; every scare type; payoff debt | The full 24-scare pool; mutators beyond Dennis Everywhere and Longer Shift |
| 12 items, 5 forms, Group Plan, 3 hats, full friendly fire | The other 18 items, 7 forms, the Company Handset |
| 1-6 Links, every formation, drop-in/out, host migration, Steam lobbies, EOS Voice | Dedicated servers, non-Steam builds, consoles |
| Washers, vending machines, a demo wall: 3 Line skins, 5 hats, 2 Deez styles, 1 Scream Pack, 2 emotes | Foreman Announcement Packs, Break Room decor, Ballast skins |
| Post-wipe replay, Incident Report, Roll Call wrong at Wellness | Localization beyond English |

### Order of feature build

1. Hybrid rope, Give/Bite/stop, Footing: nothing is testable without it.
2. Jerk, Brace, Hoist, Tug, the JERK label: the four verbs and the first joke.
3. Fall table, ragdolls, Pile Cam, Scream Chord: the punchline every scare resolves into.
4. V toggle, Flinch-lock, the 0.4 s flinch: delivery before monsters.
5. Listen server, control points, client PBD, Jerk attribution: chain feel must survive the wire before content depends on it.
6. Formations, lobby vote, Catch-Up, Deadweight on leave: 1-6 scaling sets every level metric.
7. EOS Voice and the Noise feed: Noise is the Custodian's only sense.
8. Understudy, bandwidth cap, soak gate: netcode debt paid before designers build on it.
9. Yellow Rooms kit, 4 m grid, snag edges, carpet flags: no level without it.
10. Flicker Profiles, 3 Hz validator, Lumen and VSM on min spec: the Custodian's tell and a safety gate.
11. Rearrange tool and reachability batch: it constrains every hall, so it precedes them.
12. Break Rooms, seal, Roll Call, Layoff, Corpse Commute: the loop closes before anything can kill.
13. The Custodian, five states, Grab out-pull: the first monster, countered only by the Line.
14. Dependable Torch, Squeaky Dennis, Anchor Spike: its counters ship with it.
15. The Director, Scare Stage tool, seed and retire rule: the service before the scares.
16. FMOD hum, Drops, music states, chain rattle: heard before seen.
17. The Wrong Cab, then the other five scripted scares in Sequencer: fixed beats after systemic ones work.
18. Rollers, Carpet Mouths, Rustmaw, the Hook: roaming pressure after the main threat is tuned.
19. Lanyard, throw, hand-off, Line Pass, workplace-injury log: the framework before any item.
20. The remaining nine items and hats as physics: comedy after the horror lands.
21. Mystery Juice Box and five forms: the costliest minute of play, so last among items.
22. Washers, vending machine, lockers, demo wall: progression pays out only from a complete level.
23. Steam lobbies, Cloud, Sentry, telemetry, accessibility: release infrastructure, after fun.
24. Post-wipe replay, Incident Report, the Coworker: polish on a working Layoff and voice buffer.
25. The Level 2 teaser: borrows everything above, so built last and cut first.

### Playtest plan

**Measured (opt-in, counts only, no audio stored):** laughs per minute (a client-side classifier on mic bursts of 0.3-2.0 s over −20 dBFS; only a count and timestamp leave the client); wipes (Layoffs per run and per Break Room interval, with the replay's Jerk culprit); scare reactions (yaw delta over 0.5 s, mic delta over 2 s, Jerks within 3 s, Layoff within 60 s); chain frustration (Jerks per minute, mean Pinch, all-Brace stalemates, mid-climb disconnects, and two 1-5 survey items: "the Line got in the way", "the Line was the best part"); flow (completion by Link count, Clean Shift rate, Scare Intensity chosen, a quit within 5 minutes of a ragdoll).

**Tests per milestone:** M0 three Stair Tests a week at 2-4 Links; M1 one six-Link internet session a week plus the nightly soak; M2 ten slice sessions at 4 Links, half external; M3 six Item Stage sessions; M4 two waves of 12 teams; M5 three waves of 8 teams at 1, 2, 4 and 6 Links, three runs each.

| Measure | Threshold | Milestone |
|---|---|---|
| Laughs/min, 4 Links | 1.5 with no monster; 2.0 with items | M0; M4 |
| "Best part" rated 4-5 | 60%; 70% | M0; M5 |
| "Got in the way" mean | 3.0 or under; 2.5 or under | M0; M5 |
| Scripted scare median yaw delta | 20° or more; 70% of targets with mic delta +6 dB | M2 on |
| Layoffs, first 4-Link run | median 1-3; under 10% at 0 or over 6 | M4 |
| Jerks/min | 0.5-2.0 (under is invisible, over is a leash) | M2 on |
| Mean Pinch | 8 s or under | M2 on |
| Completion, 4 Links | 25-35 min median; 1 and 6 Links within 20% | M4 |
| Scared self-report 4-5 | 60% on run one, 50% on run three | M5 |
| Would play again | 75% | M5 |
| Motion-sickness quits | under 3% of sessions | M4 |

### Risk register

| # | Risk | L | I | Mitigation |
|---|---|---|---|---|
| 1 | Chain desync blames the wrong Link | High | High | Host-only attribution; predicted Jerk cancelled within 150 ms; CI soak fails on 10 cm for 1 s |
| 2 | The Line reads as a leash | Med | High | Give at 80% of L; tune only L, spring, Jerk threshold, Footing; M0 kill criteria; no chain-off toggle |
| 3 | Friendly-fire griefing | High | Med | Friendly fire stays; injuries named on the Incident Report; 20 s vote-kick, Deadweight on kick, 10 min immunity; Snubby ×0.5 in Level 1, no ammo pickups |
| 4 | Motion sickness | Med | High | 0.25 s blends; flinch eased over 0.4 s, never a cut; third person forced on ragdoll; Reduced intensity drops the snap; FOV slider 80-110 |
| 5 | Scare fatigue | High | Med | 24-scare pools, seeded draw of 10, retire after 3 sightings for 5 Shifts, fake-outs and payoff debt, mutators; ClickHouse flags scares under 20° median yaw |
| 6 | Min-spec host misses 60 Hz | Med | High | Budget 5.0 / 4.0 / 6.0 / 1.6 ms; ragdolls as 6 key bones; monsters 5 Hz out of view; nightly perf gate on min spec |
| 7 | Host migration loses a Shift | Med | High | Understudy snapshots every 5 s and at every seal; weekly host-kill tests; lobby reload at the last Break Room |
| 8 | Rearrange strands the Line | Med | Med | Spine cells fixed; 1,000-reroll batch, 0 unreachable; doorway segments pin cells; every Pinch resolves on 3 s of opposite pull |
| 9 | Photosensitivity compliance | Med | High | Flicker Profiles; 3 Hz validator on save; the toggle replaces every profile; external review before M4 exit |
| 10 | Transformation scope | High | Med | One shared skeleton, one animation per form; forms in priority order; cut forms before the Juice Box; the Line never scales |

### Post-demo plan

**Weeks 33-52:** Level 2 in full (Pappy's 11-node graph, the Desk Jockey, Big Dough, Tiny Tomato, Mama Crust, the inflatable chef) in weeks 33-40; Carrow Heights (Lanterns, Sundown, Safe Rings, Chain-lining, the Pendulum, the Water Tower, the Pack Run, the crane) in weeks 37-48; the other 18 items and 7 forms in three drops; 60% of the cosmetic catalog; dedicated servers from the headless build.

**Early Access at month 12** with Levels 1-3, Mama Crust, every item, all 12 forms, Steam only: the Line's tuning, the retire pools and the Darlings' tells need thousands of teams before they lock, and the Stack pauses naturally at the crane with the hotel window dark. Entry: the M5 thresholds held in live demo telemetry over 30 days.

**Cadence:** a drop every 6 weeks (one mutator, two cosmetic sets, one Foreman Announcement Pack, balance). Hotel Velluto (Darlings, Bellhops, Room Service, counterweight lifts, Suite 909, Madame Velluto) at month 15. The Exit Interview (Slices, the Auditor, the Chairman, Roll Call, Door 1) at month 18, which is **full release**: the complete 2.5-3.5 h Shift, every boss, the full catalog, EOS builds. Hotel Velluto stays the cut candidate: if it slips past month 16, full release ships Levels 1, 2, 3 and 5 with the hotel as the first post-launch level. **Consoles** 12-18 months after PC through the porting partner.

---

## Appendix A - Creative Bible (canon)

The locked names, rules and numbers every section was written from.

### Title, Tone Pillars & Fiction

#### Tone Pillars
- **Scream, then laugh.** Every scare lands at full force; the punchline is what the physics did to the team during the scare. Never the other way round.
- **The Line is the comedian.** Monsters are never funny. Six adults tied together with five meters of chain always are.
- **Stupid loot, serious consequences.** Items are absurd; their results are real. Fire spreads, bombs stick, friends fall.
- **The company is calm.** The game's voice treats a colleague being pulled into a ceiling as a paperwork issue.
- **Nobody escapes alone.** Any system that plays the same without the Line gets redesigned until it doesn't.

#### Premise
Players are new hires at **DEEZ Industrial Fasteners** ("Holding It Together Since 1931"), makers of the Deez nut: a Grade 8 hex coupling nut that cannot be undone by the person wearing it. Orientation Day is a mandatory team-building ascent of **the Stack**, a 420 m tower the company built by buying failed businesses whole (an office block, a family pizzeria, a city block, a luxury hotel) and stacking them floor by floor. Nobody who was inside those businesses ever left. The team wakes at the bottom in **the Sump**, a flooded pit that kills anything that falls in, wrists cuffed into the company's chain product, each cuff locked by one Deez. The three words stamped on every cuff are the packaging slogan, product line first, fastener second, promise third: **CHAINS · DEEZ NUTS · TOGETHER**. Climbers never say the brand; they say the title. **Escape** means reaching **Door 1** on the roof and clocking out: the nuts release only when the shift timer reads "Shift Complete."

#### Voice
**The Foreman**: a dead-calm PA voice reading a workplace-safety manual that was never written for this. Flat, polite, uninterested in your survival, never sarcastic. Jump scares are "Unscheduled Events," deaths are "Separations," and every one gets an Incident number that counts up across the whole Shift ("Incident #212: colleague removed by ceiling. File a report when safe."). The HUD is a laminated badge: HP is "Wellbeing," noise is "Professionalism," items hang on a "Lanyard." Menus are a punch-clock wall; UI copy is caution-stripe yellow on black with a hex-nut cursor.

### Vocabulary

| Thing | Canon term | Usage |
|---|---|---|
| The chain | **the Line** (each span is a **segment**) | "Watch the Line on the stairs." |
| A chained player | **a Link** | "Six Links, one Line." |
| Slack | **Give** (segment under 4.0 m; HUD green) | "You've got Give, go." |
| Tension | **the Bite** (4.0-5.0 m, rising spring; HUD amber, red at the stop) | "It's biting, brace!" |
| A yank | **a Jerk** (the event and the Link who caused it) | "Jerk: Link 2." |
| A deliberate pull | **a Hoist** | "Hoist him up." |
| Checkpoint | **a Break Room** (sealed room with a punch clock) | "Clock in. Door's sealed." |
| Group death | **a Layoff** | "Layoff. Report to your last Break Room." |
| Currency | **Washers** | "Forty Washers for the climb." |
| A run | **a Shift** | "Clean Shift, no Layoffs." |
| The hex nut on each cuff | **a Deez** | Tooltip: "DEEZ. Holding it together." |
| Solo partner | **the Ballast** | A 35 kg cast-iron Deez with a smiley face and a name tag. |
| A dead Link's body | **Deadweight** | 80 kg ragdoll, still on the Line. |
| A Link off the Line | **Loose** | Hunted at 2× aggression; 60 s to re-couple. |

#### Running Gags
1. **"Who jerked?"** Every logged Jerk floats a JERK label over the culprit for 10 s; the scoreboard counts them.
2. **Dennis from Accounts.** A cardboard Employee-of-the-Month standee appears once per level somewhere wrong (ball pit, hotel bar, radio mast). Monsters never touch Dennis. Never explained.
3. **The Vending Machine.** Every Break Room has one. 5 Washers buys one random thing: 60% a Common item, 25% one warm sausage (heals 5), 10% a live crab that chases the Line for 30 s, 5% a Legendary.
4. **The Scream Chord.** Ragdoll screams pitch-scale with fall velocity; when 3+ Links fall together the game auto-tunes them into a major chord.
5. **The Corpse Commute.** Deadweight is dragged face-first up every staircase to the next Break Room.
6. **Hats are physics.** Every cosmetic hat is a rigid body. Nobody will leave one behind.
7. **Roll Call.** At each Break Room the Foreman counts Links aloud. It is sometimes wrong by one. It is never wrong by accident.
8. **Motivational Posters.** Posters change to the situation: "HANG IN THERE" over every drop, "TEAMWORK" on every two-Link door.

### Chain & Death Rules

#### Configurations
Formation is set in the lobby and re-formed only at a Break Room. The host may force any shape legal for the count.

| Links | Default | In-world name | Segments | Notes |
|---|---|---|---|---|
| 1 | Ballast | "the Ballast" | 1 × 4 m | Thrown 6 m max, Anchor-Spiked, counts as a Link for Break Rooms and Door 1 |
| 2 | Pair | "Buddy System" | 1 × 3 m | |
| 3 | Line | "the Conga" | 2 × 5 m | Ends are the Tails, the vulnerable Links |
| 4 | Ring | "the Huddle" | 4 × 5 m | Option: two Pairs joined by one 6 m Trunk |
| 5 | Line | "the Conga" | 4 × 5 m | Middle Link is the pivot |
| 6 | Ring | "the Huddle" | 6 × 5 m | Option: three 3 m Pairs on a 6 m Trunk ring |

Drop-in: a joining Link spawns at the last Break Room and attaches to the nearest Link's Deez as a dangling Tail until the next Break Room reforms the shape. Drop-out: the leaver becomes Deadweight until the next Break Room.

#### Physics
Segment max **5.0 m**, 24 physics links, 12 kg per segment, player mass 80 kg. 0-4.0 m is Give (no force); 4.0-5.0 m is the Bite (spring to 1,600 N); 5.0 m is a hard constraint. **Footing** values: airborne 0, Downed 0.3, standing 1, on ladder 1.5, Braced (hold crouch, 0.2 s wind-up, cannot move) 2, ledge-hanging 1 with a 6 s grip meter, Anchor-Spiked 99. Each airborne Link is 0.5 load, so one standing Link holds two danglers, a Braced Link holds four, and five danglers pull anyone off anything. At the stop, the side with lower total Footing moves. A **Jerk** fires when a segment hits 5.0 m with relative speed of 4 m/s or more: the caught Link takes a 1.5 s stagger (no damage); a sprinting Link who hits the stop ragdolls 1 s. Rings split load across both neighbors; Pairs split nothing across the Trunk, so the Trunk Link is the most frequent Jerk. The Line snags on corners and railings on purpose; chain dragging on floor is Noise.

#### Falling and Dragging
Fall damage by vertical drop: under 4 m none; 4-8 m 30; 8-14 m 70; over 14 m Downed; over 20 m or the Sump, Dead. A fall arrested by the Line deals no damage, only the Jerk stagger, and is arrested only if the holding side's Footing beats the load. Landing on a teammate halves your damage and deals them 20. Any Link over 9 m/s while not on their feet ragdolls until under 4 m/s. A Link dangling in the Sump's kill plane has 8 s before something below takes them.

#### Downed, Dead, Layoff
- Wellbeing **100**, no regen. At 0 (not from the Sump or a grab-kill): **Downed**. Crawl 1 m/s, can speak, bleed out in **45 s**, dragged as luggage at −30% team speed. Revive: any standing Link within 2 m holds interact 4 s; return at 40. Solo: Downed is a Layoff unless holding a First-Aid Kit (auto self-revive after 5 s, once per Break Room).
- **Dead**: bleed-out, grab-kill, Sump, or a Loose Link's timer. The body becomes Deadweight (80 kg, Footing 0) on the Line until the next Break Room (revive at 50) or Jumper Cables (revive at 25). Dead Links spectate from any living Link's camera; their voice plays from the corpse at 10% volume, lowpassed. A Line with 50%+ Deadweight is "Overloaded": team speed −40%.
- **Layoff**: every Link Dead, or every living Link Downed. Return to the last Break Room at full Wellbeing; Pocket items kept, hand items lost; Washers earned since kept at 50%; monsters return to patrol; random scares reroll.

#### Break Rooms
Per level: 5 / 4 / 6 / 5 / 4, every 40-60 m of ascent. The door seals only when every living Link and every Deadweight is inside and one Link punches the clock (2 s). On seal: Deadweight revives at 50, everyone heals to 100, formation reforms, progress saves. Inside: vending machine, 3 lockers. Safe while sealed; any Link can open the door; monsters take 25 s to path to the room after it opens.

#### Camera
V toggles first/third person any time, 0.25 s blend, per player. First person: 90° FOV, the Bite shown as cuffs tugging the screen edge. Third person: 2.2 m behind, 0.4 m over the right shoulder, the whole Line visible. Segment colors show on the HUD in both modes. Scripted scares and face-grabs force first person for 1.2 s (**Flinch-lock**); ragdoll, Downed, transformations and any airtime over 1 s force third person, then restore. Every scare flinches the camera 0.4 s toward its source.

#### Scaling
Monster HP +15% per Link above 2. Loot spawns per level: 12 + 4 × Links from a pool of 40. Scripted scares target the Tail in a Conga, the lowest-Wellbeing Link in a Huddle.

### The Vertical Stack

| # | Level | Height / floors | Play time | Style (generic) | Light & sound |
|---|---|---|---|---|---|
| 1 | **The Yellow Rooms** | 0-70 m, 9 floors (B9-B1) | 25-35 min | Endless liminal office; a thing you hear but almost never see | Sodium-yellow fluorescents at 60 Hz hum that dim near the threat; carpet hush; a floor buffer somewhere that is never found |
| 2 | **Pappy Pepperoni's Night Shift** | 70-130 m, 4 floors + stage rigging | 30-40 min | Survival night-guard setup with possessed mascots | Red exit signs, CRT camera glow, servo whine; party music slowed to half speed; a counter bell that rings itself |
| 3 | **Carrow Heights** | 130-220 m, 12 rooftops | 35-45 min | Rooftop parkour over an infected city; slow by day, lethal by night | Orange sodium dusk to pitch black, UV lamp islands; wind, howls that triangulate, one dog barking that stops |
| 4 | **Hotel Velluto** | 220-330 m, 14 floors + rooftop dome | 35-45 min | Luxury hotel where the friendly guests are not guests | Candle-warm sconces, deep carpet; lounge piano through walls that drifts off-key; voices with no reverb |
| 5 | **The Exit Interview** | 330-420 m, 6 slices of 15 m | 25-30 min | Mashup of every zone ending in a boss chase | Every palette stitched at hard seams; every monster's cue overlapping; the Foreman closer than it has ever been |

A full Shift runs 2.5-3.5 hours; level entry unlocks per level reached.

### Level Rosters

#### 1. The Yellow Rooms
- **Main monster: the Custodian.** A 3 m figure living in the drop ceiling and wall cavities, seen only as a bruise-colored stain where it presses against drywall, and once per Shift as a face. It is blind and hunts by **Noise**: each Link carries a 0-100 value (speaking +4/s, shouting +12/s, walking +1/s, sprinting +3/s, chain dragging +2/s, gunshot +40, decay 5/s). States: Dormant → Listening (any Link over 40 within 40 m; the fluorescent above them drops a semitone and dims) → Stalking (over 60; moves through walls at 6 m/s to within 15 m; ceiling tiles bow and dust falls along its path) → Grab (a Link within 8 m stands still 3 s; it drops through a tile, grabs them, and lifts them into the ceiling over 4 s against Footing 3). Two standing Links plus one Braced out-pull it, or the Link is executed above the tiles and the body drops back. Direct flashlight on the stain for 2 s forces a 20 s retreat. Counterplay: walk, Brace to kill chain noise, drop a Squeaky Dennis, never shoot.
- **Roaming: Rollers.** Empty office chairs that move only when no Link is looking, 8 m/s; impact ragdolls a Link 2 s and Jerks the Line. **Carpet Mouths.** Wet patches 1 m wide that bite and hold an ankle at Footing 4 until the Line pulls at 5 or the patch takes 50 damage.
- **Boss:** none.
- **Signature mechanic: the Rearrange.** Every 90 s, every hallway outside all player view frustums re-rolls. A doorway with the Line through it cannot swap; a Pair pins one door, the Conga pins three. A segment crossing a seam when it rotates is **Pinched**: both Links pinned until they pull opposite ways 3 s. Progress is up dead elevator shafts climbed hand-over-hand; shaft doors stay open only while a Link stands on the pressure mat, so the 5 m segment decides who climbs and who holds.
- **Scripted scare: the Photocopier.** A copier starts printing alone: photos of the team from behind, taken now. The last print is the Custodian's face over the Tail's shoulder; lights cut 1.5 s; the Line Bites hard once.
- **Exit:** the freight shaft, cab missing. Climb the counterweight cables 18 m; at 15 m the Custodian grabs the Tail's ankle; a 2-Link Hoist within 4 s frees them.

#### 2. Pappy Pepperoni's Night Shift
- **Main monster: Pappy Pepperoni.** A 2.6 m mustachioed chef animatronic with pepperoni eyes and human teeth. He moves only while no Link looks at him and no camera shows him, along an 11-node room graph, one node per **Step** of 14 s minus 1 s per Link beyond two (minimum 8 s). He sees light within 25 m, hears doors slamming within 30 m, and smells gunpowder: any gunshot on his floor skips his next timer. Tell: servo whine rising in pitch, then the party-room jukebox stops. At a **Shutter** node beside the climb hall: shutter closed, he bangs three times (Noise 100) and returns to Stage; open, he enters and grab-kills the nearest Link within 6 m. Flashlight freezes him 1.5 s (8 s cooldown). Counterplay: lights off, keep him on camera, seal shutters, hide in the walk-in freezer (he cannot path inside).
- **Roaming: Tiny Tomato.** Toddler-sized vent crawler, 7 m/s, drops onto a Link's face for 15 damage and 3 s of blind. **Big Dough.** A dough-mass strongman, 1.5 m/s, breaks any door in 6 s, immune to guns, stunned 5 s by a Party Popper.
- **Boss: Mama Crust.** A 4.5 m stage animatronic bolted into the rigging above the stage shaft; the exit is the catwalk above her and the Line climbs her body. Her arms sweep the catwalks every 7 s (4 m knockback, which is a fall, which is a Jerk); her eye lamps blind first person 1 s. Three fuse boxes on three catwalks must be pulled within 2 s of each other, count = min(Links, 3); the Ballast can be thrown onto a lever. Each pull costs her one of three phases; in phase three lights drop to zero and she tracks by Noise. 600 HP, damaged only during the 3 s after a pull.
- **Signature mechanic: the Desk Jockey.** Each floor has a Security Desk. One Link clips in and runs cameras (−0.3%/s), lights (−0.1%/s) and the stage lift (−1%/s moving) from a 100% power bank. Climbers can go only 5 m × (Links − 1) from the desk, so the Desk Jockey must unclip and sprint to the next desk, shutters dead, while the Line Hoists them. Shutters cost no power: they close when the Line's middle is hooked to the pulley and two Links walk apart into Bite, and stay shut only while Bite holds. At 0% power Pappy free-roams at 2 m/s until the next Break Room restarts the generator.
- **Scripted scare: the Birthday Song.** Power drops to 0. One party-hat spotlight. The band sings a slowed birthday song, by name, to the Link with the lowest Wellbeing. On the last word the office door swings open and Pappy's face fills it.
- **Exit:** the roof's giant inflatable chef. Climb its arm while it deflates (40 s), leaping bulge to bulge; the Line must stay under Bite or the sagging fabric drops the Tail.

#### 3. Carrow Heights
- **Main monster: the Lanterns.** Night hunters, 2.2 m, dim orange eyes; 8 m/s sprint, 6 m leap, 4 m/s wall climb, 250 HP. Sight 60 m under light (a flashlight is visible at 60 m, a flare at 120 m), hearing 30 m. One that sees the group screams for 3 s and every Lantern within 100 m converges in 15 s. A pounce Downs an unbraced Link; a Braced Link takes 30 and holds. A Lantern grabs a Link and runs for the roof edge at 6 m/s; only two Bracing Links stop it. Blinded 4 s by flare, 2 s by flashlight under 5 m; they will not enter UV light. Pack = 1 + floor(Links ÷ 2) on night one, plus one each night after. Counterplay: UV flares, go dark and quiet, deny leap angles with Chain-lines, never let one Link out-sprint the Line into open roof.
- **Roaming: Shamblers.** Day infected, 1.2 m/s, 150 HP; they grab the Line itself and hold, and three on one segment stops the team. **Bloats.** Swollen Shamblers that burst at 2 m: 50 damage in a 4 m radius and a ragdoll that ragdolls the Line.
- **Boss:** none. The third night is the **Pack Run**, a 120 s scripted climb with the full pack behind.
- **Signature mechanic: Sundown and chain crossings.** 150 s day, 90 s night; night starts whether or not you are on a safe roof. Rooftop UV lamps make 6 m Safe Rings (a Pair fits; a Conga leaves two Links in the dark); generators need 2 Links cranking 10 s. Gaps of 6-9 m are crossed by **Chain-lining** (one Link on each roof at full Bite, middle Links slide across the taut Line), the **Pendulum** (an anchored Link swings a dangling teammate 6 m to a ledge), and ziplines that carry 2 masses, a third snapping the cable.
- **Scripted scare: the Water Tower.** The only ladder up rooftop 7 runs through a water tank. As the first Link clears the hatch, a Lantern erupts from the tank 1 m away, roars 1.5 s, and drops back in. That Lantern leads the next night's pack.
- **Exit:** the radio mast crane. One Link rides the hook, the rest hang, lifted 40 m through a second-floor window of Hotel Velluto while Lanterns leap at the lowest Link.

#### 4. Hotel Velluto
- **Main monster: the Darlings** (full rules in The Succubi). Count per floor = ceil(Links ÷ 2).
- **Roaming: Bellhops.** Faceless 2.8 m figures pushing luggage carts at 7 m/s; impact ragdolls a Link 3 s and the cart snags any Taut segment and drags the Line toward the atrium drop at 2 m/s. **Room Service.** Cloche trolleys: lifting the lid is 30% a Rare item, 70% a hand that takes 40 Wellbeing and pulls the lifter under the trolley for 3 s.
- **Boss: Madame Velluto.** The owner, a gracious elderly hostess in the rooftop ballroom under a 3-ton chandelier and twelve pillars. Phase 1: twelve copies stand at twelve mirrors; the real one's reflection moves 0.5 s late. Shooting her stuns her 6 s, during which she takes one Link's hand and waltzes at 4 m/s; the Line winds around pillars, and once tangled on three pillars she cannot let go and takes damage (600 HP). The team must untangle before the pull reaches 5.0 m and tears the nut. After 50% she drops the hostess form, the lights go to candles, and her sweep dislodges the chandelier chain the Line must climb.
- **Signature mechanic: Counterweight Lifts and Carpet Hush.** Service elevators rise only when the counterweight cage is heavier: six Links is 2 up and 4 down, three is 1 and 2, and every trip leaves people hanging on a 5 m leash in a dark shaft. On red carpet the Line is silent; on marble it rings and summons a Bellhop within 20 m.
- **Scripted scare: Suite 909.** A Darling sits on the bed brushing her hair, facing away. She never turns. The wardrobe mirror shows her already standing behind the Tail.
- **Exit:** the rooftop pool (every Link in the water adds 20 kg to the Line), drained through a 1.2 m drain onto the Stack's exposed scaffold.

#### 5. The Exit Interview
- **Main monster: the Auditor.** 4 m tall, hi-vis vest, a clipboard in one hand and shears for the other. It walks at 3 m/s and never stops. It is the only thing that cuts the Line: it cuts only a segment with over 1 m of Give (two Links closer than 4 m). A cut Link is **Loose** and has 60 s to re-couple by holding interact 2 s within 1 m of any Link; at 60 s the Auditor takes them and the body is gone. 800 HP; every 100 damage stuns it 3 s. Counterplay: stay in Bite. Slack is death here.
- **Roaming:** Rollers, Tiny Tomato, Bloats and Bellhops, each inside its own slice, at 1.5× speed.
- **Boss: the Chairman.** A 12 m knot of every previous team's chains, cuffs and Deez Nuts, climbing the final shaft behind the team at 3.5 m/s for a 120 s chase. Its 20 m chain-whip sweeps every 6 s (30 damage, ragdoll); it throws chains that cuff onto the Line and reel at 1.5 m/s (cut by any gun in 2 s, any explosive, or a Goat). Door 1 opens only when every living Link is in Bite in the same direction for 5 s; solo, the Ballast is dropped down the counterweight shaft to make the pull.
- **Signature mechanic: Slices.** Every 15 m the rule set switches and a Nut Station forces a new formation (Conga → Huddle → Buddy System → Conga): Rearrange, then Desk power, then a 90 s day-night, then Darlings, then the Auditor, then the Chairman.
- **Scripted scare: Roll Call.** The Foreman counts the Links at the slice-four Break Room. It counts one too many. The extra is standing in the Line between two Links, shackled in, wearing a player's model and name tag. It smiles. The Auditor cuts it out.
- **Exit: Door 1.** The roof at dawn, a field below. The shift timer reads "Shift Complete," every Deez falls off and bounces, and the Foreman reads the Incident total.

### Cross-Level Threats

**The Coworker.** A seventh Link. It wears a random player's model, hat and chain skin, walks 5.0 m behind the Tail, and speaks in proximity voice using a 2-second-old copy of a teammate's words. It closes to 1.5 m only while unobserved, then takes a grab-kill. Its one tell is on its wrist: no Deez. "Check the nut" is the counter; a flashlight on the bare cuff makes it flee at 10 m/s for 60 s, and a Mirror Shard shows it behind you whether or not you wanted to know.

**Rustmaw.** A 0.4 m iron-colored crawler that eats chain. It latches a segment and chews one physics link per second; at 10 links the segment parts and a Link goes Loose. Tell: a grinding sound and orange flakes falling from the Line. Guns do nothing to it while it is on the chain. Counter: stomp it (any Link within 1 m), burn it, or a Jerk: two Links sprint opposite ways until the Bite flicks it off, usually into a wall, sometimes into a teammate. The Line re-forges when the Loose Link touches another Link.

**The Hook.** Every 3-6 minutes outside boss rooms, a crane hook drops from the dark above and snags one random Link's cuff, lifting them 10 m at 3 m/s, holding 4 s, then letting go. The lift drags the Line. Two neighbors Braced stop the lift at 2 m; 50 damage to the cable cuts it early.

### The Succubi

**Name:** the Darlings (singular: a Darling). Transformed: **a Vacancy.** Fiction: guests of the Velluto who never checked out. There are no real strangers in the Stack.

**Presentation at distance (20-40 m).** A warm pool of light, a fully dressed woman in evening wear or staff uniform at a doorway or balcony rail, waving every 6 s, calling in a normal, worried voice: "Darling, over here, the door's jammed." Visible loot sits behind her. No horror cues at this range.

#### Approach Phases
| Phase | Distance | Behavior |
|---|---|---|
| Hail | over 20 m | Waves, calls, does not move. |
| Draw | 20-8 m | Asks for one specific thing, steps to the edge of her cover; moves 0.5 m closer each time no Link looks at her. The ambience fades under a lounge piano. |
| Reach | 8-3 m | Extends a hand, says the nearest Link's name, asks them to come alone. The approaching Link's Bite threshold drops to **2.0 m** (the Leash); one Bracing teammate stops them here. |
| Turn | under 3 m, touch, or 2 s of flashlight on her face | Transformation. |

**Isolation Rule:** a Darling only Turns on a Link at least 4 m from every other Link. Two Links arriving together get a polite, backing-away smile. The Line is the counter, and the 5 m leash is why she asks for one.

#### Tells
1. **Wrong reflection:** mirrors, windows and puddles show her 0.5 s late, 1.5 m closer than she is, and always standing; chrome shows nothing.
2. **Flickering shadow:** her shadow flickers at 3 Hz and points toward the nearest Link, whatever the light source.
3. **Glitching audio:** a 40 ms stutter every 6 s, one clipped word per sentence, no room reverb in reverberant halls; teammates' proximity voice gains 200 ms of reverb within 10 m of her.
4. **Non-positional voice:** teammates hear her from their own Link's position, not hers.
5. No footstep sounds, no footprints in dust, clothes always dry on wet carpet.
6. The light nearest her is 3200 K; every other light in the level is 4000 K.
7. She blinks in sync with whichever Link she is looking at, and rotates three lines without ever answering a question.
8. The clock behind her is stopped at 3:11.

#### Transformation
0.8 s: the smile stays while the body stretches to 2.8 m, joints bend backward, arms reach the floor, and the face is the last thing to change, folding inward like wet paper, accompanied by the sound of a tape reel rewinding. Lights die; Flinch-lock. She is a shape, not a body.

#### Combat
Vacancy: 300 HP (3× damage during the 0.8 s), 7 m/s, 5 m lunge. She grabs one Link (20 damage/s, Footing 3) and drags them toward the nearest edge at 6 m/s, pulling the Line; a Bracing team holds her at the 5.0 m stop. Flashlight staggers 1 s (8 s cooldown); flare light makes her flee 10 s; a knee-height Taut segment trips her 4 s; salt does 2×; shotgun needs 2 shells. After 20 s of combat she retreats to the nearest dark doorway and rebuilds a Darling 60 m higher with a new face. Killing her in Darling form (120 HP) wakes every Darling on the floor.

#### Counters
Check a mirror first. Brace before anyone crosses 8 m. Spot two tells and shoot from 10 m. A Squeaky Dennis at 15 m holds her in Draw for 20 s. Carry a Mirror Shard. Never approach alone; she never takes the first step while watched.

### Item Roster

Each Link has two hand slots and one **Pocket** (kept through Layoff). Drop weights: Common 45 / Uncommon 30 / Rare 18 / Legendary 7. Dropped items persist in place for the Shift. Full friendly fire, always; the Foreman logs it as "workplace injury."

| Item | Category | Rarity | Effect | Chaotic side effect |
|---|---|---|---|---|
| Snubby | Pistol | Common | 12 rounds, 20 dmg, 40 m; Noise +40 | Muzzle flash is a full Flinch; Pappy skips a timer |
| Doorknocker | Shotgun | Uncommon | 6 shells, 90 dmg within 5 m | 1.5 m recoil shove that Jerks the Line |
| The Honker | Oversized gun | Rare | 1.4 m revolver, 1 round, 400 dmg | Recoil launches you 6 m airborne with the Line attached |
| The Longboy | Oversized weapon | Rare | 3 m rifle carried by two adjacent Links, 250 dmg, 8 s reload | Both carriers move at 2 m/s and cannot climb |
| The Ladle | Oversized melee | Rare | 3 m cast iron, 120 dmg, knocks monsters 8 m | 2.5 s swing arc also launches any Link in it |
| Party Popper | Bomb | Common | 3 s fuse, 150 dmg, 4 m radius, throw 15 m | Fuse starts on pickup if you are sprinting |
| Gum Bomb | Sticky explosive | Uncommon | Sticks to anything, remote detonate, 150 dmg, 3 m | Sticks to teammates, hats and the Line; a stuck Link cannot peel it alone |
| SHIFT! Energy | Energy drink | Common | +50% speed 15 s, 110° FOV, screen jitter | 10 s crash at −30% with a yawn (Noise 12 m) that drops your held item |
| Lift Assist Unit | Jetpack | Rare | 2,000 N thrust lifts 3 masses at 4 m/s, 10 s fuel, 0.4 s control lag | Lifts the lightest Link first; spins a Huddle; drops everyone when fuel ends |
| Harpoon Reel | Grappling hook | Uncommon | 25 m line, pulls user at 8 m/s | Pulls 2 Links; a third snaps the line back into your face (10 dmg) |
| Dependable Torch | Flashlight | Common | 20 m cone, 90 s battery, stuns listed monsters | Seen by Lanterns at 60 m; shake to recharge at Noise +6/s |
| Popflare | Flare gun | Uncommon | 3 UV flares, 12 m light, 25 s; repels Lanterns and Darlings, despawns nothing else | Burning carpet or teammate ignites the Line; fire travels 1 m/s to neighbors unless they crouch-spam |
| Squeaky Dennis | Decoy noisemaker | Common | Rubber Dennis head squeaks 20 s, Noise 40 m | Squeaks in your pocket on every ragdoll; also draws Rustmaw |
| Mystery Juice Box | Transformation | Legendary | Random form from the Transformations tables | 10% "Group Plan": the whole Line transforms |
| Spare Nut | Chain | Uncommon | Re-couples a Loose Link in 3 s (needs a second Link) | Can be bolted onto a monster, chaining it to you |
| Slack Jack | Chain | Uncommon | +3 m Give on one segment for 60 s | Ends with a 2 m snap-back Jerk; the Auditor loves it |
| The Cinch | Chain | Rare | Pulls every Link to 1.5 m for 10 s; hauls a dangler up | Everyone collides into a ragdoll pile |
| Anchor Spike | Chain | Uncommon | Pins a cuff to the floor 15 s, Footing 99 | Pinned Link cannot move; the Hook still tries |
| Bungee Nut | Chain | Rare | One segment stretches to 10 m and snaps back for 45 s | Snap-back is 12 m/s, which is ragdoll speed |
| Jumper Cables | Revive | Rare | Clip to Deadweight: revive at 25; 20 dmg shock to any monster on the Line | Every Link takes 10 and a 2 s stagger |
| First-Aid Kit (expired) | Consumable | Common | Heals 50 over 3 s; solo self-revive | 15% chance it is a sticker (heals 1) |
| Air Horn | Noise | Uncommon | Stuns all monsters within 12 m for 2 s | Noise 100 m; deafens Links 5 s |
| Big Red Button | Tool | Uncommon | Opens nearest door / seals all doors / calls elevator / summons the Hook / plays the Birthday Song (20% each) | You never know which |
| Mirror Shard | Tool | Uncommon | Shows true Darlings at 40 m; 2 s stun on a Vacancy | Shows the Coworker behind you |
| Grease Can | Deployable | Common | 4 m slick, zero Footing; Line stops snagging on it | Chain plus slick equals a six-body slide |
| Corporate Umbrella | Mobility | Uncommon | Holder falls at 3 m/s | A second Link on the Line rips it inside out |
| Rolling Chair | Mobility | Common | Sit and roll 5 m/s on flat ground | It is a Roller when you stand up |

### Transformations

Forms last their duration or until Downed. The model swaps; the Line does not scale. The Juice Box rolls a hero form 30%, an animal 70%.

#### Hero Forms
| Form | Duration | Abilities | Effect on the whole chain | Weakness / comedy |
|---|---|---|---|---|
| The Dome (bald one-punch hero) | 20 s | One punch kills any non-boss; bosses lose 25% HP | Immovable (Footing 99): the Line is anchored to a wall that walks | 2 s wind-up; the punch wind knocks every teammate 10 m and deletes the door, wall or floor you needed |
| The Hurry (speedster) | 10 s | 18 m/s, 12 m jumps, phases through Shamblers | Teammates water-ski behind, airborne after 2 s, ragdolling at 9 m/s | Cannot turn sharper than 30°; stops only by hitting something |
| The Lifter (flying strongman) | 15 s | Flies 6 m/s, lifts six Links, 200 dmg throw | The whole Line dangles from one wrist in a 15 m column | Cannot hover; says "I've got you" and lands at 6 m/s, which is a fall |
| Mister Slack | 20 s | Arms extend 10 m to grab ledges and Links | Own segments become elastic to 10 m | Snap-back Jerks neighbors at 2×; cannot hold items |
| Big Lad | 15 s | 4× size, 500 HP, ignores knockback | Everyone hangs from his cuff like keys | Does not fit through any door built so far |

#### Animal Forms
| Form | Duration | Abilities | Effect on the whole chain | Weakness / comedy |
|---|---|---|---|---|
| Snail | 45 s | 0.8 m/s; sticks to walls and ceilings; immune to Jerks | A living Anchor Spike that carries the dangling team straight up any wall at 0.8 m/s | Salt shakers; the trail is Grease; 45 s of screaming teammates |
| Pigeon (bird) | 20 s | Flies 5 m/s; carries 1 Link | Tries to carry five people: each extra Link cuts speed to 0.3 m/s and it sinks 1 m/s, panicking audibly | 20 HP; one Tiny Tomato ends it mid-air |
| Cat | 30 s | Silent (0 Noise), 2× climb, always lands on feet, nine lives (9 free fall-deaths) | The cat lands on its feet; the other five do not | Freezes 2 s to stare at the Custodian's stain; cannot hold items |
| Goat | 30 s | Climbs 70° slopes, headbutt 30 dmg, chews the Chairman's chains in 2 s | Hauls two Links up a slope | Also chews the Line: 4 s of nibbling sets a Link Loose; eats one held item per 10 s |
| Frog | 25 s | 8 m hop, 6 m sticky-tongue grab of items and Links | Every hop Jerks the Line unless Give is 3 m or more | Sticks to the first thing the tongue hits; Lanterns consider it food |
| Elephant | 20 s | 2,000 kg, Footing 99, immune to grabs | Holds the entire Line against anything, including the Hook | Every floor, plank and inflatable chef it stands on fails; cannot climb |
| Bat | 25 s | Echolocation shows monsters through walls at 30 m; flies 3 m/s | Everyone sees what the Bat pings | Flashlights blind it 3 s; idle 2 s and it hangs upside down, inverting the Line |

### Progression

**Currency: Washers.** Earned for new team height (1 per meter, split evenly), Break Rooms reached (25), Unscheduled Events survived (5 each), first-time item pickups (2), level exits (100 / 150 / 200 / 250 / 300), bosses (300 each), and a Clean Shift multiplier (×2 for a level with no Layoff). Washers are team-shared, spent at the Lobby's vending wall, and lost only at 50% on a Layoff. All unlocks are cosmetic; no stat changes.

**Unlock categories:** Line skins (chain skins: visual and audio of the chain), Deez styles (engravings and finishes on the nut), Cuffs and Outfits, Hats (physics), Ballast skins, Scream Packs, Foreman Announcement Packs, Break Room decor and vending faceplates, Emotes (all two-Link: high-five, trust fall, the Conga).

**Example unlocks:** Glow Stick Line (chain glows, visible to Lanterns at 80 m); Spaghetti Line (floppy, wet-noodle physics audio); Deez: Gold-Plated; Scream Pack: Opera Tenor; Ballast skin: Wedding Edition Ball and Chain; Hat: Traffic Cone; Outfit: Employee of the Month (Dennis's shirt).

### Do-Not List

- **No trademarked games, characters, franchises or their distinctive terms** anywhere in design text: not the liminal-office creepypasta, the animatronic night-guard franchise, the rooftop-parkour zombie series, the rope-tether climbing game, the bald one-punch manga hero, the red speedster, or the flying strongman. The only exception is the Comparables row of the overview fact sheet.
- **No explicit content.** Darlings and Madame Velluto are never sexualized: no nudity, no leering camera, no suggestive dialogue, no body-focused descriptions. They are fully dressed, polite, ordinary people until the Turn.
- **The title joke is a product slogan and a hex nut.** Never extend it into genital humor, never have a character explain it, never put it in the Foreman's mouth as a punchline.
- **Monsters are never the joke.** No quips, no slapstick kills, no cute idle animations, no monster that stops being scary on repeat.
- **No sarcastic or quippy UI.** The Foreman is deadpan, not snarky, and never winks.
- **No mean-spirited humor:** nothing targeting bodies, disabilities, gender, race, sexuality, accent, skill or real people. Dennis is loved, not mocked.
- **No gore for its own sake:** grab-kills cut to black; Deadweight is a limp ragdoll, not a corpse model; no dismemberment of player bodies.
- **No human children in the world.** Tiny Tomato is a machine and reads as one.
- **No real brands, logos, songs, celebrity likenesses or real city names.** DEEZ Industrial Fasteners, Pappy Pepperoni's, Carrow Heights and Hotel Velluto are the only companies and places.
- **No strobe above 3 Hz**; every flicker needs a photosensitivity toggle.
- **No fail state that requires an open microphone.** Noise must be earnable by movement alone; push-to-talk is honored.
- **No placeholder text, no "TBD," no numbers left to tuning without a starting value.**
- **Nothing that works without the Line.** If a set piece, item or threat plays the same solo and unchained, redesign it.
