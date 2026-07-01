import XCTest
@testable import StayfariCore

final class DiagnosticsFormatterTests: XCTestCase {
  func testDescribesIdleRoutingSummary() {
    let message = DiagnosticsFormatter.describe(URLRoutingSummary(actions: []))

    XCTAssertEqual(message, "No URL handled yet")
  }

  func testDescribesNewWindowRoutingSummary() {
    let message = DiagnosticsFormatter.describe(URLRoutingSummary(actions: [
      .openedNewWindow(URL(string: "https://example.com")!, browser: .orion)
    ]))

    XCTAssertEqual(message, "Opened new Orion window: https://example.com")
  }

  func testDescribesRejectedRoutingSummary() {
    let message = DiagnosticsFormatter.describe(URLRoutingSummary(actions: [
      .rejected(URL(string: "stayfari://example")!)
    ]))

    XCTAssertEqual(message, "Ignored unsupported URL: stayfari://example")
  }

  func testDescribesOpenedNormallyRoutingSummary() {
    let message = DiagnosticsFormatter.describe(URLRoutingSummary(actions: [
      .openedNormally(URL(string: "https://example.com")!, browser: .safari)
    ]))

    XCTAssertEqual(message, "Opened normally: https://example.com")
  }

  func testDescribesFallbackRoutingSummary() {
    let message = DiagnosticsFormatter.describe(URLRoutingSummary(actions: [
      .fellBackToNormal(
        URL(string: "https://example.com")!,
        browser: .safari,
        reason: "Denied"
      )
    ]))

    XCTAssertEqual(message, "Opened normally after fallback: https://example.com")
  }

  func testDescribesFailedRoutingSummary() {
    let message = DiagnosticsFormatter.describe(URLRoutingSummary(actions: [
      .failed(
        URL(string: "https://example.com")!,
        browser: .safari,
        reason: "Automation denied"
      )
    ]))

    XCTAssertEqual(message, "Open failed: https://example.com (Automation denied)")
  }

  func testDescribesUnavailableBrowserWithoutIncludingURL() {
    let message = DiagnosticsFormatter.describe(URLRoutingSummary(actions: [
      .browserUnavailable(URL(string: "https://private.example/path")!, browser: .helium)
    ]))

    XCTAssertEqual(message, "Helium is unavailable")
    XCTAssertFalse(message.contains("private.example"))
  }

  func testDescribesDefaultBrowserStatus() {
    let message = DiagnosticsFormatter.describeDefaultBrowserStatus([
      SchemeHandlerStatus(scheme: .http, currentHandler: "io.hanwen.Browstay", isBrowstay: true),
      SchemeHandlerStatus(scheme: .https, currentHandler: "com.apple.Safari", isBrowstay: false)
    ])

    XCTAssertEqual(message, "HTTP: Browstay, HTTPS: com.apple.Safari")
  }

  func testDescribesDefaultBrowserStatusWithNoHandler() {
    let message = DiagnosticsFormatter.describeDefaultBrowserStatus([
      SchemeHandlerStatus(scheme: .https, currentHandler: nil, isBrowstay: false)
    ])

    XCTAssertEqual(message, "HTTPS: none")
  }

  func testDescribesSetResults() {
    let message = DiagnosticsFormatter.describeSetResults([
      SchemeSetResult(scheme: .http, requestedHandler: "io.hanwen.Browstay", status: noErr),
      SchemeSetResult(scheme: .https, requestedHandler: "io.hanwen.Browstay", status: -1)
    ])

    XCTAssertEqual(message, "HTTP: OK, HTTPS: OSStatus -1")
  }
}
