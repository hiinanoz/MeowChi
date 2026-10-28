# Meowchi: notes for Claude

Cozy pixel-art virtual-cat game for iOS (SwiftUI + SpriteKit + SwiftData, offline, no dependencies).
Talk to the user in **Turkish**; code, identifiers and docs are in English. The user wants low token use, careful planning and no invented results.

## Must-know constraints

- **Toolchain: Xcode 15.2 / iOS 17 SDK / Swift 5.9** on the user's Mac. Don't use iOS 18+ APIs, Swift 6 language mode, Swift Testing, or Xcode 16 synchronized folders. Deployment target iOS 17.0, iPhone only for now (`DEVICE_FAMILY` in the generator).
- **The Xcode project is generated**: after adding, moving or deleting any file under `Meowchi/` or `MeowchiTests/`, run `python3 Tools/generate_project.py` and commit the regenerated `Meowchi.xcodeproj`. Never hand-edit `project.pbxproj`.
- **Cloud/Linux sessions can't build or test** (no Xcode). Say clearly that the change isn't compiled or tested, keep changes small, and leave verification to a Mac session.
- Placeholder art comes from `Tools/gen_sprites.py`. Final art will replace those PNGs under the same names (see `docs/ASSETS.md`). Don't run the generator once real art is in.
- Bundle ID `com.meowchi.game`. Support site https://www.hii.othink.com, contact drinanoz@gmail.com.

## Architecture rules

- All state changes go through `GameStore` (`@Observable @MainActor`). Actions return `ActionResult` and apply the state change and save **before** any animation.
- `CatSimulator` is pure, elapsed-time based (no timers). Offline time is capped and needs have a floor; there's no death.
- Every tuning number lives in `Core/Balance.swift`; item values live in `Models/ItemCatalog.swift`.
- Saves: one versioned JSON payload in SwiftData (`SaveCodec`, backup + quarantine). **New `GameState` fields must decode with `decodeIfPresent` + a default in `GameState.init(from:)`**, so existing saves keep loading.
- The cat is 3 layers (body, ears, tail) recolored by `CatShader` (palette swap of 4 key fur colors; sampling snapped to 64×64 texels). Tail mood is independent of the body animation.
- SpriteKit room: 360×400 logical room, 1 art px = 1 pt, whole-number scaling, `.nearest` filtering. Views using SpriteKit or store methods are `@MainActor`.
- Every user-facing string is a semantic key in `Localization/Localizable.xcstrings` (English now; tr, es, de, ja, ko, fr in Phase 6). Never build a `LocalizedStringKey` with string interpolation of a key name; use `"prefix." + value`.

## Verify (on the Mac)

```bash
xcodebuild test -project Meowchi.xcodeproj -scheme Meowchi -destination 'platform=iOS Simulator,name=iPhone 15' CODE_SIGNING_ALLOWED=NO
```

DEBUG launch arguments for screenshots: `-skipOnboarding` opens straight into the room; `-openScreen shop|tasks|decor|laser|garden|play|food|clean|health` opens that screen; `-refillStats` fills all needs; `-debugLook coat,ears,tail`; `-decorTab cat`.

## Workflow

One branch per phase (`phase-N-…`), merged into `main` only after the tests pass on the simulator. Commit messages end with the Co-Authored-By line. Roadmap and status: `docs/ROADMAP.md`.
