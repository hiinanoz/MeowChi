import SwiftUI

/// Fixed placement slots in the room. Each slot shows exactly one item.
enum DecorSlot: String, Codable, CaseIterable, Identifiable {
    case wallpaper, wallColor, floor, floorColor, view, rug, bed, post, plant, wallArt, toy, tv

    var id: String { rawValue }
    var titleKey: LocalizedStringKey { LocalizedStringKey("decor.slot." + rawValue) }
}

struct DecorItem: Identifiable, Equatable {
    /// Also the sprite asset name, except for color items.
    let id: String
    let slot: DecorSlot
    let price: Int
    let unlockLevel: Int
    /// Color items (wall/floor color) tint the grayscale pattern instead of having a sprite. 0xRRGGBB.
    var tint: UInt32? = nil

    var nameKey: LocalizedStringKey { LocalizedStringKey("decor." + id) }
    var isFree: Bool { price == 0 }
    /// "Nothing here" items (e.g. no TV yet).
    var isEmpty: Bool { id.hasSuffix("_none") }
    var hasSprite: Bool { tint == nil && !isEmpty }

    var color: Color? {
        tint.map { Color(red: Double($0 >> 16 & 0xFF) / 255, green: Double($0 >> 8 & 0xFF) / 255, blue: Double($0 & 0xFF) / 255) }
    }
}

enum DecorCatalog {
    static let items: [DecorItem] = [
        DecorItem(id: "wall_stripes", slot: .wallpaper, price: 0, unlockLevel: 1),
        DecorItem(id: "wall_plain", slot: .wallpaper, price: 60, unlockLevel: 1),
        DecorItem(id: "wall_dots", slot: .wallpaper, price: 100, unlockLevel: 2),
        DecorItem(id: "wallcolor_peach", slot: .wallColor, price: 0, unlockLevel: 1, tint: 0xFAE2C8),
        DecorItem(id: "wallcolor_mint", slot: .wallColor, price: 40, unlockLevel: 1, tint: 0xD6F0E2),
        DecorItem(id: "wallcolor_butter", slot: .wallColor, price: 40, unlockLevel: 1, tint: 0xFAF0C8),
        DecorItem(id: "wallcolor_lilac", slot: .wallColor, price: 40, unlockLevel: 2, tint: 0xE8DEF8),
        DecorItem(id: "wallcolor_sky", slot: .wallColor, price: 40, unlockLevel: 2, tint: 0xD6E8F8),
        DecorItem(id: "wallcolor_rose", slot: .wallColor, price: 60, unlockLevel: 3, tint: 0xFAD6DC),
        DecorItem(id: "wallcolor_sage", slot: .wallColor, price: 60, unlockLevel: 3, tint: 0xD6E4C8),
        DecorItem(id: "floor_wood", slot: .floor, price: 0, unlockLevel: 1),
        DecorItem(id: "floor_tiles", slot: .floor, price: 120, unlockLevel: 2),
        DecorItem(id: "floorcolor_oak", slot: .floorColor, price: 0, unlockLevel: 1, tint: 0xCD8C5C),
        DecorItem(id: "floorcolor_walnut", slot: .floorColor, price: 50, unlockLevel: 1, tint: 0x96644A),
        DecorItem(id: "floorcolor_maple", slot: .floorColor, price: 50, unlockLevel: 2, tint: 0xEEC896),
        DecorItem(id: "floorcolor_ash", slot: .floorColor, price: 50, unlockLevel: 2, tint: 0xC8C4BE),
        DecorItem(id: "floorcolor_rose", slot: .floorColor, price: 70, unlockLevel: 3, tint: 0xE6AAAA),
        DecorItem(id: "view_sky", slot: .view, price: 0, unlockLevel: 1),
        DecorItem(id: "view_sakura", slot: .view, price: 80, unlockLevel: 2),
        DecorItem(id: "view_sea", slot: .view, price: 80, unlockLevel: 2),
        DecorItem(id: "view_city", slot: .view, price: 100, unlockLevel: 3),
        DecorItem(id: "view_fuji", slot: .view, price: 150, unlockLevel: 4),
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
        DecorItem(id: "tv_none", slot: .tv, price: 0, unlockLevel: 1),
        DecorItem(id: "tv_retro", slot: .tv, price: 250, unlockLevel: 2),
        DecorItem(id: "tv_modern", slot: .tv, price: 400, unlockLevel: 3),
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
