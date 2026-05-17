import XCTest
@testable import StayfariCore

@MainActor
private final class SpySafariOpener: SafariOpening {
  var normalBatches: [[WebURL]] = []
  var newWindowURLs: [WebURL] = []
  var newWindowError: Error?
  var normalError: Error?

  func openNormally(_ urls: [WebURL]) async throws {
    normalBatches.append(urls)
    if let normalError {
      throw normalError
    }
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

@MainActor
private final class BlockingSafariOpener: SafariOpening {
  private(set) var events: [String] = []
  private(set) var maximumActiveOpenCalls = 0

  private var activeOpenCalls = 0
  private var continuations: [CheckedContinuation<Void, Never>] = []
  private var startWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

  func openNormally(_ urls: [WebURL]) async throws {
    let url = urls[0].url.absoluteString
    activeOpenCalls += 1
    maximumActiveOpenCalls = max(maximumActiveOpenCalls, activeOpenCalls)
    if activeOpenCalls > 1 {
      XCTFail("URL routing opened multiple batches concurrently")
    }
    events.append("start:\(url)")
    resumeSatisfiedStartWaiters()

    await withCheckedContinuation { continuation in
      continuations.append(continuation)
    }

    events.append("finish:\(url)")
    activeOpenCalls -= 1
  }

  func openInNewWindow(_ url: WebURL) async throws {
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

  @MainActor
  func testConcurrentHandleCallsDoNotOverlapAndCompleteInSubmissionOrder() async throws {
    let opener = BlockingSafariOpener()
    let router = URLRouter(
      detector: StubSafariWindowDetector(hasVisibleWindow: true),
      opener: opener
    )

    let firstTask = Task {
      await router.handle([URL(string: "https://first.example")!])
    }
    await opener.waitForOpenStart(count: 1)
    XCTAssertEqual(opener.events, ["start:https://first.example"])

    let secondTask = Task {
      await router.handle([URL(string: "https://second.example")!])
    }

    await assertNoAdditionalOpenStarts(on: opener)
    XCTAssertEqual(opener.events, ["start:https://first.example"])
    XCTAssertEqual(opener.maximumActiveOpenCalls, 1)

    opener.resumeNextOpen()
    let firstSummary = await firstTask.value
    await opener.waitForOpenStart(count: 2)
    opener.resumeNextOpen()
    let secondSummary = await secondTask.value

    XCTAssertEqual(opener.maximumActiveOpenCalls, 1)
    XCTAssertEqual(opener.events, [
      "start:https://first.example",
      "finish:https://first.example",
      "start:https://second.example",
      "finish:https://second.example"
    ])
    XCTAssertEqual(firstSummary.actions, [.openedNormally(URL(string: "https://first.example")!)])
    XCTAssertEqual(secondSummary.actions, [.openedNormally(URL(string: "https://second.example")!)])
  }

  @MainActor
  func testMixedValidAndRejectedURLsPreserveInputOrderInSummaryActions() async throws {
    let opener = SpySafariOpener()
    let router = URLRouter(
      detector: StubSafariWindowDetector(hasVisibleWindow: true),
      opener: opener
    )

    let first = URL(string: "https://first.example")!
    let rejected = URL(string: "mailto:hello@example.com")!
    let second = URL(string: "https://second.example")!
    let summary = await router.handle([first, rejected, second])

    XCTAssertEqual(opener.normalBatches.map { $0.map(\.url.absoluteString) }, [[
      "https://first.example",
      "https://second.example"
    ]])
    XCTAssertEqual(summary.actions, [
      .openedNormally(first),
      .rejected(rejected),
      .openedNormally(second)
    ])
  }

  @MainActor
  func testFallbackNormalOpenFailureReportsFailedAction() async throws {
    let opener = SpySafariOpener()
    opener.newWindowError = TestRoutingError()
    opener.normalError = TestRoutingError()
    let router = URLRouter(
      detector: StubSafariWindowDetector(hasVisibleWindow: false),
      opener: opener
    )

    let url = URL(string: "https://failure.example")!
    let summary = await router.handle([url])

    XCTAssertEqual(opener.normalBatches.map { $0.map(\.url.absoluteString) }, [["https://failure.example"]])
    XCTAssertEqual(summary.actions, [
      .failed(url, reason: "TestRoutingError()")
    ])
  }

  @MainActor
  private func assertNoAdditionalOpenStarts(
    on opener: BlockingSafariOpener,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async {
    // Let the second handle call enqueue on URLRouter. Any overlap is detected
    // by BlockingSafariOpener immediately and reflected in the event log.
    await Task.yield()
    if opener.events != ["start:https://first.example"] {
      XCTFail("Second open started before the first completed: \(opener.events)", file: file, line: line)
    }
    if opener.maximumActiveOpenCalls != 1 {
      XCTFail("Open calls overlapped", file: file, line: line)
    }
  }
}
