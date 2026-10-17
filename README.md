# CHAINS DEEZNUTS TOGETHER

1–6 player co-op horror-comedy. You are chained to your friends. Climb out of the building. Don't let them see you.

This build is **Levels 1 and 2 of 5 and the first block of Level 3: The Yellow Rooms, then Pappy Pepperoni's Night Shift**, a haunted family pizzeria stacked on top of the office, **then the roof**, where a thousand infected are waiting. Play it solo (you're chained to the Ballast, a 35 kg iron nut with a smiley face) or with up to 5 friends online.

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
| Shift, then Ctrl | Slide: a sprint plus Ctrl drops you into a slide that carries for a second. Fits under low things, dodges a lunge, and yanks whoever you're chained to |
| Space | Jump; jump into a ledge to climb it |
| F or left click | Use the item in your hands |
| 1 / 2 / 3, mouse wheel | Pick which of your three items you hold |
| G | Drop the item in your hands (hand it to a teammate) |
| T | Reload the Snubby |
| R | Auto-walk on/off |
| V | First / third person (also a Camera option in Settings; the game remembers your choice) |
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
- **The Hollow Hires walk the route.** Two or three per floor, in vests, with no faces, and they keep to the rooms the green signs send you through. At the end of a walk one stops and turns slowly through a half circle, looking: standing still in front of it is a gamble. One that sees you screams, the lights gutter, and every other Hire on the floor answers and comes running. Crouching makes you harder to spot (not invisible; good for slipping behind one); a lit flashlight makes you easy to spot. Loud noises bring them over to look. Break rooms are safe: they stop at the door.
- **The route is loud, on purpose.** B4 and B1 have a jammed door on the way that only opens if you sprint into it, with a bang the whole floor hears. B3's service lift is locked out until someone pulls the fire alarm (hold Ctrl at the red box): the klaxon runs 40 seconds and every Hire on the floor is awake and hunting for all of it. B2's shelf shaft is under a steel hatch; its release switch is two rooms back and gives you 25 seconds before it slams, so the whole chain runs. On B1, stepping into the elevator room brings one through the door behind you. Nothing on these floors can be crouch-walked.
- **It's dark.** The office runs on dying tubes. Every minute or so the power on your floor stutters out for 12 to 20 seconds; the break rooms keep their lights and the green signs still glow, so you can see where to go, but not what's between you and it. That is what the flashlight is for (and a lit flashlight is what they see).
- **Fight or run.** A flashlight held in its face stuns it for a moment (then it's wise to the trick for a few seconds); two Snubby rounds or a bomb drop it, and the floor sends another one in after a while from somewhere you aren't looking. Sprinting outruns it, loudly.
- **If one grabs someone**, everyone near them should hold Ctrl to brace, or put a light in its face, or shoot it. Nobody comes in a few seconds and the whole team is sent back to the last break room.
- **The cable tray** on B4 is a narrow optional ledge with a stash at the end. One at a time; the chain decides who falls.
- **Throw Squeaky Dennis** and every Hire on the floor walks over and stands staring at him for as long as he squeaks (eight seconds): that's your window past them. The bomb launches everyone nearby, including the people you're chained to.
- **A dangling teammate drags you toward the edge** unless you brace or keep walking to hoist them.

### The Night Shift (Level 2)

- **Pappy Pepperoni only moves while nobody is looking at him and no camera shows him.** Someone keeps eyes on him; the rest move. The top-right panel tells you whether he's pinned and how long until his next step.
- **Cameras:** stand on the painted spot at a security desk (Host Stand, Manager's Office, Sound Booth) and F flips cameras. A camera showing his room pins him too. Cameras drain the power bank; at 0% the lights go out, the lift locks and nothing stops him. Stand in a break room for a few seconds to restart the generator.
- **Shutters:** hold Ctrl at the pull chain to keep the EMPLOYEES ONLY shutter down. He bangs three times and goes back to his end of the floor. That's your window. **Let go while he's banging and he comes through at a run**, eyes or no eyes: RUN for a break room or the freezer. The same happens for as long as the power is out.
- **The dumbwaiter** takes one rider; someone holds Ctrl at the hand rope to haul. Solo, step in and hold Ctrl. **The stage lift** runs while someone holds Ctrl at the lever (it locks when you're alone); three ride, the last one gets hoisted up on the chain. The game tells you why a lift isn't moving (overloaded, no power).
- **If he grabs someone:** air horn (stuns him), party popper (shoves him back a room), or a flashlight in his face or chest (the HUD counts the light up). Guns do nothing. The walk-in freezer is safe.
- **The goal:** get everyone onto the PROP LOFT at the back of the stage (ROOF ACCESS). Dining Hall: cameras, shutter, dumbwaiter up. Kitchen: the stage lift up. Stage: cross it, climb the speaker case onto the loft. The checklist under the objective tracks each step, and the game counts "3 of 4 on the loft" until the last one is up.
- **The fly rail** off the loft's left end is an optional run of hanging planks over the band, with a stash at the gallery. A slip yanks whoever is chained to you.

### A new building every run

The office maze is laid out from a random seed every time you press PLAY SOLO or HOST: different rooms, different route, the pizzeria dressed differently. Friends who join are handed the host's layout automatically (they reconnect once while it builds, a second or two).

### The roof: Carrow Heights (Level 3, first block)

Level 3 is the infected city, and its first block is the roof of the building: when everyone is on the pizzeria's prop loft, the hatch opens and the whole Line climbs out onto a loading lot in the sky, with the city all round it and a long way down over the parapet. The top-right corner shows the swarm count. To start there straight away, click the START button on the title screen until it says THE ROOF, then PLAY SOLO or HOST (`PLAY THE LOT (horde test).bat` opens the title with it selected). Friends join the usual way and get whatever the host chose.

**The way out is a helicopter.** Over the fence (the dumpster, or a teammate's head), through the gap in the wall, then up the fire escape on the tower in the corner: ledge by ledge, walk into each one and tap Space. On the helipad, someone has to stand on the pad for thirty seconds while the pilot spins her up, then everyone aboard. That's the end of this build: next stop Level 4.

**What came out of the walls**, in rounds:

- **Roaches**, knee-high and hundreds of them, as fast as you walk. They bunch at the gap and climb each other into a wall. Stand in the swarm and three sets of mandibles pull you down in a few seconds. Walk, don't stand; sprint when it's close.
- **Weavers**, spiders the size of dogs, faster than you. They come when you reach the gap. They hang on the chain: one on your chain and you can still sprint, and the sprint flings it off; three on one length and that pair is stopped until you shoot them off, bomb them, hit the air horn, or a teammate on another length sprints away so the chain snaps taut. A slide throws them off too.
- **Flitters**, bats with a two-metre span, come when the first of you reaches the helipad. Walls mean nothing to them; they circle overhead and dive. Only a gun stops them. Hold the pad anyway.
- **The Jumper**, a spider the size of a sofa, screeches and coils, then jumps five or six metres at wherever you were standing. Sprint or slide out of that line and it lands on nothing. If it pins someone: everyone beside them holds Ctrl, or a flashlight in its eyes, the air horn, or two shots. Three shots or a bomb kill it.
- **Distractions work:** the squeaky decoy pulls the swarm to it, the air horn scatters whatever is near.

**Mind the edge.** The roof has a knee-high parapet and the street is a long way down. Going over it is a layoff, unless whoever you're chained to braces in time.

## Tests

`RUN TESTS.bat` plays through both levels by script, headless: solo, then the Loading Lot, then a host and a client over the network. See `CLAUDE.md` for details.
