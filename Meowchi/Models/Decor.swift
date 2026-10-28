import SwiftUI

/// Fixed placement slots in the room. Each slot shows exactly one item.
enum DecorSlot: String, Codable, CaseIterable, Identifiable {
    case wallpaper, floor, rug, bed, post, plant, wallArt, toy

    var id: String { rawValue }
    var titleKey: LocalizedStringKey { LocalizedStringKey("decor.slot." + rawValue) }
}

struct DecorItem: Identifiable, Equatable {
    /// Also the sprite asset name.
    let id: String
    let slot: DecorSlot
    let price: Int
    let unlockLevel: Int

    var nameKey: LocalizedStringKey { LocalizedStringKey("decor." + id) }
    var isFree: Bool { price == 0 }
}

enum DecorCatalog {
    static let items: [DecorItem] = [
        DecorItem(id: "wall_stripes", slot: .wallpaper, price: 0, unlockLevel: 1),
        DecorItem(id: "wall_mint", slot: .wallpaper, price: 120, unlockLevel: 2),
        DecorItem(id: "wall_dots", slot: .wallpaper, price: 150, unlockLevel: 3),
        DecorItem(id: "floor_wood", slot: .floor, price: 0, unlockLevel: 1),
        DecorItem(id: "floor_tiles", slot: .floor, price: 150, unlockLevel: 3),
        DecorItem(id: "rug_oval", slot: .rug, price: 0, unlockLevel: 1),
        DecorItem(id: "rug_blue", slot: .rug, price: 80, unlockLevel: 2),
        DecorItem(id: "rug_leaf", slot: .rug, price: 80, unlockLevel: 2),
        DecorItem(id: "bed_basic", slot: .bed, price: 0, unlockLevel: 1),
        DecorItem(id: "bed_cloud", slot: .bed, price: 120, unlockLevel: 2),
        DecorItem(id: "bed_royal", slot: .bed, price: 250, unlockLevel: 4),
        DecorItem(id: "scratching_post", slot: .post, price: 0, unlockLevel: 1),
        DecorItem(id: "post_tower", slot: .post, price: 200, unlockLevel: 3),
        DecorItem(id: "plant_basic", slot: .plant, price: 0, unlockLevel: 1),
        DecorItem(id: "plant_cactus", slot: .plant, price: 60, unlockLevel: 1),
        DecorItem(id: "frame_sun", slot: .wallArt, price: 0, unlockLevel: 1),
        DecorItem(id: "frame_fish", slot: .wallArt, price: 60, unlockLevel: 1),
        DecorItem(id: "frame_clock", slot: .wallArt, price: 90, unlockLevel: 2),
        DecorItem(id: "toy_yarn", slot: .toy, price: 0, unlockLevel: 1),
        DecorItem(id: "toy_mouse", slot: .toy, price: 50, unlockLevel: 1),
    ]

    static func item(_ id: String) -> DecorItem? { items.first { $0.id == id } }
    static func items(in slot: DecorSlot) -> [DecorItem] { items.filter { $0.slot == slot } }
    /// The free starter item of each slot.
    static func defaultItem(_ slot: DecorSlot) -> DecorItem { items.first { $0.slot == slot && $0.isFree }! }
}

/// Saved room layout. Free items are always owned; unknown or missing slots fall back to defaults.
struct DecorState: Codable, Equatable {
    var owned: Set<String> = []
    var equipped: [String: String] = [:]

    func isOwned(_ item: DecorItem) -> Bool { item.isFree || owned.contains(item.id) }

    func equipped(_ slot: DecorSlot) -> DecorItem {
        if let id = equipped[slot.rawValue], let item = DecorCatalog.item(id), item.slot == slot, isOwned(item) {
            return item
        }
        return DecorCatalog.defaultItem(slot)
    }
}
