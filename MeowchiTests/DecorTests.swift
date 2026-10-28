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

    func testAppearanceAndTextureNames() {
        let store = makeStore()
        XCTAssertEqual(store.setAppearance("cream"), .ok)
        XCTAssertEqual(store.state.cat.appearanceID, "cream")
        XCTAssertEqual(store.setAppearance("plaid"), .unknownItem)
        XCTAssertEqual(CatAppearance.textureName("idle_0", appearance: "orange_white"), "cat_idle_0")
        XCTAssertEqual(CatAppearance.textureName("idle_0", appearance: "cream"), "cat_cream_idle_0")
        XCTAssertEqual(CatAppearance.textureName("idle_0", appearance: "bogus"), "cat_idle_0")
    }

    func testEveryReferencedSpriteExistsInTheBundle() {
        let names = DecorCatalog.items.map(\.id) + ["window_basic", "litter_clean", "litter_dirty", "bath_tub", "fx_laser"]
            + CatAppearance.allCases.flatMap { a in ["idle_0", "idle_1", "blink", "walk_0", "walk_1", "happy_0", "happy_1",
                                                    "sad", "eat_0", "eat_1", "sleep_0", "sleep_1"]
                .map { CatAppearance.textureName($0, appearance: a.rawValue) } }
            + ItemCatalog.foods.map(\.iconName)
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
