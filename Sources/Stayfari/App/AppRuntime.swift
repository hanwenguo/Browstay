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

  private let router: URLRouter
  private let defaultBrowserManager: DefaultBrowserManager
  @ObservationIgnored
  private var runtimeTail: Task<Void, Never>?
  @ObservationIgnored
  private var runtimeCommandGeneration = 0

  init(
    router: URLRouter,
    defaultBrowserManager: DefaultBrowserManager,
    isEnabled: Bool = true,
    lastEventSummary: String = "No URL handled yet"
  ) {
    self.router = router
    self.defaultBrowserManager = defaultBrowserManager
    self.isEnabled = isEnabled
    self.lastEventSummary = lastEventSummary
    self.defaultBrowserSummary = DiagnosticsFormatter.describeDefaultBrowserStatus(defaultBrowserManager.status())
  }

  static func live() -> AppRuntime {
    let detector = SafariWindowDetector(snapshotProvider: CoreGraphicsWindowSnapshotProvider())
    let opener = SafariOpener()
    let router = URLRouter(detector: detector, opener: opener)
    let defaultBrowserManager = DefaultBrowserManager()

    return AppRuntime(router: router, defaultBrowserManager: defaultBrowserManager)
  }

  func setEnabled(_ isEnabled: Bool) {
    let router = self.router
    enqueueRuntimeCommand {
      await router.setEnabled(isEnabled)
    }
    self.isEnabled = isEnabled
  }

  func refreshDefaultBrowserStatus() {
    defaultBrowserSummary = DiagnosticsFormatter.describeDefaultBrowserStatus(defaultBrowserManager.status())
  }

  func setAsDefaultBrowser() {
    let results = defaultBrowserManager.setStayfariAsDefault()
    defaultBrowserSummary = DiagnosticsFormatter.describeSetResults(results)
  }

  func restoreSafariAsDefaultBrowser() {
    let results = defaultBrowserManager.restoreSafariAsDefault()
    defaultBrowserSummary = DiagnosticsFormatter.describeSetResults(results)
  }

  func openTestURL() {
    handleIncomingURLs([URL(string: "https://www.apple.com/")!])
  }

  func handleIncomingURLs(_ urls: [URL]) {
    let router = self.router
    enqueueRuntimeCommand { [weak self] in
      let summary = await router.handle(urls)
      self?.lastEventSummary = DiagnosticsFormatter.describe(summary)
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
