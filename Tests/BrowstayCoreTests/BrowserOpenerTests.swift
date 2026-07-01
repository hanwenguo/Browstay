import Foundation
import XCTest
@testable import BrowstayCore

final class BrowserOpenerTests: XCTestCase {
  func testAppleScriptStringLiteralEscapesQuotesBackslashesAndNewlines() {
    let literal = BrowserOpener.appleScriptStringLiteral("https://example.com/a\"b\\c\nnext")

    XCTAssertEqual(literal, "\"https://example.com/a\\\"b\\\\c\\nnext\"")
  }

  func testSafariNewWindowScriptCreatesDocumentWithURL() throws {
    let webURL = try XCTUnwrap(WebURL(URL(string: "https://example.com/safari")!))

    XCTAssertEqual(BrowserOpener.newWindowScriptSource(for: webURL, browser: .safari), """
    tell application id "com.apple.Safari"
      activate
      make new document with properties {URL:"https://example.com/safari"}
    end tell
    """)
  }

  func testOrionNewWindowScriptCreatesDocumentWithURL() throws {
    let webURL = try XCTUnwrap(WebURL(URL(string: "https://example.com/orion")!))

    XCTAssertEqual(BrowserOpener.newWindowScriptSource(for: webURL, browser: .orion), """
    tell application id "com.kagi.kagimacOS"
      activate
      make new document with properties {URL:"https://example.com/orion"}
    end tell
    """)
  }

  func testHeliumNewWindowScriptCreatesNormalChromiumWindow() throws {
    let webURL = try XCTUnwrap(WebURL(URL(string: "https://example.com/helium")!))

    XCTAssertEqual(BrowserOpener.newWindowScriptSource(for: webURL, browser: .helium), """
    tell application id "net.imput.helium"
      activate
      set newWindow to make new window with properties {mode:"normal"}
      set URL of active tab of newWindow to "https://example.com/helium"
    end tell
    """)
  }
}
