import XCTest
@testable import StayfariCore

@MainActor
private final class SpySafariOpener: SafariOpening {
  var normalBatches: [[WebURL]] = []
  var newWindowURLs: [WebURL] = []
  var newWindowError: Error?

  func openNormally(_ urls: [WebURL]) async throws {
    normalBatches.append(urls)
  }

  func openInNewWindow(_ url: WebURL) async throws {
    if let newWindowError {
      throw newWindowError
    }
    newWindowURLs.append(url)
  }
}

private struct StubSafariWindowDetector: SafariWindowDetecting {
  let hasVisibleWindow: Bool

  func hasVisibleSafariWindow() async -> Bool {
    hasVisibleWindow
  }
}

private struct TestRoutingError: Error, Equatable {}

final class URLRouterTests: XCTestCase {
  @MainActor
  func testVisibleSafariWindowUsesNormalOpening() async throws {
    let opener = SpySafariOpener()
    let router = URLRouter(
      detector: StubSafariWindowDetector(hasVisibleWindow: true),
      opener: opener
    )

    let summary = await router.handle([
      URL(string: "https://example.com")!
    ])

    XCTAssertEqual(opener.normalBatches.map { $0.map(\.url.absoluteString) }, [["https://example.com"]])
    XCTAssertEqual(opener.newWindowURLs, [])
    XCTAssertEqual(summary.actions, [.openedNormally(URL(string: "https://example.com")!)])
  }

  @MainActor
  func testNoVisibleSafariWindowCreatesOneNewWindowForFirstURL() async throws {
    let opener = SpySafariOpener()
    let router = URLRouter(
      detector: StubSafariWindowDetector(hasVisibleWindow: false),
      opener: opener
    )

    let summary = await router.handle([
      URL(string: "https://first.example")!,
      URL(string: "https://second.example")!
    ])

    XCTAssertEqual(opener.newWindowURLs.map(\.url.absoluteString), ["https://first.example"])
    XCTAssertEqual(opener.normalBatches.map { $0.map(\.url.absoluteString) }, [["https://second.example"]])
    XCTAssertEqual(summary.actions, [
      .openedNewWindow(URL(string: "https://first.example")!),
      .openedNormally(URL(string: "https://second.example")!)
    ])
  }

  @MainActor
  func testAutomationFailureFallsBackToNormalSafariOpen() async throws {
    let opener = SpySafariOpener()
    opener.newWindowError = TestRoutingError()
    let router = URLRouter(
      detector: StubSafariWindowDetector(hasVisibleWindow: false),
      opener: opener
    )

    let summary = await router.handle([
      URL(string: "https://fallback.example")!
    ])

    XCTAssertEqual(opener.normalBatches.map { $0.map(\.url.absoluteString) }, [["https://fallback.example"]])
    XCTAssertEqual(summary.actions, [
      .fellBackToNormal(URL(string: "https://fallback.example")!, reason: "TestRoutingError()")
    ])
  }

  @MainActor
  func testDisabledRouterAlwaysUsesNormalOpening() async throws {
    let opener = SpySafariOpener()
    let router = URLRouter(
      detector: StubSafariWindowDetector(hasVisibleWindow: false),
      opener: opener,
      isEnabled: false
    )

    let summary = await router.handle([
      URL(string: "https://disabled.example")!
    ])

    XCTAssertEqual(opener.newWindowURLs, [])
    XCTAssertEqual(opener.normalBatches.map { $0.map(\.url.absoluteString) }, [["https://disabled.example"]])
    XCTAssertEqual(summary.actions, [
      .openedNormally(URL(string: "https://disabled.example")!)
    ])
  }

  @MainActor
  func testRejectedURLsAreReportedAndNotOpened() async throws {
    let opener = SpySafariOpener()
    let router = URLRouter(
      detector: StubSafariWindowDetector(hasVisibleWindow: true),
      opener: opener
    )

    let rejectedURL = URL(string: "mailto:hello@example.com")!
    let summary = await router.handle([rejectedURL])

    XCTAssertEqual(opener.normalBatches, [])
    XCTAssertEqual(opener.newWindowURLs, [])
    XCTAssertEqual(summary.actions, [.rejected(rejectedURL)])
  }
}
