# Enemies

One script per monster, all original designs, all simulated on the server with replicated state and visuals that run on every peer. Every monster that hunts a player exposes `hunt_peer` and `is_hunting()`, sits in group "monster", and answers `blast()` (a bomb went off) and `release(killed)` (let go of whoever it holds). Kills send the whole group back to the checkpoint through the level's `request_layoff`.

- `custodian.gd`: Level 1. One per office floor, blind, hunts by sound in the plenum, lifts a still player through the ceiling. Countered by the Line (bracing teammates), a flashlight, two pistol hits or a blast. Also in group "custodian" (the lights dim near it).
- `pappy.gd`: Level 2. Pappy Pepperoni, the chef animatronic. Walks the floor the Line is on, one node per Step, only while unobserved (no player's view cone with line of sight, no live camera on his node). Lunges and grabs the nearest player within reach. A held shutter stops him for three bangs. Countered by eyes, cameras, shutters, the air horn (stun), the party popper (one node back) and a flashlight in his face while he holds someone. Guns do nothing.

Rules from `CLAUDE.md`: original designs only, server-simulated, reacts to player noise, and the chain must be part of the counter.
