import SwiftUI

/// Something the cat asks for (a thought bubble in the room). Granting it gives a small bonus.
struct CatWish: Codable, Equatable {
    enum Kind: Codable, Equatable {
        case food(String)          // a food id from ItemCatalog
        case game(String)          // a MiniGameKind raw value
        case event(TaskEvent)      // petted, walked, bathed, brushed, watchedTV
    }

    var kind: Kind
    var expiresAt: Date

    var icon: String {
        switch kind {
        case .food(let id): ItemCatalog.food(id)?.iconName ?? "icon_hunger"
        case .game: "icon_play"
        case .event(.walked): "fx_sparkle"
        case .event(.bathed), .event(.brushed): "icon_clean"
        case .event(.watchedTV): "icon_play"
        case .event: "icon_happiness"
        }
    }

    /// What the cat wants, as a short phrase.
    var textKey: LocalizedStringKey {
        switch kind {
        case .food(let id): ItemCatalog.food(id)?.nameKey ?? "food.title"
        case .game(let raw): MiniGameKind(rawValue: raw)?.titleKey ?? "action.play"
        case .event(let event): LocalizedStringKey("wish." + event.rawValue)
        }
    }

    /// Wishes the player can always fulfil with what the game offers.
    static let eventChoices: [TaskEvent] = [.petted, .walked, .bathed, .brushed]
}

/// One line in the cat's diary. `kind` picks the sentence ("diary.<kind>"); `detail` is an optional
/// localization key shown after it (a place, a badge, a stage) and `number` an optional value.
struct DiaryEntry: Codable, Equatable, Identifiable {
    var date: Date
    var kind: String
    var detail: String?
    var number: Int?

    var id: String { "\(date.timeIntervalSince1970)-\(kind)" }
    var titleKey: LocalizedStringKey { LocalizedStringKey("diary." + kind) }
}
