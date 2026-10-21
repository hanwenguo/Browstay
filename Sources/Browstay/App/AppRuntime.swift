import Foundation
import Observation
import BrowstayCore

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
  private let opener: BrowserOpening
  private let currentDisplayBounds: @MainActor () -> WindowBounds?
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
    opener: BrowserOpening,
    currentDisplayBounds: @escaping @MainActor () -> WindowBounds?,
    defaultBrowserManager: DefaultBrowserManager,
    browserCatalog: BrowserCatalog,
    selectionStore: BrowserSelectionStore,
    failureReporter: RoutingFailureReporting,
    isEnabled: Bool = true,
    lastEventSummary: String = "No URL handled yet"
  ) {
    self.router = router
    self.opener = opener
    self.currentDisplayBounds = currentDisplayBounds
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
      opener: opener,
      currentDisplayBounds: CurrentDisplay.visibleBounds,
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

  var browserChoices: [BrowserDefinition] {
    let installed = installedBrowsers.map(\.definition)
    if installed.contains(where: { $0.id == selectedBrowserID }) {
      return installed
    }
    return installed + [selectedBrowser]
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
    guard isBrowserInstalled(selectedBrowserID) else {
      defaultBrowserSummary = "\(selectedBrowser.displayName) is unavailable"
      return
    }

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

  func openTestURL() {
    handleIncomingURLs([URL(string: "https://www.apple.com/")!])
  }

  func openNewWindowOnCurrentDisplay() {
    let target = selectedBrowser
    guard isBrowserInstalled(target.id) else {
      lastEventSummary = "\(target.displayName) is unavailable"
      return
    }

    let opener = self.opener
    let bounds = currentDisplayBounds()
    enqueueRuntimeCommand { [weak self] in
      do {
        try await opener.openEmptyWindow(in: target, within: bounds)
        self?.lastEventSummary = "Opened new \(target.displayName) window"
      } catch {
        self?.lastEventSummary = "New \(target.displayName) window failed (\(error.localizedDescription))"
      }
    }
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
