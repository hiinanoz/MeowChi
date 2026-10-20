import SwiftUI

struct FoodItem: Identifiable, Equatable {
    let id: String
    let price: Int
    let hunger: Double
    let happiness: Double
    let xp: Int

    var nameKey: LocalizedStringKey { LocalizedStringKey(id + ".name") }
}

/// Static item definitions. Balancing values for items live here, next to their IDs.
enum ItemCatalog {
    static let foods: [FoodItem] = [
        FoodItem(id: "food.dry", price: 5, hunger: 20, happiness: 1, xp: 3),
        FoodItem(id: "food.wet", price: 10, hunger: 30, happiness: 4, xp: 4),
        FoodItem(id: "food.fish", price: 15, hunger: 35, happiness: 6, xp: 5),
        FoodItem(id: "food.chicken", price: 15, hunger: 35, happiness: 6, xp: 5),
        FoodItem(id: "food.treat", price: 8, hunger: 8, happiness: 10, xp: 2),
    ]

    static func food(_ id: String) -> FoodItem? { foods.first { $0.id == id } }
}
