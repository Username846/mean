# Bug My Brother!

An *Interactive Buddy*-style prank game made in **Godot 4.7.2**. Your big brother is always mean to you, so here are **10 places to get him back**. It's all cartoon slapstick: pies, water balloons, whoopee cushions and crabs.

**Play in your browser:** https://username846.github.io/mean/

## The 10 locations

| # | Place | What you do |
|---|-------|-------------|
| 1 | **Living Room** | A ragdoll sandbox like Interactive Buddy. Grab and fling him into walls, poke him, tickle him with a feather, bonk him with bouncy balls, and hide a whoopee cushion for him to land on. If you shake him around, he gets dizzy. |
| 2 | **Kitchen** | Throw cream pies at his face while he dodges behind the counter. Watch out for his frying-pan shield. |
| 3 | **Backyard** | Pull back a slingshot and lob water balloons at him. He has an umbrella. |
| 4 | **Bedroom** | Draw on his sleeping face with markers and stamps (mustache, glasses, whiskers, unibrow). Keep the noise down when he stirs, then wake him up and hand him a mirror. |
| 5 | **Game Room** | He's fighting a video-game boss. Pull the plug at the worst moment. The closer he is to winning, the madder he gets. |
| 6 | **Cafeteria** | Build him a disgusting sandwich (ghost pepper sauce, old sock, gummy worms...). He checks the top layer, so hide the gross stuff under some lettuce! |
| 7 | **Snow Park** | Snowball whack-a-bro. Don't waste throws on the snowmen, and wipe his snowballs off your screen. |
| 8 | **Beach** | Bury him in sand before the waves wash it away, then bring the crab. |
| 9 | **Haunted Attic** | Hide in the dark. He creeps past with a flashlight, so jump-scare him up close without getting spotted. |
| 10 | **Carnival** | Hit the bullseye with your wobbly aim to drop him into the dunk tank. |

Fill his **BRO RAGE** meter in a location to earn its star. Get all 10 stars to see the ending. You also collect *mean points* that move you up the ranks, from "Innocent Angel" all the way to "LEGENDARY Little Sibling". Your progress saves automatically in the browser.

## Audio

* **Synthesized voices:** all 84 voice lines (the brother, an announcer and Mom) are synthesized with `espeak-ng`. They have speech-bubble subtitles.
* **Music:** each location has its own procedurally composed chiptune track, plus tracks for the menu and the ending (12 in total).
* **Sound effects:** 41 procedurally generated sounds (splats, splashes, boings and, yes, a whoopee cushion).

## Project layout

```
project.godot / main.tscn   Godot project (renderer: Compatibility, for the web)
scripts/game.gd             Autoload: audio, saving, screen switching, UI theme
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
