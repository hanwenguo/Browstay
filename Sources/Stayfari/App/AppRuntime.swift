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
    self.isEnabled = isEnabled
    Task {
      await router.setEnabled(isEnabled)
    }
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
    Task {
      let summary = await router.handle(urls)
      lastEventSummary = DiagnosticsFormatter.describe(summary)
    }
  }
}
