import XCTest

/// App Store screenshots. Runs only in the "Ekran görüntüleri" workflow (`MEOWCHI_SCREENSHOTS=1`).
///
/// Every shot is a fresh launch with `-screenshots` (sample progress in memory, DEBUG only) and
/// `-openScreen <screen>`, so no taps or back buttons are needed. Attachments are named
/// `<lang>_<order>_<name>` for Tools/collect_screenshots.py (7 shots per language).
final class ScreenshotTests: XCTestCase {
    private let shots: [(name: String, screen: String?)] = [
        ("01_home", nil), ("02_food", "food"), ("03_decor", "decor"), ("04_laser", "laser"),
        ("05_garden", "garden"), ("06_shop", "shop"), ("07_collection", "collection"),
    ]

    override func setUp() {
        continueAfterFailure = false
    }

    func testCaptureStoreScreenshots() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["MEOWCHI_SCREENSHOTS"] == "1" else {
            throw XCTSkip("Only runs in the screenshots workflow")
        }
        let language = environment["MEOWCHI_LANG"] ?? "en"
        let locale = environment["MEOWCHI_LOCALE"] ?? "en_US"

        for shot in shots {
            let app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", locale, "-screenshots"]
            if let screen = shot.screen { app.launchArguments += ["-openScreen", screen] }
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30), "App did not start")
            Thread.sleep(forTimeInterval: 4)
            XCTAssertEqual(app.state, .runningForeground, "App closed on \(shot.name)")
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "\(language)_\(shot.name)"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }
    }
}
