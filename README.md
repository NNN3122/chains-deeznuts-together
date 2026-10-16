# CHAINS DEEZNUTS TOGETHER

1–6 player co-op horror-comedy. You are chained to your friends. Climb out of the building. Stay quiet: something lives in the ceiling.

This build is **Levels 1 and 2 of 5: The Yellow Rooms, then Pappy Pepperoni's Night Shift**, a haunted family pizzeria stacked on top of the office. Play it solo (you're chained to the Ballast, a 35 kg iron nut with a smiley face) or with up to 5 friends online.

## Download and play (Windows)

**[Download the latest version](https://github.com/NNN3122/chains-deeznuts-together/releases/latest/download/CHAINS-DEEZNUTS-TOGETHER.zip)**

1. Unzip it: right-click the zip, then "Extract All...".
2. Double-click **CHAINS DEEZNUTS TOGETHER.exe**. There's nothing to install. If Windows says "Windows protected your PC", click "More info", then "Run anyway".

**Playing together:** one person clicks HOST CO-OP, presses Esc, clicks COPY INVITE and sends the code (like `K7QM-2XR`) to everyone else. Everyone else clicks JOIN CO-OP, PASTE, CONNECT. Friends can join mid-run, and everyone needs the same version: when there's an update, download the zip again from the same link.

While you host, the game asks your router (UPnP) to let friends in, and closes it again when you leave. You can switch this off in Settings. If the Esc menu says "NO CODE", your router or internet provider is blocking it. Friends in the same house can still join with the Wi-Fi address shown there; over the internet, use Tailscale.

## Running from source

- Needs Godot 4.7 (`winget install GodotEngine.GodotEngine`). Double-click `PLAY.bat`. `PLAY 2 WINDOWS (co-op test).bat` opens a host and a client side by side.
- **Publishing an update for friends:** double-click `PUBLISH UPDATE TO GITHUB.bat`. It builds the game, pushes the source and creates the next release, so the download link above serves the new version. `MAKE FRIEND ZIP.bat` only builds the zip, into `CHAINS DEEZNUTS TOGETHER - send to friends` on the Desktop.

## Controls

| Key | Action |
|---|---|
| WASD | Move |
| Up / Down arrows | Walk forward / back |
| Left / Right arrows, Q / E | Turn |
| Mouse | Look. Over TeamViewer, hold the mouse against the side of the window to keep turning |
| Shift | Run (loud) |
| Ctrl or C | Crouch: brace the chain, sneak quietly, fit under low things |
| Space | Jump; jump into a ledge to climb it |
| F or left click | Use the item in your hands |
| 1 / 2 / 3, mouse wheel | Pick which of your three items you hold |
| G | Drop the item in your hands (hand it to a teammate) |
| T | Reload the Snubby |
| R | Auto-walk on/off |
| V | First / third person |
| H | Show / hide controls |
| Esc | Pause, invite code, settings, regroup, leave |

**Playing over TeamViewer or another remote desktop?** Remote Controls fix held keys and mouse look. They switch on automatically when TeamViewer is running, and you can toggle them in Settings.

**Too dark?** Settings has a Brightness slider, sound captions (on by default: they tell you what you heard and from which side) and an FPS counter. Back-of-house rooms are meant to be dark: that is what the flashlight is for.

**Voice chat:** just talk. Friends within about 20 m hear you, quieter with distance and muffled through walls. Settings has the microphone switch and a volume for friends' voices.

**Your three items:** the HUD shows three slots. Walk into an item to take it (a fourth is refused until you drop one with G). The Snubby holds 6 rounds with 12 in the pocket; T reloads, and ammo boxes pour into the pocket.

## How to survive

- **Climb up through four floors**, from B4 to B1: crates through a hole in the ceiling, a service lift someone has to hold the plate for, a shelf shaft too tall to climb alone, then the freight elevator. Everyone has to be inside: it rides you up into the pizzeria.
- **Follow the green "THIS WAY" signs** over doorways, and the checklist under the objective (top left): it ticks off as you do things. A hint pops up the first time you reach each climb.
- **Lost or stuck?** Esc, then "Stuck? Regroup" pulls the whole team back to the last break room. It doesn't count as a death.
- **The Custodian hunts by sound.** Running, gunshots, landing hard, jetpacks and a yanked chain are loud. Walk, or sneak with Ctrl. But don't camp: standing still in one spot for a few seconds (crouched or not) brings it over to look. Break rooms are safe.
- **If it grabs someone**, everyone near them should hold Ctrl to brace. Or shine a flashlight at it, at the arm, or at the person it's lifting: the HUD shows "LIGHT ON IT" counting up, and at 100% it lets go. Or shoot it twice.
- **The cable tray** on B4 is a narrow optional ledge with a stash at the end. One at a time; the chain decides who falls.
- **Throw the squeaky decoy** to send it somewhere else. The bomb launches everyone nearby, including the people you're chained to.
- **A dangling teammate drags you toward the edge** unless you brace or keep walking to hoist them.

### The Night Shift (Level 2)

- **Pappy Pepperoni only moves while nobody is looking at him and no camera shows him.** Someone keeps eyes on him; the rest move. The top-right panel tells you whether he's pinned and how long until his next step.
- **Cameras:** stand on the painted spot at a security desk (Host Stand, Manager's Office, Sound Booth) and F flips cameras. A camera showing his room pins him too. Cameras drain the power bank; at 0% the lights go out, the lift locks and nothing stops him. Stand in a break room for a few seconds to restart the generator.
- **Shutters:** hold Ctrl at the pull chain to keep the EMPLOYEES ONLY shutter down. He bangs three times and goes back to his end of the floor. That's your window. **Let go while he's banging and he comes through at a run**, eyes or no eyes: RUN for a break room or the freezer. The same happens for as long as the power is out.
- **The dumbwaiter** takes one rider; someone holds Ctrl at the hand rope to haul. Solo, step in and hold Ctrl. **The stage lift** runs while someone holds Ctrl at the lever (it locks when you're alone); three ride, the last one gets hoisted up on the chain. The game tells you why a lift isn't moving (overloaded, no power).
- **If he grabs someone:** air horn (stuns him), party popper (shoves him back a room), or a flashlight in his face or chest (the HUD counts the light up). Guns do nothing. The walk-in freezer is safe.
- **The goal:** get everyone onto the PROP LOFT at the back of the stage (ROOF ACCESS). Dining Hall: cameras, shutter, dumbwaiter up. Kitchen: the stage lift up. Stage: cross it, climb the speaker case onto the loft. The checklist under the objective tracks each step, and the game counts "3 of 4 on the loft" until the last one is up.
- **The fly rail** off the loft's left end is an optional run of hanging planks over the band, with a stash at the gallery. A slip yanks whoever is chained to you.

## Tests

`RUN TESTS.bat` plays through both levels by script, headless: solo, then a host and a client over the network. See `CLAUDE.md` for details.
