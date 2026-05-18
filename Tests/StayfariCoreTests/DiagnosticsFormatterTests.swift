import XCTest
@testable import StayfariCore

final class DiagnosticsFormatterTests: XCTestCase {
  func testDescribesIdleRoutingSummary() {
    let message = DiagnosticsFormatter.describe(URLRoutingSummary(actions: []))

    XCTAssertEqual(message, "No URL handled yet")
  }

  func testDescribesNewWindowRoutingSummary() {
    let message = DiagnosticsFormatter.describe(URLRoutingSummary(actions: [
      .openedNewWindow(URL(string: "https://example.com")!)
    ]))

    XCTAssertEqual(message, "Opened new Safari window: https://example.com")
  }

  func testDescribesFallbackRoutingSummary() {
    let message = DiagnosticsFormatter.describe(URLRoutingSummary(actions: [
      .fellBackToNormal(URL(string: "https://example.com")!, reason: "Denied")
    ]))

    XCTAssertEqual(message, "Opened normally after fallback: https://example.com")
  }

  func testDescribesDefaultBrowserStatus() {
    let message = DiagnosticsFormatter.describeDefaultBrowserStatus([
      SchemeHandlerStatus(scheme: .http, currentHandler: "com.hanwen.Stayfari", isStayfari: true),
      SchemeHandlerStatus(scheme: .https, currentHandler: "com.apple.Safari", isStayfari: false)
    ])

    XCTAssertEqual(message, "HTTP: Stayfari, HTTPS: com.apple.Safari")
  }
}
