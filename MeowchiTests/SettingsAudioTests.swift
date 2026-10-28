import XCTest
@testable import Meowchi

@MainActor
final class SettingsAudioTests: XCTestCase {
    func testOldSettingsDecodeWithDefaultVolumes() throws {
        let settings = try JSONDecoder().decode(GameSettings.self, from: Data(#"{"soundEnabled":false,"musicEnabled":true}"#.utf8))
        XCTAssertFalse(settings.soundEnabled)
        XCTAssertEqual(settings.musicVolume, 0.5)
        XCTAssertEqual(settings.sfxVolume, 0.8)
        let wild = try JSONDecoder().decode(GameSettings.self, from: Data(#"{"sfxVolume":7,"musicVolume":-2}"#.utf8))
        XCTAssertEqual(wild.sfxVolume, 1)
        XCTAssertEqual(wild.musicVolume, 0)
    }

    func testUpdateSettingsPersistsAndClamps() throws {
        let save = InMemorySaveStore()
        let store = GameStore(saveStore: save)
        var settings = store.state.settings
        settings.musicEnabled = false
        settings.musicVolume = 3
        store.updateSettings(settings)
        let reloaded = try XCTUnwrap(try save.load())
        XCTAssertFalse(reloaded.settings.musicEnabled)
        XCTAssertEqual(reloaded.settings.musicVolume, 1)
    }

    func testEveryAudioFileIsBundled() {
        XCTAssertNotNil(Bundle.main.url(forResource: "music_home", withExtension: "caf"))
        for sound in AudioManager.Sound.allCases {
            XCTAssertNotNil(Bundle.main.url(forResource: sound.fileName, withExtension: "caf"), sound.fileName)
        }
    }
}
