# Bug My Brother!

An *Interactive Buddy*-style prank game made in **Godot 4.7.2**. Your big brother is always mean to you, so here are **10 places to get him back**. It's mostly cartoon slapstick: pies, water balloons, whoopee cushions and crabs (the post-game unlock is a realistic handgun, so it isn't for young kids).

**Play in your browser:** https://username846.github.io/mean/

## The 10 locations

| # | Place | What you do |
|---|-------|-------------|
| 1 | **Living Room** | A ragdoll sandbox like Interactive Buddy. Grab and fling him into walls, poke him, tickle him with a feather, bonk him with bouncy balls, and hide a whoopee cushion for him to land on. If you shake him around, he gets dizzy. |
| 2 | **Kitchen** | Throw cream pies at his face while he dodges behind the counter. Watch out for his frying-pan shield. |
| 3 | **Backyard** | Pull back a slingshot and lob water balloons at him. He has an umbrella. |
| 4 | **Bedroom** | Draw on his sleeping face with a pen, a marker and stamps (mustache, glasses, whiskers, unibrow). Keep the noise down when he stirs, then wake him up and hand him a mirror. |
| 5 | **Game Room** | He's fighting a video-game boss. Pull the plug at the worst moment. The closer he is to winning, the madder he gets. |
| 6 | **Cafeteria** | Build him a disgusting sandwich (ghost pepper sauce, old sock, gummy worms...). He checks the top layer, so hide the gross stuff under some lettuce! |
| 7 | **Snow Park** | Snowball whack-a-bro. Don't waste throws on the snowmen, and wipe his snowballs off your screen. |
| 8 | **Beach** | Bury him in sand before the waves wash it away, then bring the crab. |
| 9 | **Treehouse** | He's reading comics in his treehouse. Shake the tree, pelt him with acorns, or send a squirrel after him. |
| 10 | **Carnival** | Hit the bullseye with your wobbly aim to drop him into the dunk tank. |

Works on **PC (mouse)** and **phones/tablets (touch)**: tap where you'd click, and drag where you'd drag. Hold your phone sideways. The title screen has a **Fullscreen** button (bottom-left) and a **volume** button (top-right).

Fill his **BRO RAGE** meter in a location to earn its star. Get all 10 stars to see the ending. You also collect *mean points* that move you up the ranks, from "Innocent Angel" all the way to "LEGENDARY Little Sibling". Your progress saves automatically in the browser.

### Secret hospital trips

Each location also hides one way to *seriously* hurt him by accident. That sets off an emergency: Mom yells for an ambulance, it races to the hospital, and you see him bandaged up in bed (the doctor says he'll be okay). The map shows a red cross on every location where you've found it.

<details><summary>Spoilers: how to find all 10</summary>

1. **Living Room:** smash him into the walls too many times.
2. **Kitchen:** hit the cupboard right above his head with a pie.
3. **Backyard:** hit the tree with a balloon while he's standing under it.
4. **Bedroom:** after he wakes up, draw on his eyes.
5. **Game Room:** click the TV.
6. **Cafeteria:** put two or more Ghost Pepper Sauces in his sandwich (with a normal topping on top).
7. **Snow Park:** pack a rock into your snowball, then hit him with it.
8. **Beach:** keep pouring sea water on his face while he's buried.
9. **Treehouse:** hit him with an acorn while he's climbing up or down the ladder.
10. **Carnival:** hit the sign above him 4 times.

Bonus: during the ambulance ride, tap one of its wheels.

**After all 10:** he gets his revenge and trashes your room (RIP, LEGO castle). Then you sneak out at night and buy a **9mm pistol** from a shady dealer. From then on, every location has a pistol button in the bottom-right. Equip it and tap him for the Code Red emergency. This time he doesn't make it: the family waits outside surgery, the doctor comes out to say he's sorry, and it ends at his grave. From then on he's gone for good: the title, the map and all ten places are empty and quiet (only **Reset progress** brings him back).

</details>

## Audio

* **Synthesized voices:** all 113 voice lines (the brother, you, an announcer, Mom, a paramedic, a doctor and a shady dealer) are synthesized with `espeak-ng`. They have speech-bubble subtitles.
* **Music:** each location has its own procedurally composed chiptune track, plus tracks for the menu, the hospital, the cutscenes and the ending (17 in total).
* **Sound effects:** 60 procedurally generated sounds (splats, splashes, boings, sirens and, yes, a whoopee cushion).

Audio starts after your first click or tap, because browsers require that. On iPhone, the ring/silent switch has to be on ring to hear web audio. iPhone Safari doesn't support fullscreen for web pages, so the Fullscreen button is hidden there.

## Project layout

```
project.godot / main.tscn   Godot project (renderer: Compatibility, for the web)
scripts/game.gd             Autoload: audio, volume, fullscreen, saving, screens, UI theme
default_bus_layout.tres     Audio buses (must be defined here, not in code, to play on the web)
scripts/bro.gd              The brother: procedurally drawn puppet with 13 moods
scripts/minigame.gd         Base class for locations (rage meter, scoring, HUD)
scripts/scenes/*.gd         The 10 locations
scripts/lines.gd            Voice-line subtitles (generated)
assets/music|sfx|voice      Generated audio (.ogg)
tools/gen_*.py              The audio generators (numpy + ffmpeg + espeak-ng)
tools/export_web.sh         Rebuilds the browser version into docs/
docs/                       The exported web build that GitHub Pages serves
```

All art is drawn in code with Godot's `_draw()`, so the game has no image assets.

## Turning on GitHub Pages (one-time)

The playable build lives in `docs/`. To publish it, open the repo's **Settings → Pages**. Under *Build and deployment*, set **Source: Deploy from a branch**, **Branch: `main`**, **Folder: `/docs`**, and click **Save**. After a minute or so, the game will be live at the link above.

The build has threads turned off, so it runs on GitHub Pages without any special server headers.

## Rebuilding

```bash
# regenerate audio (optional): needs python3 + numpy, ffmpeg, espeak-ng
python3 tools/gen_music.py
(cd tools && python3 gen_sfx.py)
python3 tools/gen_voices.py

# export the web build into docs/: needs Godot 4.7.2 + its export templates
./tools/export_web.sh
```

To open the project in the editor, use Godot 4.7.2 and press F5 to play.
