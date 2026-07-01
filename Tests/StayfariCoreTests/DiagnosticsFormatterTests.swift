import XCTest
@testable import StayfariCore

final class DiagnosticsFormatterTests: XCTestCase {
  func testDescribesIdleRoutingSummary() {
    let message = DiagnosticsFormatter.describe(URLRoutingSummary(actions: []))

    XCTAssertEqual(message, "No URL handled yet")
  }

  func testDescribesNewWindowRoutingSummary() {
    let message = DiagnosticsFormatter.describe(URLRoutingSummary(actions: [
      .openedNewWindow(URL(string: "https://example.com")!, browser: .safari)
    ]))

    XCTAssertEqual(message, "Opened new Safari window: https://example.com")
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

  func testDescribesDefaultBrowserStatus() {
    let message = DiagnosticsFormatter.describeDefaultBrowserStatus([
      SchemeHandlerStatus(scheme: .http, currentHandler: "com.hanwen.Stayfari", isStayfari: true),
      SchemeHandlerStatus(scheme: .https, currentHandler: "com.apple.Safari", isStayfari: false)
    ])

    XCTAssertEqual(message, "HTTP: Stayfari, HTTPS: com.apple.Safari")
  }

  func testDescribesDefaultBrowserStatusWithNoHandler() {
    let message = DiagnosticsFormatter.describeDefaultBrowserStatus([
      SchemeHandlerStatus(scheme: .https, currentHandler: nil, isStayfari: false)
    ])

    XCTAssertEqual(message, "HTTPS: none")
  }

  func testDescribesSetResults() {
    let message = DiagnosticsFormatter.describeSetResults([
      SchemeSetResult(scheme: .http, requestedHandler: "com.hanwen.Stayfari", status: noErr),
      SchemeSetResult(scheme: .https, requestedHandler: "com.hanwen.Stayfari", status: -1)
    ])

    XCTAssertEqual(message, "HTTP: OK, HTTPS: OSStatus -1")
  }
}
