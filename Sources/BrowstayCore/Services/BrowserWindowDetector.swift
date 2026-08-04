import CoreGraphics

public protocol WindowSnapshotProviding: Sendable {
  func currentOnScreenWindows() -> [WindowInfo]
}

public protocol BrowserWindowDetecting: Sendable {
  func hasVisibleWindow(for browser: BrowserDefinition) async -> Bool
}

public struct BrowserWindowDetector: BrowserWindowDetecting {
  private let snapshotProvider: WindowSnapshotProviding

  public init(snapshotProvider: WindowSnapshotProviding) {
    self.snapshotProvider = snapshotProvider
  }

  public func hasVisibleWindow(for browser: BrowserDefinition) async -> Bool {
    hasVisibleWindow(for: browser, in: snapshotProvider.currentOnScreenWindows())
  }

  public func hasVisibleWindow(
    for browser: BrowserDefinition,
    in windows: [WindowInfo]
  ) -> Bool {
    windows.contains { Self.isNormalVisibleWindow($0, for: browser) }
  }

  public static func isNormalVisibleWindow(
    _ window: WindowInfo,
    for browser: BrowserDefinition
  ) -> Bool {
    let isTargetBrowser: Bool
    if let bundleIdentifier = window.bundleIdentifier {
      isTargetBrowser = bundleIdentifier == browser.bundleIdentifier
    } else {
      isTargetBrowser = browser.ownerNames.contains(window.ownerName)
    }

    return isTargetBrowser
      && window.isOnscreen
      && window.layer == 0
      && window.alpha > 0
      && window.bounds.width >= 80
      && window.bounds.height >= 80
  }
}
