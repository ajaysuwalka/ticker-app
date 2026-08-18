import XCTest
@testable import Ticker

final class CategoryGuesserTests: XCTestCase {

    func testProductiveApps() {
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.apple.dt.Xcode", name: "Xcode"), .productive)
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.microsoft.VSCode", name: "Visual Studio Code"), .productive)
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "md.obsidian", name: "Obsidian"), .productive)
    }

    func testDistractingApps() {
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.google.Chrome", name: "YouTube"), .distracting)
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.valvesoftware.steam", name: "Steam"), .distracting)
    }

    func testUnknownIsNeutral() {
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.tinyspeck.slackmacgap", name: "Slack"), .neutral)
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.example.mystery", name: "Mystery"), .neutral)
    }

    func testDistractingTakesPrecedence() {
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "x", name: "Some Game Editor"), .distracting)
    }
}
