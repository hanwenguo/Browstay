import XCTest
@testable import Stayfari
@testable import StayfariCore

@MainActor
private final class SpySafariOpener: BrowserOpening {
  var normalBatches: [[WebURL]] = []
  var newWindowURLs: [WebURL] = []

  func isAvailable(_ browser: BrowserDefinition) -> Bool {
    true
  }

  func openNormally(_ urls: [WebURL], in browser: BrowserDefinition) async throws {
    normalBatches.append(urls)
  }

  func openInNewWindow(_ url: WebURL, in browser: BrowserDefinition) async throws {
    newWindowURLs.append(url)
  }
}

private struct StubSafariWindowDetector: BrowserWindowDetecting {
  func hasVisibleWindow(for browser: BrowserDefinition) async -> Bool {
    false
  }
}

private final class StubLaunchServicesClient: LaunchServicesClient {
  func copyDefaultHandler(for scheme: String) -> String? {
    StayfariVersion.safariBundleIdentifier
  }

  func setDefaultHandler(_ handler: String, for scheme: String) -> OSStatus {
    noErr
  }
}

final class AppRuntimeTests: XCTestCase {
  @MainActor
  func testDisableThenURLRoutesWithDisabledBehavior() async throws {
    let opener = SpySafariOpener()
    let runtime = makeRuntime(opener: opener)
    let url = URL(string: "https://disabled.example")!

    runtime.setEnabled(false)
    runtime.handleIncomingURLs([url])
    await runtime.waitForRuntimeCommands()

    XCTAssertFalse(runtime.isEnabled)
    XCTAssertEqual(opener.newWindowURLs, [])
    XCTAssertEqual(opener.normalBatches.map { $0.map(\.url.absoluteString) }, [["https://disabled.example"]])
    XCTAssertEqual(runtime.lastEventSummary, "Opened normally: https://disabled.example")
  }

  @MainActor
  func testQuickURLBatchesLeaveSummaryForSecondSubmittedURL() async throws {
    let opener = SpySafariOpener()
    let runtime = makeRuntime(opener: opener)

    runtime.handleIncomingURLs([URL(string: "https://first.example")!])
    runtime.handleIncomingURLs([URL(string: "https://second.example")!])
    await runtime.waitForRuntimeCommands()

    XCTAssertEqual(opener.newWindowURLs.map(\.url.absoluteString), [
      "https://first.example",
      "https://second.example"
    ])
    XCTAssertEqual(runtime.lastEventSummary, "Opened new Safari window: https://second.example")
  }

  @MainActor
  private func makeRuntime(opener: SpySafariOpener) -> AppRuntime {
    AppRuntime(
      router: URLRouter(detector: StubSafariWindowDetector(), opener: opener),
      defaultBrowserManager: DefaultBrowserManager(launchServicesClient: StubLaunchServicesClient())
    )
  }
}
