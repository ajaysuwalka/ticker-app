import XCTest
@testable import Ticker

final class CategoryGuesserTests: XCTestCase {

    func testProductiveApps() {
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.apple.dt.Xcode", name: "Xcode"), .productive)
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.microsoft.VSCode", name: "Visual Studio Code"), .productive)
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "md.obsidian", name: "Obsidian"), .productive)
    }

    func testExpandedProductiveHeuristics() {
        // Dev tooling, PM, design, data — all should read as productive now.
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.google.android.studio", name: "Android Studio"), .productive)
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.linear", name: "Linear"), .productive)
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.figma.Desktop", name: "Figma"), .productive)
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.tinybuild.tableplus", name: "TablePlus"), .productive)
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.jetbrains.intellij", name: "IntelliJ IDEA"), .productive)
    }

    func testWorkCommunicationIsProductive() {
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.tinyspeck.slackmacgap", name: "Slack"), .productive)
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "us.zoom.xos", name: "zoom.us"), .productive)
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.microsoft.teams2", name: "Microsoft Teams"), .productive)
    }

    func testOfficeTokensDoNotFalseMatchUtilities() {
        // "word" must not match 1Password just because it contains the substring.
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.agilebits.onepassword7", name: "1Password"), .neutral)
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.microsoft.Word", name: "Microsoft Word"), .productive)
    }

    func testDistractingApps() {
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.google.Chrome", name: "YouTube"), .distracting)
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.valvesoftware.steam", name: "Steam"), .distracting)
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.netflix.Netflix", name: "Netflix"), .distracting)
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.amazon.avod", name: "Prime Video"), .distracting)
    }

    func testUnknownIsNeutral() {
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.example.mystery", name: "Mystery"), .neutral)
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "com.spotify.client", name: "Spotify"), .neutral)
    }

    func testDistractingTakesPrecedence() {
        XCTAssertEqual(CategoryGuesser.guess(bundleId: "x", name: "Some Game Editor"), .distracting)
    }
}
