import Foundation
import Observation
import StayfariCore

@MainActor
@Observable
final class AppRuntime {
  static let shared = AppRuntime.live()

  var isEnabled: Bool
  var lastEventSummary: String
  var defaultBrowserSummary: String
  var selectedBrowserID: BrowserID
  var installedBrowsers: [BrowserInstallation]

  private let router: URLRouter
  private let defaultBrowserManager: DefaultBrowserManager
  private let browserCatalog: BrowserCatalog
  private let selectionStore: BrowserSelectionStore
  private let failureReporter: RoutingFailureReporting
  @ObservationIgnored
  private var runtimeTail: Task<Void, Never>?
  @ObservationIgnored
  private var runtimeCommandGeneration = 0

  init(
    router: URLRouter,
    defaultBrowserManager: DefaultBrowserManager,
    browserCatalog: BrowserCatalog,
    selectionStore: BrowserSelectionStore,
    failureReporter: RoutingFailureReporting,
    isEnabled: Bool = true,
    lastEventSummary: String = "No URL handled yet"
  ) {
    self.router = router
    self.defaultBrowserManager = defaultBrowserManager
    self.browserCatalog = browserCatalog
    self.selectionStore = selectionStore
    self.failureReporter = failureReporter
    self.isEnabled = isEnabled
    self.lastEventSummary = lastEventSummary
    let handlerStatus = defaultBrowserManager.status()
    self.defaultBrowserSummary = DiagnosticsFormatter.describeDefaultBrowserStatus(handlerStatus)
    let httpsHandler = handlerStatus.first { $0.scheme == .https }?.currentHandler
    let selectedBrowserID = selectionStore.selectedBrowser(currentHTTPSHandler: httpsHandler)
    self.selectedBrowserID = selectedBrowserID
    self.installedBrowsers = browserCatalog.installedBrowsers()
    selectionStore.setSelectedBrowser(selectedBrowserID)
  }

  static func live() -> AppRuntime {
    let detector = BrowserWindowDetector(snapshotProvider: CoreGraphicsWindowSnapshotProvider())
    let opener = BrowserOpener()
    let router = URLRouter(detector: detector, opener: opener)
    let defaultBrowserManager = DefaultBrowserManager()
    let browserCatalog = BrowserCatalog()
    let selectionStore = BrowserSelectionStore()
    let failureReporter = RoutingFailureReporter()

    return AppRuntime(
      router: router,
      defaultBrowserManager: defaultBrowserManager,
      browserCatalog: browserCatalog,
      selectionStore: selectionStore,
      failureReporter: failureReporter
    )
  }

  var selectedBrowser: BrowserDefinition {
    BrowserDefinition.definition(for: selectedBrowserID)
  }

  var selectedBrowserAvailabilitySummary: String {
    isBrowserInstalled(selectedBrowserID)
      ? "Target: \(selectedBrowser.displayName)"
      : "Target unavailable: \(selectedBrowser.displayName)"
  }

  func isBrowserInstalled(_ browserID: BrowserID) -> Bool {
    installedBrowsers.contains { $0.definition.id == browserID }
  }

  func selectBrowser(_ browserID: BrowserID) {
    selectedBrowserID = browserID
    selectionStore.setSelectedBrowser(browserID)
  }

  func setEnabled(_ isEnabled: Bool) {
    let router = self.router
    enqueueRuntimeCommand {
      await router.setEnabled(isEnabled)
    }
    self.isEnabled = isEnabled
  }

  func refreshBrowsersAndStatus() {
    installedBrowsers = browserCatalog.installedBrowsers()
    defaultBrowserSummary = DiagnosticsFormatter.describeDefaultBrowserStatus(defaultBrowserManager.status())
  }

  func refreshDefaultBrowserStatus() {
    refreshBrowsersAndStatus()
  }

  func setAsDefaultBrowser() {
    let results = defaultBrowserManager.setBrowstayAsDefault()
    defaultBrowserSummary = DiagnosticsFormatter.describeSetResults(results)
    let failureReporter = self.failureReporter
    enqueueRuntimeCommand {
      await failureReporter.requestAuthorization()
    }
  }

  func restoreSelectedBrowserAsDefault() {
    guard isBrowserInstalled(selectedBrowserID) else {
      defaultBrowserSummary = "\(selectedBrowser.displayName) is unavailable"
      return
    }

    let results = defaultBrowserManager.restoreDefault(to: selectedBrowser)
    defaultBrowserSummary = DiagnosticsFormatter.describeSetResults(results)
  }

  func restoreSafariAsDefaultBrowser() {
    restoreSelectedBrowserAsDefault()
  }

  func openTestURL() {
    handleIncomingURLs([URL(string: "https://www.apple.com/")!])
  }

  func handleIncomingURLs(_ urls: [URL]) {
    let router = self.router
    let target = selectedBrowser
    let failureReporter = self.failureReporter
    enqueueRuntimeCommand { [weak self] in
      let summary = await router.handle(urls, target: target)
      self?.lastEventSummary = DiagnosticsFormatter.describe(summary)
      await failureReporter.report(summary)
    }
  }

  func waitForRuntimeCommands() async {
    await runtimeTail?.value
  }

  private func enqueueRuntimeCommand(_ operation: @escaping @MainActor () async -> Void) {
    let previousCommand = runtimeTail
    runtimeCommandGeneration += 1
    let generation = runtimeCommandGeneration

    let command = Task { @MainActor [weak self] in
      if let previousCommand {
        await previousCommand.value
      }

      await operation()

      if self?.runtimeCommandGeneration == generation {
        self?.runtimeTail = nil
      }
    }

    runtimeTail = command
  }
}
