# Dino Blocklands iOS

A native iPhone and iPad SpriteKit blocky fantasy RPG MVP. You play as a dinosaur adventurer in an original classic-MMO-inspired world: choose a class in Blockshire, accept an elder quest, clear Bramble Camp, earn gear, enter Tailblock Cave, defeat the Sky Wyrm, and restore the Sky Gate Shrine.

## Story Direction

Dino Blocklands is set on **First Earth**, a mythic prehistoric Earth before humans. Dinosaur clans preserve culture through migration songs, amber memory, stone shrines, crest marks, and oral history rather than written books.

Blockshire is a small clan village where young dinosaurs pass into adulthood through one of three rites:

- **Guardian**: the shell oath, a herd-protector tradition.
- **Emberclaw**: the scout path, a hunter tradition that reads heat, ash, and danger.
- **Stonesinger**: the stone rhythm, a lore-keeper tradition tied to amber and shrine resonance.

The first story arc begins when Elder Mossbeak warns that the Sky Gate Shrine has gone silent. Bramble growth blocks the old migration path, Tailblock Cave wakes with broken ancestral memory, and the Sky Wyrm inside the cave has been twisted by the fallen Sky Relic. The player's first rite is to clear the path, recover the relic, reopen the Sky Gate, and restore the shrine so Blockshire can carry its clan memory forward.

## Requirements

- Xcode 26.5 or newer
- iOS Simulator runtime installed
- XcodeGen, installed with:

```bash
brew install xcodegen
```

## Build

```bash
xcodegen generate
xcodebuild \
  -project DinoRealmsIOS.xcodeproj \
  -scheme DinoRealmsIOS \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  build
```

## Run

Open the project:

```bash
open DinoRealmsIOS.xcodeproj
```

Choose an iPad or iPhone simulator, then press Run.

Or install and launch the latest simulator build from the command line:

```bash
APP_DIR="$(xcodebuild -project DinoRealmsIOS.xcodeproj -scheme DinoRealmsIOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -showBuildSettings 2>/dev/null | awk -F'= ' '/ TARGET_BUILD_DIR = / {print $2; exit}')/DinoRealmsIOS.app"
xcrun simctl boot "iPad Pro 13-inch (M5)" 2>/dev/null || true
xcrun simctl install booted "$APP_DIR"
xcrun simctl launch booted com.tomwu.DinoRealmsIOS
```

## Test

```bash
xcodebuild \
  -project DinoRealmsIOS.xcodeproj \
  -scheme DinoRealmsIOS \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test
```

## Controls

- Drag on the left side for the virtual joystick.
- Tap the right action button; its label changes for nearby actions like Train, Talk, Open, Enter, Unlock, Commune, and Attack.
- Follow the objective arrow and distance hint when you are not close to the next quest target.
- The camera follows the dinosaur automatically.
- In Simulator, enable keyboard capture to use WASD/arrow keys and Space/Return for action.

## MVP Scope

- Universal iPhone/iPad app.
- Touch-first top-down blocky RPG zone.
- Runtime-generated visuals with no external art assets.
- HUD with class, level, HP, keys, gold, amber, XP, quest text, contextual prompts, and next-objective guidance.
- Three dinosaur classes: Guardian, Emberclaw, and Stonesinger, each with different combat stats.
- Blockshire quest hub with class rite mentors, Elder Mossbeak, gear rewards, and a Bramble Camp quest chain.
- Overworld enemies, readable health pips, combat, chests, key gate, cuttable brush, heart pickups, gear, gold, and relic progression.
- Three-room Tailblock Cave dungeon with a separate dungeon key, Boss Door, Sky Wyrm boss, and Sky Relic reward.
- Centralized story/dialogue codex for First Earth lore, clan rites, elder hints, and quest text.
- Unit tests for class choice, quest progression, leveling, rewards, completion, and story text.
