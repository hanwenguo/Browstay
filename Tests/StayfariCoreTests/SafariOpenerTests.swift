import XCTest
@testable import StayfariCore

final class SafariOpenerTests: XCTestCase {
  func testAppleScriptStringLiteralEscapesQuotesBackslashesAndNewlines() {
    let literal = SafariOpener.appleScriptStringLiteral("https://example.com/a\"b\\c\nnext")

    XCTAssertEqual(literal, "\"https://example.com/a\\\"b\\\\c\\nnext\"")
  }

  func testNewWindowScriptTargetsSafariByBundleIdentifier() throws {
    let webURL = try XCTUnwrap(WebURL(URL(string: "https://example.com/path?q=1")!))

    let source = SafariOpener.newWindowScriptSource(for: webURL)

    XCTAssertEqual(source, """
    tell application id "com.apple.Safari"
      activate
      make new document with properties {URL:"https://example.com/path?q=1"}
    end tell
    """)
  }
}
