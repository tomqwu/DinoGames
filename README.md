# Dino Adventure

An endless-runner dinosaur game built to match the supplied design — extended with missions, coins, powerups, combos, and a day/night cycle. Pure HTML / CSS / JavaScript, no build step, no dependencies.

## Run it

Any static file server works.

```bash
# Option 1 — npm (uses npx serve)
npm start
#   → http://localhost:5173

# Option 2 — Python (no Node needed)
python3 -m http.server 5173
#   → http://localhost:5173

# Option 3 — just open the file
open index.html      # macOS
xdg-open index.html  # Linux
```

> Opening `index.html` directly works in most browsers, but a few block ES module imports from `file://` URLs. If you see a blank page, use one of the server options above.

## Controls

| Action | Keyboard | Mouse / Touch |
| --- | --- | --- |
| Jump | `↑` / `Space` / `W` | Click / tap top half |
| Slide | `↓` / `S` (hold) | Hold mouse / tap bottom half |
| Pause | `Esc` / `P` | Pause button (top-right HUD) |
| Reroll missions | `R` (in-game) | — |
| Retry | `Enter` (on game-over) | RETRY button |

## Gameplay features

### Missions
Three missions are active at any time, shown on the right side of the HUD with progress bars. Complete a mission to earn coins; a fresh mission slides into the slot.

Mission templates include:

- Reach **N** points
- Collect **N** coins
- Jump / slide **N** times
- Clear **N** cacti / rocks
- Dodge **N** pterodactyls
- Reach an **xN** combo
- Collect **N** powerups
- Survive **N** seconds

Press `R` mid-run to reroll all three missions if you don't like the current set.

### Coins
Collect golden coins that float in arcs above the path. Coins boost your score, count toward missions, and add to a **lifetime coin total** stored in `localStorage`. The HUD shows `run-coins / lifetime`.

### Powerups
Periodically a glowing orb spawns on the track. Grab it for a 6-second buff:

- 🛡️ **Shield (S, blue)** — absorbs one collision, then breaks.
- 🧲 **Magnet (M, yellow)** — pulls nearby coins toward you.
- 🐢 **Slow-mo (T, purple)** — slows obstacle scroll ~45% so jumps are easier.

Active powerups show as chips under the score with a depleting timer bar.

### Combo multiplier
Clear obstacles in quick succession (within ~2 seconds) to build a combo (`x2`, `x3`, …). Combos award bonus score, show above the dino, and feed the combo mission. Touching anything resets the combo to zero.

### Day / Night cycle
The sky, mountains, ground, and clouds shift between day and night every ~500 score, with stars appearing at night and a moon replacing the sun. Pure visual flavor — gameplay is unaffected.

### Run summary
Game over now shows: final score, best, coins earned, longest combo, total obstacles cleared, and missions completed this run.

## Screens

- **Title** — PLAY, HOW TO PLAY, SETTINGS, plus sound and music toggles.
- **Game** — Score & best HUD, coin counter, mission list, powerup chips, pause button.
- **Game Over** — Run summary, RETRY, HOME.
- **How to Play** — Instructions and controls reference.
- **Settings** — Sound, music, difficulty (Easy / Normal / Hard), reset best score.

## Persistence

Stored in `localStorage`:

| Key | Description |
| --- | --- |
| `dino-adventure:best` | Highest score reached |
| `dino-adventure:coins` | Lifetime coin total |
| `dino-adventure:missions-completed` | Lifetime mission completions |
| `dino-adventure:settings` | `sfx`, `music`, `difficulty` |

You can wipe the best score from the Settings screen.

## Project layout

```
index.html       # all five screens, HUD, overlays
styles.css       # theme, HUD, mission list, powerup chips, toasts
src/
  main.js        # screen routing, input, mission/coin persistence
  game.js        # canvas game loop (physics, obstacles, coins, powerups, combo)
  missions.js    # mission templates + manager (auto-reroll on complete)
  sfx.js         # tiny WebAudio sound bank (jump, coin, powerup, hit…)
package.json     # `npm start` → static server on :5173
```

## Browser support

Modern evergreen browsers (Chrome, Firefox, Safari, Edge). Uses Canvas 2D, ES modules, and the Web Audio API.
