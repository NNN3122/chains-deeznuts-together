# CHAINS DEEZNUTS TOGETHER — project guide

Read this before touching anything. It captures the full vision so every session builds toward the same game, and the rules that keep the codebase coherent.

## What this game is

A 1–6 player online co-op horror-comedy. Players are physically chained together and must cooperate to climb upward through stacked horror levels and escape at the top. The tone is chaotic and stupid-funny, but the horror is real: tense atmosphere, monsters that kill you, and lots of jump scares. The rhythm is: scream, then laugh.

- **Camera:** toggle first-person / third-person at any time (key V).
- **Chains:** physics-based. One player falling, jumping, or panicking pulls the others. Falling drags teammates down. Dying sends the whole group back to the last checkpoint. Chain topology changes with player count (line, ring, pairs).
- **Levels, stacked vertically (bottom to top):**
  1. Liminal yellow office maze — buzzing fluorescents, shifting layouts, an entity you hear but rarely see.
  2. Abandoned pizzeria — possessed animatronic mascots; manage doors, cameras and power while climbing.
  3. Infected rooftop city — rooftop parkour; slow infected by day, fast lethal hunters at night.
  4. Seductive hotel — dim luxury; succubi lurk (see Enemies).
  5. Final mashup ascent — every zone remixed, ending in a boss chase to the exit.
- **Items ("go stupid with it"):** random loot. Guns (pistol, shotgun, ridiculous oversized weapons), bombs and sticky explosives (hurt monsters and teammates alike), energy drink (speed boost, jittery screen, then a crash), jetpack (lifts the whole chain, hard to control), grappling hook, flashlight, flare gun, decoy noisemaker, and a rare **Transformation item** that turns a player into an original superhero archetype (bald one-punch hero, speedster, flying strongman) or an animal (snail: slow, sticks to walls; bird: flies but weak; cat: silent, lands on feet, nine lives). Transformations affect the whole chained team in funny ways (a bird trying to carry five people).
- **Enemies:** every level has its own monster plus roaming threats. Items can fight, stun, distract, or help escape them. Monsters react to noise. Boss encounters end select levels.
- **Succubi:** from a distance they look like friendly women calling for help; when a player gets close they transform into demons and attack. Observant players can spot subtle tells (glitchy audio, wrong reflections, flickering or wrong shadows). Strictly non-explicit: the horror is the betrayal and the transformation.
- **Horror:** scripted jump scares plus randomized/procedural scares so repeat runs stay unpredictable. Proximity voice chat later; monsters hear player noise (including microphones, eventually).
- **Originality:** all characters, monsters, heroes, mascots and names are original designs. Never copy or name existing franchises or characters in code, assets, or text.

The full game design document is `design/GAME_DESIGN_DOCUMENT.md`. Treat it as the reference for names and numbers; this file is the short version.

## Engine and architecture rules

- **Godot 4.3+ with GDScript** (developed and tested on 4.7.2). Static typing everywhere. Tabs for indentation.
- **Multiplayer:** Godot high-level multiplayer. Solo uses `OfflineMultiplayerPeer` (same server code path, no sockets); co-op uses `ENetMultiplayerPeer`. **Host-authoritative:** the host (peer 1) simulates all bodies, the chain, items, monsters and triggers; clients send input by RPC and render replicated state. Built for 6 players; never special-case "2 players".
- **Assets:** CC0 textures live in `assets/textures/` with their sources in `assets/textures/LICENSE.md` (ceiling tiles and carpet from TextureCan, mapped in world space by `LevelKit` shaders, carpet recoloured blue to mustard). Everything else is built in code: shader materials (`LevelKit`), primitive models (`PlayerModel`, `ItemModels`), synthesized sounds (`Sfx`), system fonts (`UiTheme`). Only download new assets with the user's explicit OK, CC0 or similar only, and record each one in the LICENSE file. Texture imports: VRAM compressed, mipmaps on, normal maps flagged as normal maps.
- **Folders** (each system grows without touching the others):
  - `src/core/` main flow, `GameState` autoload (run state + input map), `Settings` (static, saved to user://settings.cfg)
  - `src/net/` `Net` autoload: solo / host / join, spawners for players, pickups and thrown objects, the Ballast switch
  - `src/player/` `Player` (controller, noise, grab state), `PlayerInput` (remote-desktop-proof input), `PlayerModel`
  - `src/chain/` `ChainBody` base, `Ballast` (solo partner), `ChainSystem` (topology, ledge wrapping, pull, hang drag, link rendering, jerks)
  - `src/items/` data-driven items: one `ItemData` .tres per item in `data/` plus a logic script extending `ItemBase`; `ItemRegistry` finds them; `ItemPickup`, `Thrown`, `ItemModels`
  - `src/enemies/` `Custodian` (ceiling monster per floor, hunts by sound, lifts victims; the chain is the counter)
  - `src/levels/` `YellowRooms` (Level 1 generator), `LevelKit` (materials, environment, `BoxBatch`), `LightController`, plate, lift, checkpoint
  - `src/scare/` `ScareDirector` autoload (scripted + procedural scares), `ScareTrigger`
  - `src/fx/` `Effects` (RPC visuals and sounds the server triggers on every peer)
  - `src/audio/` `Sfx` (procedural sound bank; silent when headless)
  - `src/ui/` title, settings, pause, end screen, HUD, `ScreenFx` post shader, menu backdrop, `UiTheme`
  - `tests/` smoke test and screenshot tour, loaded by path only with `--smoke` / `--shots`
  - `tools/` (ignored by Godot) `make_friend_zip.ps1`, `publish_release.ps1`, `write_licenses.gd`, and `friend_package/` (the READ ME shipped in the zip, HOW TO SEND for the user)
- **Items are data-driven:** adding an item = one `.tres` in `src/items/data/` + one logic script + a model case in `ItemModels`. Nothing else changes.
- **Levels are generated from a fixed seed** so every peer builds the identical world before connecting. Replicated props need identical node names on all peers.
- **Physics layers:** 1 world, 2 chain bodies (players, Ballast), 4 thrown, 8 monster hitboxes. Areas that detect players use mask 2.
- **Server-only logic** is guarded by `multiplayer.is_server()`; anything clients see is pushed with `call_local` RPCs or replicated properties.
- **Autoloads:** `GameState`, `Net`, `ScareDirector` only.
- **The user plays over TeamViewer.** TeamViewer sends a held key as a stream of taps and breaks captured mouse look. Movement must never depend on mouse capture; keys are bound by physical code AND key label; Remote Controls mode (auto-on when TeamViewer is running or key flicker is detected) holds keys for 650 ms after each tap. Its mouse look hides the cursor and confines it to the window (`MOUSE_MODE_CONFINED_HIDDEN`), with no button to hold: plain movement turns the view, and holding the cursor in the outer 7% of the window keeps turning, since a remote cursor stops at the edge of the user's own screen. The user rejected right-drag look ("like all games"); don't bring it back. Arrow keys walk/turn and R toggles auto-walk in every mode.
- Keep the chain central: a mechanic, item or level piece that would play the same without the chain is wrong for this game.

## Status

- **Milestone 1 (done):** chain prototype on a greybox tower, now superseded by Level 1.
- **Level 1 vertical slice (done, tested):** The Yellow Rooms, 4 floors (B4 to B1) of generated offices. Ascents: crates through a ceiling hole; plate + lift + chain hoist; a shelf shaft (stand on a teammate's head or use the jetpack); freight elevator exit. A Custodian per floor. Six items: flashlight, pistol, energy drink, decoy, bomb, jetpack. Scripted and procedural scares. Solo play with the Ballast. Title, settings, pause, end screen, HUD, post-processing.
- **Realism pass (done):** articulated procedural character (pelvis, spine, two-bone limbs, distance-driven gait, spring landings, head look); render-rate interpolation between physics ticks (`Player._visual_position`); camera spring follow, landing dip, strafe roll, run FOV kick; eased keyboard turning; SDFGI bounce light, soft PCSS shadows, auto exposure; troffers, doors, EXIT signs, vents, outlets, office chairs, monitors, cabinets, plants. Real CC0 ceiling-tile and carpet textures (TextureCan) applied with procedural stains on top.
- **Readability and feel pass (done):** green route signs ("SERVICE LIFT / THIS WAY") over path doorways, built by `YellowRooms._wayfinding`; one-time HUD hints at each climb (`Hud.HINTS`, co-op and solo wording); directional sound captions (`Sfx.CAPTIONS` routed to the "hud" group, Custodian movement captions); brightness slider, sound-caption and FPS toggles in Settings; pause-menu "Stuck? Regroup" (`GameState.request_regroup` to `YellowRooms.regroup`, 15 s cooldown, no wipe counted); hard hats that pop off on grabs, hard landings and blasts (`PlayerModel.pop_hat`).
- **Next:** Level 2 (The Pizzeria Night Shift), proximity voice, client-side prediction for remote players, standalone .exe export (needs Godot export templates, about 1 GB).

## Running and testing

- Double-click `PLAY.bat` or the desktop shortcut. `PLAY 2 WINDOWS (co-op test).bat` opens a host and a client side by side. `RUN TESTS.bat` runs the smoke tests.
- **Sharing with friends:** `MAKE FRIEND ZIP.bat` runs `tools/make_friend_zip.ps1`. It writes `CHAINS DEEZNUTS TOGETHER - send to friends/` on the Desktop:
  - the zip: the official Godot exe renamed to `CHAINS DEEZNUTS TOGETHER.exe`, a `.pck` of the same name (Godot auto-loads it), READ ME and LICENSES;
  - the bare `.pck`, for updates;
  - `HOW TO SEND.txt`.

  The pck comes from `--export-pack "Windows Desktop"` (`export_presets.cfg`), which needs no export templates. `script_export_mode=0` keeps scripts as text so `Net.get_build_id()` (a SHA-256 of `res://src/**/*.gd`) matches between source and pck; joiners with another build are turned away with a message. Keep `.bat` files CRLF.
- **GitHub:** public repo `NNN3122/chains-deeznuts-together`, pushed with the user's `gh` login. `PUBLISH UPDATE TO GITHUB.bat` runs `tools/publish_release.ps1`, which builds the friend zip, commits and pushes, and creates release `vN+1` with the zip as `CHAINS-DEEZNUTS-TOGETHER.zip`. Friends use `releases/latest/download/CHAINS-DEEZNUTS-TOGETHER.zip`, the link at the top of README. The repo is public: never commit real IP addresses, emails or anything else personal. Commits use the GitHub noreply email (local git config).
- **Invites:** hosting (not headless) runs `PortOpener`, which uses UPnP on a thread: discover, add a UDP mapping with a 4 h lease renewed hourly, then query the public IP. The mapping is removed on leave and quit. `InviteCode` turns the public IPv4 into a 7-character base-32 code (`XXXX-XXX`, plus `-PORT` when not 7777). The JOIN box accepts a code, a pasted message containing one, `IP[:port]` or a host name. Never let tests touch the router: `Net._begin_invite` skips UPnP when headless. Fallbacks shown in the Esc menu: LAN and Tailscale addresses (Tailscale is installed on the user's PC).
- **New `class_name` scripts:** run `godot --headless --path . --import` once so the global class cache knows them, before a plain headless run.
- Command-line flags (after `--`): `--solo`, `--host`, `--join=IP`, `--port=N`, `--name=X`, `--remote` / `--no-remote`, `--fake-build=X` (tests the version check). Add `--position 12000,12000` before `--` for windowed screenshot runs so the user can't click the window mid-tour. The Godot console binary is `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`; the `godot` alias was not created (needs admin).
- **Smoke tests (run after every change):**
  - Solo: `godot --headless --path . --max-fps 60 -- --solo --smoke` (39 checks; co-op host 37, client 8)
  - Co-op: `godot --headless --path . --max-fps 60 -- --host --port=7791 --smoke --smoke-players=2` together with `godot --headless --path . --max-fps 60 -- --join=127.0.0.1 --port=7791 --smoke-client`
- **Visual check:** `godot --path . --resolution 1280x720 -- --no-remote --shots=DIR` saves a screenshot tour (needs a real window); `--title-shot=FILE` saves the title screen. Look at the PNGs after visual changes.
- `godot --check-only --script <file>` reports false "Identifier not found" errors for autoloads; use a real headless run instead.
- GDScript gotcha: generic `floor()`, `abs()`, `min()` return Variant, so `var x := floor(y)` fails to compile. Use `floorf`, `absf`, `minf`.
- Headless runs use the dummy audio driver, which never releases played streams; `Sfx` skips playback when headless.

## Conventions

- One class per file, `class_name` for anything referenced by type. File names in `snake_case`, class names in `PascalCase`.
- Signals over polling for UI; polling is fine inside physics ticks.
- Constants for tunables at the top of each script with a short comment on the unit (meters, seconds, m/s).
- Comments explain intent and gotchas, not what the line does.
- Keep `CLAUDE.md` current when the architecture or status changes.

## Working with Claude on this repo

- Keep background agents and multi-agent workflows small. Do work inline by default and ask before any agent fan-out; the user has hit usage limits from large background runs.
