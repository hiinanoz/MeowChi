import SwiftUI

/// How the cat looks. Stored as raw strings so unknown values from newer builds fall back safely.
struct CatLook: Codable, Equatable {
    var coat = CatCoat.ginger.rawValue
    var ears = EarStyle.pointy.rawValue
    var tail = TailLength.medium.rawValue

    var coatValue: CatCoat { CatCoat(rawValue: coat) ?? .ginger }
    var earsValue: EarStyle { EarStyle(rawValue: ears) ?? .pointy }
    var tailValue: TailLength { TailLength(rawValue: tail) ?? .medium }

    /// Same look with every unknown value replaced by its default.
    var sanitized: CatLook { CatLook(coat: coatValue.rawValue, ears: earsValue.rawValue, tail: tailValue.rawValue) }
}

/// Coat colors. Each maps the four key fur colors of the sprites (fur, shade, light, stripes) to new ones.
enum CatCoat: String, CaseIterable, Identifiable {
    case ginger, silver, cream, cocoa, smoke, snow

    var id: String { rawValue }
    var nameKey: LocalizedStringKey { LocalizedStringKey("coat." + rawValue) }

    /// fur, shade, light, stripe (RGB 0...255).
    var palette: [(Double, Double, Double)] {
        switch self {
        case .ginger: [(242, 153, 74), (222, 120, 52), (251, 188, 115), (198, 94, 28)]
        case .silver: [(160, 165, 182), (136, 141, 160), (196, 200, 214), (112, 117, 138)]
        case .cream: [(240, 214, 176), (220, 190, 150), (250, 232, 205), (204, 160, 116)]
        case .cocoa: [(150, 104, 78), (126, 84, 62), (180, 134, 104), (104, 68, 50)]
        case .smoke: [(98, 100, 116), (80, 82, 98), (128, 130, 146), (66, 68, 82)]
        case .snow: [(246, 242, 236), (226, 220, 212), (255, 252, 248), (220, 212, 204)]
        }
    }

    var swatch: Color {
        let (r, g, b) = palette[0]
        return Color(red: r / 255, green: g / 255, blue: b / 255)
    }
}

enum EarStyle: String, CaseIterable, Identifiable {
    case pointy, round, folded
    var id: String { rawValue }
    var nameKey: LocalizedStringKey { LocalizedStringKey("ears." + rawValue) }
}

enum TailLength: String, CaseIterable, Identifiable {
    case short, medium, long
    var id: String { rawValue }
    var nameKey: LocalizedStringKey { LocalizedStringKey("tail." + rawValue) }
}
