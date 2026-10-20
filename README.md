# Meowchi 🐾

A cozy virtual-cat game for iOS with a pixel-art look, built with SwiftUI and SpriteKit. Works offline, no account needed.

## Requirements

- Xcode 15.2 or newer, iOS 17.0+ (iPhone; iPad comes later)
- Python 3 (comes with Xcode's command line tools). Used only for the project and placeholder-art generators.

## Getting started

```bash
open Meowchi.xcodeproj          # pick the "Meowchi" scheme and an iPhone simulator, then Run
```

Command line:

```bash
xcodebuild test -project Meowchi.xcodeproj -scheme Meowchi \
  -destination 'platform=iOS Simulator,name=iPhone 15' CODE_SIGNING_ALLOWED=NO
```

## Adding files

The Xcode project is **generated**. After you add, move or delete a file under `Meowchi/` or `MeowchiTests/`, run:

```bash
python3 Tools/generate_project.py
```

Placeholder sprites are made by `python3 Tools/gen_sprites.py`. Don't run it once real art has replaced the placeholders.

## Layout

```
Meowchi/
  App/            app entry point, root view
  Core/           Balance (every tuning value)
  Models/         GameState, CatStats, ItemCatalog (Codable value types)
  Game/           GameStore, Simulation/, Scenes/ (SpriteKit), Cat/ (CatNode state machine)
  Services/       Persistence (SwiftData + versioned JSON)
  Features/       SwiftUI screens (Home/, Shared/ pixel UI kit)
  Resources/      Assets.xcassets
  Localization/   Localizable.xcstrings (en; tr es de ja ko fr in Phase 6)
MeowchiTests/     XCTest unit tests
Tools/            project + placeholder-art generators
docs/             ROADMAP.md, ASSETS.md
```

See [docs/ROADMAP.md](docs/ROADMAP.md) for the architecture, simulation rules and phase plan.
