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

  func testSafariEmptyWindowScriptWithoutBoundsOnlyCreatesWindow() {
    XCTAssertEqual(BrowserOpener.emptyWindowScriptSource(for: .safari, within: nil), """
    tell application id "com.apple.Safari"
      activate
      make new document
      set newWindow to front window
    end tell
    """)
  }

  func testHeliumEmptyWindowScriptMovesWindowOntoBounds() {
    let bounds = WindowBounds(left: 1440, top: 25, right: 3360, bottom: 1080)

    XCTAssertEqual(BrowserOpener.emptyWindowScriptSource(for: .helium, within: bounds), """
    tell application id "net.imput.helium"
      activate
      set newWindow to make new window with properties {mode:"normal"}
      set {windowLeft, windowTop, windowRight, windowBottom} to bounds of newWindow
      set windowCenterX to (windowLeft + windowRight) / 2
      set windowCenterY to (windowTop + windowBottom) / 2
      if windowCenterX < 1440 or windowCenterX > 3360 or windowCenterY < 25 or windowCenterY > 1080 then
        set windowWidth to windowRight - windowLeft
        if windowWidth > 1920 then set windowWidth to 1920
        set windowHeight to windowBottom - windowTop
        if windowHeight > 1055 then set windowHeight to 1055
        set newLeft to 1440 + (1920 - windowWidth) div 2
        set newTop to 25 + (1055 - windowHeight) div 2
        set bounds of newWindow to {newLeft, newTop, newLeft + windowWidth, newTop + windowHeight}
      end if
    end tell
    """)
  }

  func testWindowBoundsConvertsAppKitFrameToTopLeftOrigin() {
    // A display to the right of a 900-point-tall primary display, with its
    // bottom edge 200 points below the primary display's bottom edge.
    let frame = CGRect(x: 1440, y: -200, width: 1920, height: 1055)

    XCTAssertEqual(
      WindowBounds(appKitFrame: frame, primaryScreenHeight: 900),
      WindowBounds(left: 1440, top: 45, right: 3360, bottom: 1100)
    )
  }
}
