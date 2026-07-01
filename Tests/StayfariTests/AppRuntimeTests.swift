import XCTest
@testable import Stayfari
@testable import StayfariCore

@MainActor
private final class SpyBrowserOpener: BrowserOpening {
  var availableBrowserIDs = Set(BrowserID.allCases)
  var normalBatches: [(browser: BrowserID, urls: [WebURL])] = []
  var newWindowRequests: [(browser: BrowserID, url: WebURL)] = []

  func isAvailable(_ browser: BrowserDefinition) -> Bool {
    availableBrowserIDs.contains(browser.id)
  }

  func openNormally(_ urls: [WebURL], in browser: BrowserDefinition) async throws {
    normalBatches.append((browser: browser.id, urls: urls))
  }

  func openInNewWindow(_ url: WebURL, in browser: BrowserDefinition) async throws {
    newWindowRequests.append((browser: browser.id, url: url))
  }
}

private struct StubBrowserWindowDetector: BrowserWindowDetecting {
  func hasVisibleWindow(for browser: BrowserDefinition) async -> Bool {
    false
  }
}

private final class MutableBrowserApplicationLocator: BrowserApplicationLocating {
  var applicationURLs: [String: URL]

  init(browserIDs: [BrowserID]) {
    applicationURLs = Dictionary(uniqueKeysWithValues: browserIDs.map { browserID in
      let browser = BrowserDefinition.definition(for: browserID)
      return (
        browser.bundleIdentifier,
        URL(fileURLWithPath: "/Applications/\(browser.displayName).app")
      )
    })
  }

  func applicationURL(forBundleIdentifier bundleIdentifier: String) -> URL? {
    applicationURLs[bundleIdentifier]
  }
}

private final class MemorySelectionDefaults: BrowserSelectionDefaults {
  var values: [String: String] = [:]

  func string(forKey defaultName: String) -> String? {
    values[defaultName]
  }

  func set(_ value: String, forKey defaultName: String) {
    values[defaultName] = value
  }
}

private final class RecordingLaunchServicesClient: LaunchServicesClient {
  var handlers: [String: String?] = [
    "http": "com.apple.Safari",
    "https": "com.apple.Safari"
  ]
  var setCalls: [(scheme: String, handler: String)] = []

  func copyDefaultHandler(for scheme: String) -> String? {
    handlers[scheme] ?? nil
  }

  func setDefaultHandler(_ handler: String, for scheme: String) -> OSStatus {
    setCalls.append((scheme: scheme, handler: handler))
    handlers[scheme] = handler
    return noErr
  }
}

@MainActor
private final class SpyRoutingFailureReporter: RoutingFailureReporting {
  var authorizationRequests = 0
  var summaries: [URLRoutingSummary] = []

  func requestAuthorization() async {
    authorizationRequests += 1
  }

  func report(_ summary: URLRoutingSummary) async {
    summaries.append(summary)
  }
}

final class AppRuntimeTests: XCTestCase {
  @MainActor
  func testPersistedSelectionTargetsIncomingURLs() async {
    let defaults = MemorySelectionDefaults()
    defaults.values[BrowserSelectionStore.selectionKey] = BrowserID.orion.rawValue
    let opener = SpyBrowserOpener()
    let runtime = makeRuntime(
      opener: opener,
      selectionDefaults: defaults,
      installedBrowserIDs: [.safari, .orion]
    ).runtime

    runtime.handleIncomingURLs([URL(string: "https://orion.example")!])
    await runtime.waitForRuntimeCommands()

    XCTAssertEqual(runtime.selectedBrowserID, .orion)
    XCTAssertEqual(opener.newWindowRequests.map(\.browser), [.orion])
    XCTAssertEqual(runtime.lastEventSummary, "Opened new Orion window: https://orion.example")
  }

  @MainActor
  func testSelectingBrowserPersistsAndTestOpenUsesNewTarget() async {
    let defaults = MemorySelectionDefaults()
    let opener = SpyBrowserOpener()
    let runtime = makeRuntime(
      opener: opener,
      selectionDefaults: defaults,
      installedBrowserIDs: [.safari, .helium]
    ).runtime

    runtime.selectBrowser(.helium)
    runtime.openTestURL()
    await runtime.waitForRuntimeCommands()

    XCTAssertEqual(defaults.values[BrowserSelectionStore.selectionKey], "helium")
    XCTAssertEqual(opener.newWindowRequests.map(\.browser), [.helium])
  }

  @MainActor
  func testRefreshUpdatesInstalledBrowsersAndAvailability() {
    let setup = makeRuntime(installedBrowserIDs: [.safari])
    let runtime = setup.runtime

    XCTAssertEqual(runtime.installedBrowsers.map(\.definition.id), [.safari])
    XCTAssertFalse(runtime.isBrowserInstalled(.orion))

    setup.applicationLocator.applicationURLs[BrowserDefinition.orion.bundleIdentifier] =
      URL(fileURLWithPath: "/Applications/Orion.app")
    runtime.refreshBrowsersAndStatus()

    XCTAssertEqual(runtime.installedBrowsers.map(\.definition.id), [.safari, .orion])
    XCTAssertTrue(runtime.isBrowserInstalled(.orion))
  }

  @MainActor
  func testSetDefaultRequestsNotificationsAndRestoreUsesSelectedBrowser() async {
    let setup = makeRuntime(installedBrowserIDs: [.safari, .orion])
    let runtime = setup.runtime
    runtime.selectBrowser(.orion)

    runtime.setAsDefaultBrowser()
    await runtime.waitForRuntimeCommands()
    runtime.restoreSelectedBrowserAsDefault()

    XCTAssertEqual(setup.failureReporter.authorizationRequests, 1)
    XCTAssertEqual(setup.launchServicesClient.setCalls.map(\.handler), [
      "io.hanwen.Browstay",
      "io.hanwen.Browstay",
      "com.kagi.kagimacOS",
      "com.kagi.kagimacOS"
    ])
  }

  @MainActor
  func testDisableThenURLUsesNormalOpeningInSelectedBrowser() async {
    let opener = SpyBrowserOpener()
    let runtime = makeRuntime(opener: opener, installedBrowserIDs: [.safari]).runtime

    runtime.setEnabled(false)
    runtime.handleIncomingURLs([URL(string: "https://disabled.example")!])
    await runtime.waitForRuntimeCommands()

    XCTAssertEqual(opener.normalBatches.map(\.browser), [.safari])
    XCTAssertEqual(runtime.lastEventSummary, "Opened normally: https://disabled.example")
  }

  @MainActor
  private func makeRuntime(
    opener: SpyBrowserOpener = SpyBrowserOpener(),
    selectionDefaults: MemorySelectionDefaults = MemorySelectionDefaults(),
    installedBrowserIDs: [BrowserID]
  ) -> (
    runtime: AppRuntime,
    applicationLocator: MutableBrowserApplicationLocator,
    launchServicesClient: RecordingLaunchServicesClient,
    failureReporter: SpyRoutingFailureReporter
  ) {
    let applicationLocator = MutableBrowserApplicationLocator(browserIDs: installedBrowserIDs)
    let launchServicesClient = RecordingLaunchServicesClient()
    let failureReporter = SpyRoutingFailureReporter()
    let runtime = AppRuntime(
      router: URLRouter(detector: StubBrowserWindowDetector(), opener: opener),
      defaultBrowserManager: DefaultBrowserManager(
        ownBundleIdentifier: "io.hanwen.Browstay",
        launchServicesClient: launchServicesClient
      ),
      browserCatalog: BrowserCatalog(applicationLocator: applicationLocator),
      selectionStore: BrowserSelectionStore(defaults: selectionDefaults),
      failureReporter: failureReporter
    )

    return (runtime, applicationLocator, launchServicesClient, failureReporter)
  }
}
