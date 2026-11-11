import SwiftUI

/// Small picture of a decoration, shown on the player's current wall and floor (used by Decor and Shop).
struct DecorPreview: View {
    let item: DecorItem
    @Environment(GameStore.self) private var store

    var body: some View {
        let decor = store.state.decor
        if item.isEmpty {
            PixelIcon(name: "icon_close", size: 24).frame(width: 64, height: 56)
        } else if let color = item.color {
            // Color swatch shown on the currently equipped pattern.
            let pattern = item.slot == .wallColor ? decor.equipped(.wallpaper).id : decor.equipped(.floor).id
            preview(pattern, cropBottom: item.slot == .floorColor).colorMultiply(color)
        } else if item.slot == .wallpaper {
            preview(item.id, cropBottom: false).colorMultiply(decor.equipped(.wallColor).color ?? .white)
        } else if item.slot == .floor {
            preview(item.id, cropBottom: true).colorMultiply(decor.equipped(.floorColor).color ?? .white)
        } else {
            preview(item.id, cropBottom: false)
        }
    }

    /// Big wall/floor textures are cropped to a swatch; small items are shown whole.
    private func preview(_ sprite: String, cropBottom: Bool) -> some View {
        Image(sprite)
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: sprite.hasPrefix("wall_") || sprite.hasPrefix("floor_") ? .fill : .fit)
            .frame(width: 64, height: 56, alignment: cropBottom ? .bottom : .top)
            .clipped()
            .accessibilityHidden(true)
    }
}

/// An accessory as worn, cropped to the part of the cat it sits on.
struct AccessoryPreview: View {
    let item: Accessory

    var body: some View {
        Image("cat_acc_\(item.rawValue)_idle_0").interpolation(.none).resizable()
            .frame(width: 64, height: 64)
            .frame(width: 64, height: 40, alignment: item.slot == .head ? .top : .center)
            .clipped()
            .accessibilityHidden(true)
    }
}
