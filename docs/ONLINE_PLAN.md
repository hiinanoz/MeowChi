# Game Center and iCloud: plan (not implemented)

Both are optional and touch signing, App Store Connect and privacy answers, so they need the user's go-ahead first.

## Game Center achievements

- **What:** mirror the 16 badges in `Models/Badges.swift` as Game Center achievements (same ids, `meowchi.badge.<id>`).
- **Code:** `Services/GameCenter.swift` with `GKLocalPlayer.local.authenticateHandler` (called once from `MeowchiApp`,
  never blocking play) and `report(badgeID:)` called from `GameStore.unlockBadges()` when a badge is new.
  Players who aren't signed in see nothing; the game stays fully offline.
- **Signing:** add the `com.apple.developer.game-center` entitlement to `Meowchi/Meowchi.entitlements`. The bundle ID
  already has the Game Center capability (seen in the signing log), so API-key signing should keep working.
- **App Store Connect:** create the 16 achievements (title, description, 512×512 image, points) in every language.
  This can be scripted with the App Store Connect API (`gameCenterAchievements`), like the other `Tools/asc_*.py` scripts.
- **Privacy:** Game Center data is handled by Apple; the privacy page gets a short Game Center section (see Catgrid's).
- **Cost:** about a day of work plus achievement art.

## iCloud save sync

- **What:** the save follows the player to a new device.
- **Option A (recommended): iCloud key-value store** (`NSUbiquitousKeyValueStore`). The whole save is one JSON payload
  (`SaveCodec`) and is well under the 1 MB limit. Conflict rule: keep the payload with the newer `lastSimulatedAt`,
  but never lose purchases or badges (merge `decor.owned`, `wardrobe`, `badges`, `lifetime` by union/max).
- **Option B: CloudKit / SwiftData sync:** more moving parts (schema, container, migrations) for no gain here.
- **Signing:** iCloud capability with key-value storage on `com.othinks.Meowchi`. Like App Groups, the user may have
  to enable it in the developer portal by hand before the release workflow can sign it.
- **Save format:** no change to `GameState`; a small `CloudSaveSync` wrapper around `SaveStore`.
- **Privacy:** data stays in the player's own iCloud account; "Data Not Collected" still applies.
- **Cost:** about a day of work plus careful conflict tests (two devices, offline edits, a reset on one device).
