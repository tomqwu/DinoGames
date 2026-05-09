# Dino Adventure

An endless-runner dinosaur game built to match the supplied design. Pure HTML/CSS/JavaScript — no build step, no dependencies.

![Dino Adventure](https://img.shields.io/badge/runtime-static%20web-7fa650) ![No build](https://img.shields.io/badge/build-none-blue)

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

> Note: opening `index.html` directly works in most browsers, but a few of them block ES module imports from `file://` URLs. If you see a blank page, use one of the server options above.

## Controls

| Action | Keyboard | Mouse / Touch |
| --- | --- | --- |
| Jump | `↑` / `Space` / `W` | Click / tap top half |
| Slide | `↓` / `S` (hold) | Hold mouse / tap bottom half |
| Pause | `Esc` / `P` | Pause button (top-right HUD) |
| Retry | `Enter` (on game-over) | RETRY button |

## Screens

- **Title** — PLAY, HOW TO PLAY, SETTINGS, plus sound and music toggles.
- **Game** — Score & best HUD, pause button, controls hint.
- **Game Over** — Final score, RETRY, HOME.
- **How to Play** — Instructions and controls reference.
- **Settings** — Sound, music, difficulty (Easy / Normal / Hard), reset best score.

## Gameplay

- The dino runs forward automatically.
- Jump over cacti and rocks; slide under flying pterodactyls (after score 200).
- Speed ramps up over time — the longer you survive, the harder it gets.
- Difficulty preset adjusts speed growth and obstacle spacing.

## Persistence

`localStorage` keeps:
- `dino-adventure:best` — highest score reached
- `dino-adventure:settings` — `sfx`, `music`, `difficulty`

You can wipe the best score from the Settings screen.

## Project layout

```
index.html       # all five screens
styles.css       # theme, HUD, overlays, cards
src/
  main.js        # screen routing + input + persistence
  game.js        # canvas game loop (physics, obstacles, rendering)
  sfx.js         # tiny WebAudio sound bank
package.json     # `npm start` → static server on :5173
```

## Browser support

Modern evergreen browsers (Chrome, Firefox, Safari, Edge). Uses Canvas 2D, ES modules, and the Web Audio API.
