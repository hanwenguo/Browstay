import XCTest
@testable import BrowstayCore

@MainActor
private final class SpyBrowserOpener: BrowserOpening {
  var available = true
  var normalBatches: [(browser: BrowserID, urls: [WebURL])] = []
  var newWindowRequests: [(browser: BrowserID, url: WebURL)] = []
  var newWindowError: Error?
  var normalError: Error?

  func isAvailable(_ browser: BrowserDefinition) -> Bool {
    available
  }

  func openNormally(_ urls: [WebURL], in browser: BrowserDefinition) async throws {
    normalBatches.append((browser: browser.id, urls: urls))
    if let normalError {
      throw normalError
    }
  }

  func openInNewWindow(_ url: WebURL, in browser: BrowserDefinition) async throws {
    if let newWindowError {
      throw newWindowError
    }
    newWindowRequests.append((browser: browser.id, url: url))
  }

  func openEmptyWindow(in browser: BrowserDefinition, within bounds: WindowBounds?) async throws {
    XCTFail("URL routing should not open empty windows")
  }
}

private struct StubBrowserWindowDetector: BrowserWindowDetecting {
  let hasVisibleWindow: Bool

  func hasVisibleWindow(for browser: BrowserDefinition) async -> Bool {
    hasVisibleWindow
  }
}

private struct TestRoutingError: Error, Equatable {}

@MainActor
private final class BlockingBrowserOpener: BrowserOpening {
  private(set) var events: [String] = []
  private(set) var maximumActiveOpenCalls = 0

  private var activeOpenCalls = 0
  private var continuations: [CheckedContinuation<Void, Never>] = []
  private var startWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

  func isAvailable(_ browser: BrowserDefinition) -> Bool {
    true
  }

  func openNormally(_ urls: [WebURL], in browser: BrowserDefinition) async throws {
    let event = "\(browser.id.rawValue):\(urls[0].url.absoluteString)"
    activeOpenCalls += 1
    maximumActiveOpenCalls = max(maximumActiveOpenCalls, activeOpenCalls)
    if activeOpenCalls > 1 {
      XCTFail("URL routing opened multiple batches concurrently")
    }
    events.append("start:\(event)")
    resumeSatisfiedStartWaiters()

    await withCheckedContinuation { continuation in
      continuations.append(continuation)
    }

    events.append("finish:\(event)")
    activeOpenCalls -= 1
  }

  func openInNewWindow(_ url: WebURL, in browser: BrowserDefinition) async throws {
    XCTFail("Expected normal opening only")
  }

  func openEmptyWindow(in browser: BrowserDefinition, within bounds: WindowBounds?) async throws {
    XCTFail("Expected normal opening only")
  }

  func resumeNextOpen() {
    continuations.removeFirst().resume()
  }

  func waitForOpenStart(count: Int) async {
    if openStartCount >= count {
      return
    }

    await withCheckedContinuation { continuation in
      startWaiters.append((count: count, continuation: continuation))
    }
  }

  private var openStartCount: Int {
    events.filter { $0.hasPrefix("start:") }.count
  }

  private func resumeSatisfiedStartWaiters() {
    let readyWaiters = startWaiters.filter { openStartCount >= $0.count }
    startWaiters.removeAll { openStartCount >= $0.count }
    for waiter in readyWaiters {
      waiter.continuation.resume()
    }
  }
}

private actor RouteEnqueueProbe {
  private var latestCount = 0
  private var waiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

  func record(_ count: Int) {
    latestCount = max(latestCount, count)
    let readyWaiters = waiters.filter { latestCount >= $0.count }
    waiters.removeAll { latestCount >= $0.count }
    for waiter in readyWaiters {
      waiter.continuation.resume()
    }
  }

  func waitForCount(_ count: Int) async {
    if latestCount >= count {
      return
    }

    await withCheckedContinuation { continuation in
      waiters.append((count: count, continuation: continuation))
    }
  }
}

final class URLRouterTests: XCTestCase {
  @MainActor
  func testVisibleTargetWindowUsesNormalOpening() async {
    let opener = SpyBrowserOpener()
    let router = URLRouter(
      detector: StubBrowserWindowDetector(hasVisibleWindow: true),
      opener: opener
    )
    let url = URL(string: "https://example.com")!

    let summary = await router.handle([url], target: .orion)

    XCTAssertEqual(opener.normalBatches.map(\.browser), [.orion])
    XCTAssertEqual(opener.normalBatches.flatMap(\.urls).map(\.url), [url])
    XCTAssertEqual(opener.newWindowRequests.count, 0)
    XCTAssertEqual(summary.actions, [.openedNormally(url, browser: .orion)])
  }

  @MainActor
  func testNoVisibleTargetWindowCreatesOneWindowThenOpensRemainingNormally() async {
    let opener = SpyBrowserOpener()
    let router = URLRouter(
      detector: StubBrowserWindowDetector(hasVisibleWindow: false),
      opener: opener
    )
    let first = URL(string: "https://first.example")!
    let second = URL(string: "https://second.example")!

    let summary = await router.handle([first, second], target: .helium)

    XCTAssertEqual(opener.newWindowRequests.map(\.browser), [.helium])
    XCTAssertEqual(opener.newWindowRequests.map(\.url.url), [first])
    XCTAssertEqual(opener.normalBatches.flatMap(\.urls).map(\.url), [second])
    XCTAssertEqual(summary.actions, [
      .openedNewWindow(first, browser: .helium),
      .openedNormally(second, browser: .helium)
    ])
  }

  @MainActor
  func testUnavailableTargetFailsWithoutOpening() async {
    let opener = SpyBrowserOpener()
    opener.available = false
    let router = URLRouter(
      detector: StubBrowserWindowDetector(hasVisibleWindow: false),
      opener: opener
    )
    let url = URL(string: "https://missing.example")!

    let summary = await router.handle([url], target: .orion)

    XCTAssertEqual(opener.normalBatches.count, 0)
    XCTAssertEqual(opener.newWindowRequests.count, 0)
    XCTAssertEqual(summary.actions, [.browserUnavailable(url, browser: .orion)])
  }

  @MainActor
  func testAutomationFailureFallsBackToSameBrowserForCompleteBatch() async {
    let opener = SpyBrowserOpener()
    opener.newWindowError = TestRoutingError()
    let router = URLRouter(
      detector: StubBrowserWindowDetector(hasVisibleWindow: false),
      opener: opener
    )
    let first = URL(string: "https://first.example")!
    let second = URL(string: "https://second.example")!

    let summary = await router.handle([first, second], target: .orion)

    XCTAssertEqual(opener.normalBatches.map(\.browser), [.orion])
    XCTAssertEqual(opener.normalBatches.flatMap(\.urls).map(\.url), [first, second])
    XCTAssertEqual(summary.actions, [
      .fellBackToNormal(first, browser: .orion, reason: "TestRoutingError()"),
      .fellBackToNormal(second, browser: .orion, reason: "TestRoutingError()")
    ])
  }

  @MainActor
  func testNormalFallbackFailureReportsSelectedBrowser() async {
    let opener = SpyBrowserOpener()
    opener.newWindowError = TestRoutingError()
    opener.normalError = TestRoutingError()
    let router = URLRouter(
      detector: StubBrowserWindowDetector(hasVisibleWindow: false),
      opener: opener
    )
    let url = URL(string: "https://failure.example")!

    let summary = await router.handle([url], target: .helium)

    XCTAssertEqual(summary.actions, [
      .failed(url, browser: .helium, reason: "TestRoutingError()")
    ])
  }

  @MainActor
  func testDisabledRouterUsesNormalOpeningInSelectedBrowser() async {
    let opener = SpyBrowserOpener()
    let router = URLRouter(
      detector: StubBrowserWindowDetector(hasVisibleWindow: false),
      opener: opener,
      isEnabled: false
    )
    let url = URL(string: "https://disabled.example")!

    let summary = await router.handle([url], target: .helium)

    XCTAssertEqual(opener.normalBatches.map(\.browser), [.helium])
    XCTAssertEqual(summary.actions, [.openedNormally(url, browser: .helium)])
  }

  @MainActor
  func testMixedValidAndRejectedURLsPreserveInputOrder() async {
    let opener = SpyBrowserOpener()
    let router = URLRouter(
      detector: StubBrowserWindowDetector(hasVisibleWindow: true),
      opener: opener
    )
    let first = URL(string: "https://first.example")!
    let rejected = URL(string: "mailto:hello@example.com")!
    let second = URL(string: "https://second.example")!

    let summary = await router.handle([first, rejected, second], target: .safari)

    XCTAssertEqual(summary.actions, [
      .openedNormally(first, browser: .safari),
      .rejected(rejected),
      .openedNormally(second, browser: .safari)
    ])
  }

  @MainActor
  func testConcurrentRoutesKeepSubmissionOrderAndCapturedTargets() async {
    let opener = BlockingBrowserOpener()
    let enqueueProbe = RouteEnqueueProbe()
    let router = URLRouter(
      detector: StubBrowserWindowDetector(hasVisibleWindow: true),
      opener: opener,
      didEnqueueRoute: { count in
        Task { await enqueueProbe.record(count) }
      }
    )
    let firstURL = URL(string: "https://first.example")!
    let secondURL = URL(string: "https://second.example")!

    let firstTask = Task {
      await router.handle([firstURL], target: .orion)
    }
    await opener.waitForOpenStart(count: 1)

    let secondTask = Task {
      await router.handle([secondURL], target: .helium)
    }
    await enqueueProbe.waitForCount(2)

    XCTAssertEqual(opener.maximumActiveOpenCalls, 1)
    opener.resumeNextOpen()
    let firstSummary = await firstTask.value
    await opener.waitForOpenStart(count: 2)
    opener.resumeNextOpen()
    let secondSummary = await secondTask.value

    XCTAssertEqual(opener.events, [
      "start:orion:https://first.example",
      "finish:orion:https://first.example",
      "start:helium:https://second.example",
      "finish:helium:https://second.example"
    ])
    XCTAssertEqual(firstSummary.actions, [.openedNormally(firstURL, browser: .orion)])
    XCTAssertEqual(secondSummary.actions, [.openedNormally(secondURL, browser: .helium)])
  }
}
