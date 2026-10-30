# Meowchi: handoff for Claude Code (cloud)

Status as of 2026-10-30. `main` = `eb76cae`, 48 Swift source files, 65 unit tests, all passing on the Mac (iPhone 15 simulator, iOS 17.2).
Read `CLAUDE.md` first. The rules below are the ones most likely to trip a new session.

## 1. Read this before touching anything

- **Talk to the user in Turkish.** Code, identifiers, commit messages and docs are in English. The user wants low token use, careful planning and honest results ("compiled / tested / not verified").
- **Cloud sessions can't build or test iOS** (no Xcode, no simulator). Every Swift change made in the cloud is **untested**. Say so in every report, keep changes small and reviewable, and leave verification to a Mac session.
- **Toolchain on the user's Mac: Xcode 15.2 / iOS 17 SDK / Swift 5.9 (Intel, macOS 13).** No iOS 18+ APIs, no Swift 6 mode, no Swift Testing, no Xcode 16 synchronized folders.
- **The Xcode project is generated** by `python3 Tools/generate_project.py` (plain Python, works in the cloud). Run it after adding, moving or deleting any file under `Meowchi/`, `MeowchiTests/` or `MeowchiWidget/`, and commit the regenerated `Meowchi.xcodeproj`. Never hand-edit `project.pbxproj`.
- **Generators:** `Tools/gen_sprites.py` (placeholder art) and `Tools/gen_audio.py` (music and SFX; needs macOS `afconvert`, so it **won't run in the cloud**). Final art will replace the sprite PNGs; don't regenerate sprites after that.
- **Save compatibility:** every new `GameState` or nested field must decode with `decodeIfPresent` plus a default, so existing saves keep loading. Add a test that decodes an older JSON.
- **Balancing numbers** live only in `Core/Balance.swift`; item data lives in `Models/ItemCatalog.swift`, `Models/Decor.swift`, `Models/CatLook.swift`, `Models/Badges.swift` and `Models/DailyTasks.swift`.
- **Strings:** semantic keys in `Meowchi/Localization/Localizable.xcstrings` (English only for now). The widget has its own `MeowchiWidget/Localizable.xcstrings`. Never build a `LocalizedStringKey` by interpolating a key name; use `"prefix." + value`.

## 2. What exists (by phase)

| Phase | Done |
|---|---|
| 1 Foundation | Generated project, `GameStore` (all mutations), elapsed-time `CatSimulator` (offline cap, need floors, clock-rollback safe), SwiftData save with versioned JSON, backup and quarantine |
| 2 Playable cat | 64 px art at 1 art px = 1 pt, whole-number scaling, tap vs stroke petting, day/night lighting, onboarding |
| 3 Care | Food picker, bath, brushing, litter box, vet, health tips |
| 4 Gameplay | Mini-game framework + Laser Chase, food shop, daily tasks (4 of 10, all-done bonus), XP and levels, coins |
| 5 Content | Layered room: wallpaper/floor patterns tinted by color slots, window views, 12 decor slots; cat customization (6 coats via palette-swap `CatShader`, 3 ears, 3 tails, 5 accessories); side-view walk; tail body language; scratching post; water bowl; nail trimming; sickness + attention bubble; friend visits; Cozy time; TV channels; walks (garden, park, beach, forest); daily check-in; badges + photo album; home-screen widget; 4 synthesized music tracks with context rules (menu = 16-bit, games = upbeat, home = player's pick); 10 SFX |
| 5f UX (HIG) | One Menu page, sheets close / pushed pages go back, Decorate `NavigationStack`, Continue + "open straight to home", welcome-back banner, Dynamic Type, contrast, 44 pt targets, Reduce Motion, VoiceOver room actions and announcements, door transition, haptics, purchase confirm (200+ coins), first-time tips, opt-in reminders (max 1/day, quiet hours 21:00–09:00), iPad layout, long-text pass |

Details: `docs/ROADMAP.md`, `docs/UX_REVIEW_TR.md` (status table at the end), `docs/ASSETS.md` (art spec, including the 4 fur key colors), `docs/GROWTH_PLAN.md`.

## 3. Code map

```
Meowchi/App/            MeowchiApp (DEBUG launch flags), RootView (onboarding → main menu → home)
Meowchi/Core/           Balance, DayCycle
Meowchi/Models/         GameState (+ CatState, CareState, RewardLog, settings…), CatLook, Decor, DailyTasks, Walk, Badges, MiniGame, ItemCatalog
Meowchi/Game/           GameStore; Simulation/CatSimulator; Cat/ (CatNode layers, CatShader); Scenes/ (RoomScene, RoomBackdrop, SpriteLibrary);
                        MiniGames/LaserChaseScene; Garden/GardenScene
Meowchi/Features/       Home (HomeView, HUD, CarePanels), Menu, MainMenu, Decor, Shop, Tasks (+ LoginRewardView), Collection,
                        Settings, Onboarding, Cozy, Care (NailTrim), Garden (GardenView, WalkPicker), MiniGames, Shared (PixelTheme,
                        SheetScaffold, CatPreview/CatCustomizer, FirstTimeTip, ShaderPrewarm)
Meowchi/Services/       Persistence (SaveStore), Audio (AudioManager), Widget (WidgetSnapshot [shared with widget], WidgetBridge,
                        CatImageRenderer), Notifications (Reminders)
MeowchiWidget/          WidgetKit extension (small + medium), own asset catalog and strings
MeowchiTests/           XCTest: simulator, store, care, gameplay, decor, settings/audio, widget, reminders
```

## 4. To-do list (in recommended order)

### A. Blocked on the user
1. **Developer portal setup**: Team ID `24RD5ZN5HX` is set (project-level `DEVELOPMENT_TEAM` in `Tools/generate_project.py`). Still to do in the portal: register `com.othinks.Meowchi`, `com.othinks.Meowchi.widget` and the App Group `group.com.othinks.Meowchi`, then create the App Store Connect record.

### B. Phase 6: release prep (cloud-friendly items marked ☁︎)
2. ☁︎ **Translations** for tr, es, de, ja, ko, fr into both `.xcstrings` files: about 290 app keys + 3 widget keys, plurals for `hud.coins %lld`. Keep the tone cozy and non-guilt; review Japanese and Korean naturalness. Re-check long German and French text on the Mac.
3. ☁︎ **App Store metadata**: name, subtitle, keywords, description and "What's New" in 7 languages; privacy answers ("Data Not Collected"); age rating notes. Support URL https://hii.othinks.com, contact mobile@othinks.com.
4. ☁︎ **Privacy policy page** (static HTML/Markdown for the website): offline, no account, no tracking, local notifications only when opted in.
5. **Xcode Cloud** (App Store Connect web): a workflow on `main` that archives with a current Xcode and uploads to TestFlight. The user's Mac can't run newer Xcode, so this is the release path.
6. **Final app icon and launch look**, once the final art exists.
7. **In-app language selector** (optional): iOS already offers per-app language in Settings; an in-app picker would link there.

### C. Content and polish (Mac verification needed)
8. **Final pixel art** from the user (AI generation + cleanup). Swap the PNGs under the same names; respect the key colors and sizes in `docs/ASSETS.md`.
9. **Yarn Ball and Toy Mouse mini-games** (`MiniGameKind` + a scene each, rewards via `Balance`).
10. **Extra animations** after final art: jump, groom, drink, turn, back-view "watching TV" pose.
11. **Cat growth** per `docs/GROWTH_PLAN.md` (stage derived from care days; never decreases).
12. **Personalities** (the enum exists; only one is used): behavior weights in `RoomScene.decideNextBehavior`.
13. Optional: Game Center achievements mirroring badges; iCloud save sync (needs a save-format plan).

### D. Known gaps and verification debt
- iPad **landscape** layout and the door transition were never seen on screen. VoiceOver actions, haptics, the notification permission flow and the widget on a home screen were never tried by hand.
- On this Mac, a failing XCTest assertion can hang for minutes (symbolication). Run a stalled test alone with `-only-testing:` and log its values.
- The Mac runs out of memory when many apps are open; shut down simulators between runs if builds stall.

## 5. How to verify (on the Mac)

```bash
python3 Tools/generate_project.py
xcodebuild test -project Meowchi.xcodeproj -scheme Meowchi -destination 'platform=iOS Simulator,name=iPhone 15' CODE_SIGNING_ALLOWED=NO
```

Screenshots without tapping use DEBUG launch flags (see `CLAUDE.md`), e.g. `xcrun simctl launch <device> com.othinks.Meowchi -skipOnboarding -openScreen decor -decorTab cat`.

## 6. Working agreement

- One branch per piece of work (`phase-N-…`), fast-forward into `main` after the tests pass **on the Mac**. Cloud work goes to a branch plus a PR; the Mac session merges it after testing.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Report to the user in Turkish: what changed, what was verified, what was not.
