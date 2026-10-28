import XCTest
@testable import Meowchi

@MainActor
final class DecorTests: XCTestCase {
    private func makeStore(_ configure: (inout GameState) -> Void = { _ in }) -> GameStore {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var state = GameState.newGame(now: now, balance: .standard)
        configure(&state)
        return GameStore(saveStore: InMemorySaveStore(state: state), clock: { now })
    }

    func testEverySlotHasExactlyOneFreeDefaultAndSpritesAreUnique() {
        for slot in DecorSlot.allCases {
            XCTAssertEqual(DecorCatalog.items(in: slot).filter(\.isFree).count, 1, "\(slot)")
        }
        XCTAssertEqual(Set(DecorCatalog.items.map(\.id)).count, DecorCatalog.items.count)
    }

    func testBuyEquipsAndCannotBuyTwice() {
        let store = makeStore { $0.coins = 100; $0.progression.level = 2 }
        XCTAssertEqual(store.buyDecor("rug_blue"), .ok)
        XCTAssertEqual(store.state.coins, 20)
        XCTAssertEqual(store.state.decor.equipped(.rug).id, "rug_blue")
        XCTAssertEqual(store.buyDecor("rug_blue"), .alreadyOwned)
        XCTAssertEqual(store.state.coins, 20, "no double charge")
        XCTAssertEqual(store.buyDecor("rug_oval"), .alreadyOwned, "free items are owned")
        XCTAssertEqual(store.equipDecor("rug_oval"), .ok)
        XCTAssertEqual(store.state.decor.equipped(.rug).id, "rug_oval")
    }

    func testLockedAndUnaffordableItemsAreRejectedWithoutCharge() {
        let store = makeStore { $0.coins = 1000; $0.progression.level = 1 }
        XCTAssertEqual(store.buyDecor("bed_royal"), .locked)
        let poor = makeStore { $0.coins = 10; $0.progression.level = 5 }
        XCTAssertEqual(poor.buyDecor("bed_royal"), .insufficientCoins)
        XCTAssertEqual(poor.state.coins, 10)
        XCTAssertEqual(poor.equipDecor("bed_royal"), .noReward, "can't equip what you don't own")
        XCTAssertEqual(poor.buyDecor("sofa_nope"), .unknownItem)
    }

    func testBrokenLayoutFallsBackToDefaults() {
        var decor = DecorState()
        decor.equipped = ["bed": "wall_mint", "rug": "missing", "plant": "plant_cactus"] // wrong slot, unknown, not owned
        XCTAssertEqual(decor.equipped(.bed).id, "bed_basic")
        XCTAssertEqual(decor.equipped(.rug).id, "rug_oval")
        XCTAssertEqual(decor.equipped(.plant).id, "plant_basic")
    }

    func testLookIsSanitizedAndLegacyCoatMigrates() throws {
        let store = makeStore()
        store.setLook(CatLook(coat: "cocoa", ears: "folded", tail: "long"))
        XCTAssertEqual(store.state.cat.look, CatLook(coat: "cocoa", ears: "folded", tail: "long"))
        store.setLook(CatLook(coat: "plaid", ears: "antenna", tail: "huge"))
        XCTAssertEqual(store.state.cat.look, CatLook(), "unknown values fall back to defaults")

        let legacy = #"{"name":"Mochi","appearanceID":"gray_white","stats":{"hunger":50,"energy":50,"happiness":50,"cleanliness":50,"health":50},"adoptedAt":0}"#
        let cat = try JSONDecoder().decode(CatState.self, from: Data(legacy.utf8))
        XCTAssertEqual(cat.look.coat, "silver")
    }

    func testEveryReferencedSpriteExistsInTheBundle() {
        var names = DecorCatalog.items.map(\.id) + ["window_basic", "litter_clean", "litter_dirty", "bath_tub", "fx_laser",
                                                   "garden_background"] + ItemCatalog.foods.map(\.iconName)
        let bodyFrames = ["idle_0", "idle_1", "blink", "happy_0", "happy_1", "sad", "eat_0", "eat_1",
                          "walk_0", "walk_1", "walk_2", "walk_3", "sleep_0", "sleep_1"]
        names += bodyFrames.map { "cat_" + $0 }
        for ears in EarStyle.allCases { names += bodyFrames.map { "cat_ears_\(ears.rawValue)_" + $0 } }
        for length in TailLength.allCases {
            names.append("cat_tail_\(length.rawValue)_sleep")
            for family in ["front", "side"] {
                names += ["down", "wag0", "wag1", "up"].map { "cat_tail_\(length.rawValue)_\(family)_" + $0 }
            }
        }
        for name in names { XCTAssertNotNil(UIImage(named: name), "missing asset \(name)") }
    }

    func testSaveWithoutDecorStillLoads() throws {
        let data = try SaveCodec.encode(GameState.newGame(now: .now, balance: .standard))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var inner = try XCTUnwrap(json["state"] as? [String: Any])
        inner.removeValue(forKey: "decor")
        json["state"] = inner
        XCTAssertEqual(try SaveCodec.decode(JSONSerialization.data(withJSONObject: json)).decor, DecorState())
    }
}
